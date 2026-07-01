import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/payout_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/competitions/competition_detail_screen.dart';
import '../features/competitions/create_competition_screen.dart';
import '../features/competitions/public_competition_screen.dart';
import '../features/home/home_shell.dart';
import '../features/admin/config_screen.dart';
import '../features/admin/payouts_screen.dart';
import '../features/admin/users_screen.dart';
import '../features/matches/match_detail_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/language_currency_screen.dart';
import '../features/organizer/manage_competition_screen.dart';
import '../features/profile/my_registrations_screen.dart';
import 'settings_store.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.listen(settingsStoreProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      // Public tournament pages (share links) are open to anyone — skip the
      // onboarding + auth gates entirely.
      if (state.matchedLocation.startsWith('/c/')) return null;

      final onboarded = ref.read(settingsStoreProvider).onboarded;
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!onboarded) return atOnboarding ? null : '/onboarding';
      if (atOnboarding) return '/';

      final loggedIn = ref.read(authControllerProvider) != null;
      final atAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';
      if (!loggedIn) return atAuth ? null : '/login';
      if (atAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const LanguageCurrencyScreen(firstRun: true),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const LanguageCurrencyScreen(),
      ),
      GoRoute(
        path: '/c/:slug',
        builder: (_, s) =>
            PublicCompetitionScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeShell()),
      GoRoute(
        path: '/competition/new',
        builder: (_, __) => const CreateCompetitionScreen(),
      ),
      GoRoute(
        path: '/competition/:id/manage',
        builder: (_, s) =>
            ManageCompetitionScreen(competitionId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/competition/:id',
        builder: (_, s) =>
            CompetitionDetailScreen(competitionId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/match/:id',
        builder: (_, s) => MatchDetailScreen(matchId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/payout', builder: (_, __) => const PayoutScreen()),
      GoRoute(
        path: '/my-registrations',
        builder: (_, __) => const MyRegistrationsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/admin/payouts',
        builder: (_, __) => const AdminPayoutsScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (_, __) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: '/admin/config',
        builder: (_, __) => const ConfigScreen(),
      ),
    ],
  );
});
