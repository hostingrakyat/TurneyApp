import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n.dart';
import '../admin/admin_screen.dart';
import '../auth/auth_controller.dart';
import '../competitions/browse_screen.dart';
import '../organizer/organizer_screen.dart';
import '../profile/profile_screen.dart';
import '../schedule/schedule_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  )..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.015),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final isAdmin = user?.isAdmin ?? false;
    final s = ref.watch(stringsProvider);

    final tabs = <Widget>[
      const BrowseScreen(),
      const ScheduleScreen(),
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
        icon: const Icon(Icons.calendar_month_outlined),
        selectedIcon: const Icon(Icons.calendar_month),
        label: s.t('nav.schedule'),
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
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          // IndexedStack preserves each tab's state (scroll, controllers)
          // while the whole body cross-fades in on every switch.
          child: IndexedStack(index: safeIndex, children: tabs),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: _select,
        destinations: destinations,
      ),
    );
  }
}
