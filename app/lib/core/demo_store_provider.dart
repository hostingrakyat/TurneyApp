import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_store.dart';

/// Session-scoped in-memory backend, used when no Supabase is configured.
/// Watch it to rebuild on any tournament-state change.
final demoStoreProvider =
    ChangeNotifierProvider<DemoStore>((ref) => DemoStore());
