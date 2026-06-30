import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'demo_store_provider.dart';
import 'supabase.dart';

/// Admin-managed app settings: logo override, demo-mode toggle, and the
/// deployment configuration (domain, QRIS, email) captured for going live.
class AppSettings {
  const AppSettings({
    this.logoUrl,
    this.logoBytes,
    this.demoMode = true,
    this.domain,
    this.qrisMock = true,
    this.qrisMerchantId,
    this.qrisStoreId,
    this.emailFrom,
  });
  final String? logoUrl;
  final Uint8List? logoBytes;
  final bool demoMode;

  /// Public domain the web build is hosted on (feeds share links).
  final String? domain;

  /// QRIS still in mock mode (no real money) until live keys are configured.
  final bool qrisMock;
  final String? qrisMerchantId;
  final String? qrisStoreId;
  final String? emailFrom;

  bool get hasLogoOverride =>
      logoBytes != null || (logoUrl != null && logoUrl!.isNotEmpty);

  bool get hasDomain => domain != null && domain!.isNotEmpty;
  bool get hasQrisLive =>
      !qrisMock &&
      (qrisMerchantId?.isNotEmpty ?? false) &&
      (qrisStoreId?.isNotEmpty ?? false);
  bool get hasEmail => emailFrom != null && emailFrom!.isNotEmpty;
}

/// Backend settings row (single row id=1), loaded lazily.
final _backendSettingsProvider = FutureProvider<AppSettings>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const AppSettings();
  final row =
      await client.from('app_settings').select().eq('id', 1).maybeSingle();
  if (row == null) return const AppSettings();
  return AppSettings(
    logoUrl: row['app_logo_url'] as String?,
    demoMode: (row['demo_mode'] ?? true) as bool,
    domain: row['domain'] as String?,
    qrisMock: (row['qris_mock'] ?? true) as bool,
    qrisMerchantId: row['qris_merchant_id'] as String?,
    qrisStoreId: row['qris_store_id'] as String?,
    emailFrom: row['email_from'] as String?,
  );
});

/// Effective settings — from [DemoStore] offline, or the backend row.
final appSettingsProvider = Provider<AppSettings>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    final store = ref.watch(demoStoreProvider);
    return AppSettings(
      logoBytes: store.appLogoBytes,
      demoMode: store.demoMode,
      domain: store.domain,
      qrisMock: store.qrisMock,
      qrisMerchantId: store.qrisMerchantId,
      qrisStoreId: store.qrisStoreId,
      emailFrom: store.emailFrom,
    );
  }
  return ref.watch(_backendSettingsProvider).valueOrNull ?? const AppSettings();
});

final appSettingsServiceProvider =
    Provider<AppSettingsService>((ref) => AppSettingsService(ref));

class AppSettingsService {
  AppSettingsService(this._ref);
  final Ref _ref;

  SupabaseClient? get _client => _ref.read(supabaseClientProvider);

  Future<void> setLogo(Uint8List bytes) async {
    final client = _client;
    if (client == null) {
      _ref.read(demoStoreProvider).setAppLogo(bytes);
      return;
    }
    const path = 'app-logo.png';
    await client.storage.from('branding').uploadBinary(
          path,
          bytes,
          fileOptions:
              const FileOptions(upsert: true, contentType: 'image/png'),
        );
    final url = client.storage.from('branding').getPublicUrl(path);
    // cache-bust so the new logo shows immediately
    final busted = '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    await client
        .from('app_settings')
        .upsert({'id': 1, 'app_logo_url': busted});
    _ref.invalidate(_backendSettingsProvider);
  }

  Future<void> setDemoMode(bool value) async {
    final client = _client;
    if (client == null) {
      _ref.read(demoStoreProvider).setDemoMode(value);
      return;
    }
    await client.from('app_settings').upsert({'id': 1, 'demo_mode': value});
    _ref.invalidate(_backendSettingsProvider);
  }

  /// Saves the deployment configuration (non-secret values only; secret QRIS /
  /// email keys live in Supabase secrets, never in this client-readable row).
  Future<void> setConfig({
    String? domain,
    bool? qrisMock,
    String? qrisMerchantId,
    String? qrisStoreId,
    String? emailFrom,
  }) async {
    final client = _client;
    if (client == null) {
      _ref.read(demoStoreProvider).setConfig(
            domain: domain,
            qrisMock: qrisMock,
            qrisMerchantId: qrisMerchantId,
            qrisStoreId: qrisStoreId,
            emailFrom: emailFrom,
          );
      return;
    }
    final patch = <String, dynamic>{'id': 1};
    if (domain != null) patch['domain'] = domain;
    if (qrisMock != null) patch['qris_mock'] = qrisMock;
    if (qrisMerchantId != null) patch['qris_merchant_id'] = qrisMerchantId;
    if (qrisStoreId != null) patch['qris_store_id'] = qrisStoreId;
    if (emailFrom != null) patch['email_from'] = emailFrom;
    await client.from('app_settings').upsert(patch);
    _ref.invalidate(_backendSettingsProvider);
  }
}
