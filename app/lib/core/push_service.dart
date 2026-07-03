import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import 'supabase.dart';

/// Client hook for push notifications.
///
/// The FCM token itself comes from `firebase_messaging`, which needs your own
/// Firebase project — run `flutterfire configure`, then feed tokens to
/// [registerToken] from the `getToken()` / `onTokenRefresh` callbacks (see
/// docs/PUSH.md). Until then this is a safe no-op: the app relies on in-app
/// notifications + dispute emails, and nothing here touches the build.
///
/// The DB half is real and ready: [registerToken] upserts into `device_tokens`,
/// which the `resolve-matches` cron fans out to via FCM (`_shared/push.ts`).
class PushService {
  PushService(this._ref);
  final Ref _ref;

  /// Store/refresh this device's push token for the signed-in user.
  Future<void> registerToken(String token, {String? platform}) async {
    final user = _ref.read(authControllerProvider);
    final client = _ref.read(supabaseClientProvider);
    if (user == null || client == null || token.isEmpty) return;
    await client.from('device_tokens').upsert({
      'user_id': user.id,
      'token': token,
      'platform': platform ?? defaultTargetPlatform.name,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,token');
  }

  /// Drop a token on sign-out or when FCM reports it invalid.
  Future<void> unregisterToken(String token) async {
    final client = _ref.read(supabaseClientProvider);
    if (client == null || token.isEmpty) return;
    await client.from('device_tokens').delete().eq('token', token);
  }
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));
