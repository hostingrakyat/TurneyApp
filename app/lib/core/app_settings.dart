import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'demo_store_provider.dart';
import 'supabase.dart';

/// Admin-managed app settings: a custom logo override and a demo-mode toggle.
class AppSettings {
  const AppSettings({this.logoUrl, this.logoBytes, this.demoMode = true});
  final String? logoUrl;
  final Uint8List? logoBytes;
  final bool demoMode;

  bool get hasLogoOverride =>
      logoBytes != null || (logoUrl != null && logoUrl!.isNotEmpty);
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
  );
});

/// Effective settings — from [DemoStore] offline, or the backend row.
final appSettingsProvider = Provider<AppSettings>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    final store = ref.watch(demoStoreProvider);
    return AppSettings(
        logoBytes: store.appLogoBytes, demoMode: store.demoMode);
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
}
