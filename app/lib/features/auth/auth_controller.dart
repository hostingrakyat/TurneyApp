import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../shared/models/app_user.dart';

final authControllerProvider =
    NotifierProvider<AuthController, AppUser?>(AuthController.new);

/// Holds the signed-in [AppUser], or null when signed out.
///
/// When no Supabase backend is configured the controller falls back to a local
/// "demo" sign-in so the UI is fully explorable offline.
class AuthController extends Notifier<AppUser?> {
  SupabaseClient? get _client => ref.read(supabaseClientProvider);

  @override
  AppUser? build() {
    final client = _client;
    final user = client?.auth.currentUser;
    if (user == null) return null;
    Future.microtask(_loadProfile);
    return _fromAuthUser(user);
  }

  AppUser _fromAuthUser(User u) => AppUser(
        id: u.id,
        email: u.email ?? '',
        displayName: (u.userMetadata?['display_name'] as String?) ??
            u.email?.split('@').first ??
            'Player',
      );

  Future<void> _loadProfile() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    final row = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (row != null) {
      state = AppUser.fromMap({...row, 'email': user.email ?? ''});
    }
  }

  Future<void> signIn(
      {required String email, required String password}) async {
    final client = _client;
    if (client == null) {
      _demoSignIn(email);
      return;
    }
    final res = await client.auth
        .signInWithPassword(email: email.trim(), password: password);
    if (res.user != null) {
      state = _fromAuthUser(res.user!);
      await _loadProfile();
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final client = _client;
    if (client == null) {
      _demoSignIn(email, displayName: displayName);
      return;
    }
    final res = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName},
    );
    if (res.user != null) {
      state = _fromAuthUser(res.user!).copyWith(displayName: displayName);
    }
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
    state = null;
  }

  /// Admin action: set a user's role. Updates the backend when present and the
  /// local session if it's the current user.
  Future<void> setRole(String userId, UserRole role) async {
    final client = _client;
    if (client != null) {
      await client.from('profiles').update({'role': role.name}).eq('id', userId);
    }
    if (state?.id == userId) state = state!.copyWith(role: role);
  }

  /// Local-only session for demo mode. Grants the organizer role so the full
  /// create-competition flow can be explored without a backend; an `admin@…`
  /// email signs in as an admin (for testing the admin console).
  void _demoSignIn(String email, {String? displayName}) {
    final mail = email.trim().isEmpty ? 'demo@protourney.test' : email.trim();
    final isAdmin = mail.toLowerCase().startsWith('admin@');
    state = AppUser(
      id: isAdmin ? 'demo-admin' : 'demo-user',
      email: mail,
      displayName: displayName ?? mail.split('@').first,
      role: isAdmin ? UserRole.admin : UserRole.organizer,
    );
  }
}
