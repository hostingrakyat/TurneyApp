import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/payout_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/competitions/competition_detail_screen.dart';
import '../features/competitions/create_competition_screen.dart';
import '../features/home/home_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authControllerProvider) != null;
      final atAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';
      if (!loggedIn) return atAuth ? null : '/login';
      if (atAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeShell()),
      GoRoute(
        path: '/competition/new',
        builder: (_, __) => const CreateCompetitionScreen(),
      ),
      GoRoute(
        path: '/competition/:id',
        builder: (_, s) =>
            CompetitionDetailScreen(competitionId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/payout', builder: (_, __) => const PayoutScreen()),
    ],
  );
});
