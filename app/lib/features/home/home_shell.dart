import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../admin/admin_screen.dart';
import '../auth/auth_controller.dart';
import '../competitions/browse_screen.dart';
import '../organizer/organizer_screen.dart';
import '../profile/profile_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final isAdmin = user?.isAdmin ?? false;
    final s = ref.watch(stringsProvider);

    final tabs = <Widget>[
      const BrowseScreen(),
      const OrganizerScreen(),
      if (isAdmin) const AdminScreen(),
      const ProfileScreen(),
    ];

    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.emoji_events_outlined),
        selectedIcon: const Icon(Icons.emoji_events),
        label: s.t('nav.compete'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: s.t('nav.organize'),
      ),
      if (isAdmin)
        NavigationDestination(
          icon: const Icon(Icons.shield_outlined),
          selectedIcon: const Icon(Icons.shield),
          label: s.t('nav.admin'),
        ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: s.t('nav.profile'),
      ),
    ];

    final int safeIndex =
        _index < 0 ? 0 : (_index >= tabs.length ? tabs.length - 1 : _index);

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}
