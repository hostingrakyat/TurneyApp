import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

/// The active Supabase client, or `null` when running in demo mode
/// (no `SUPABASE_URL` configured). Callers must handle the null case.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!Env.hasBackend) return null;
  return Supabase.instance.client;
});

/// Convenience: streams auth state changes when a backend is present.
final authStateChangesProvider = StreamProvider<AuthState?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return Stream<AuthState?>.value(null);
  return client.auth.onAuthStateChange;
});
