import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/settings_store.dart';
import '../../core/theme.dart';
import '../../shared/widgets/animate.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/surface.dart';
import 'onboarding_hero.dart';

/// First run: an immersive, paged welcome on the brand gradient with an
/// animated hero. Opened from Profile → Settings instead, it renders as a
/// plain settings page with the same modern pickers.
class LanguageCurrencyScreen extends ConsumerStatefulWidget {
  const LanguageCurrencyScreen({super.key, this.firstRun = false});
  final bool firstRun;

  @override
  ConsumerState<LanguageCurrencyScreen> createState() =>
      _LanguageCurrencyScreenState();
}

class _LanguageCurrencyScreenState
    extends ConsumerState<LanguageCurrencyScreen> {
  final _pages = PageController();
  double _page = 0;
  static const _count = 3;

  @override
  void initState() {
    super.initState();
    _pages.addListener(() {
      final p = _pages.page ?? 0;
      if (p != _page) setState(() => _page = p);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(settingsStoreProvider).completeOnboarding();
    if (mounted) context.go('/');
  }

  void _next() {
    if (_page.round() >= _count - 1) {
      _finish();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() => _pages.previousPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );

  @override
  Widget build(BuildContext context) {
    return widget.firstRun ? _buildOnboarding() : _buildSettings();
  }

  // ── First run ───────────────────────────────────────────────
  Widget _buildOnboarding() {
    final s = ref.watch(stringsProvider);
    final last = _page.round() >= _count - 1;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.sky,
                    AppColors.violet,
                    AppColors.violetDeep,
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
          ),
          const PatternOverlay(
              type: PatternType.bracket, opacity: 0.13, spacing: 30),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                // Sized from the available height so the art shrinks instead
                // of overflowing on short screens.
                child: LayoutBuilder(builder: (_, box) {
                  final hero = (box.maxHeight * 0.24).clamp(110.0, 208.0).toDouble();
                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      const FadeSlideIn(child: AppLogo(size: 34, full: true)),
                      SizedBox(height: box.maxHeight * 0.04),
                      // The hero stays put; the copy slides beneath it.
                      OnboardingHero(
                        size: hero,
                        parallax: (_page - _page.round()).clamp(-1.0, 1.0).toDouble(),
                      ),
                      Expanded(
                        child: PageView(
                          controller: _pages,
                          children: [
                            _WelcomePage(strings: s),
                            _LanguagePage(strings: s),
                            _CurrencyPage(strings: s),
                          ],
                        ),
                      ),
                      _Dots(count: _count, page: _page),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: Column(
                          children: [
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.violetDeep,
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _next,
                              child: Text(
                                s.t(last
                                    ? 'onboarding.getStarted'
                                    : 'common.continue'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                                minimumSize: const Size.fromHeight(44),
                              ),
                              onPressed: last ? _back : _finish,
                              child: Text(s.t(
                                  last ? 'common.back' : 'onboarding.skip')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile → Settings ──────────────────────────────────────
  Widget _buildSettings() {
    final s = ref.watch(stringsProvider);
    final store = ref.watch(settingsStoreProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('profile.settings'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(s.t('onboarding.language')),
                  const _LanguageChoices(),
                  const SizedBox(height: 24),
                  SectionHeader(s.t('onboarding.currency')),
                  _CurrencyChoices(store: store),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: Text(s.t('common.save')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pages ─────────────────────────────────────────────────────

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.title, required this.subtitle, this.child});
  final String title;
  final String subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 27,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82), height: 1.4),
          ),
          if (child != null) ...[const SizedBox(height: 22), child!],
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context) => _PageFrame(
        title: strings.t('onboarding.welcomeTitle'),
        subtitle: strings.t('onboarding.welcomeSub'),
      );
}

class _LanguagePage extends StatelessWidget {
  const _LanguagePage({required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context) => _PageFrame(
        title: strings.t('onboarding.languageTitle'),
        subtitle: strings.t('onboarding.subtitle'),
        child: const _LanguageChoices(),
      );
}

class _CurrencyPage extends ConsumerWidget {
  const _CurrencyPage({required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _PageFrame(
        title: strings.t('onboarding.currencyTitle'),
        subtitle: strings.t('onboarding.subtitle'),
        child: _CurrencyChoices(store: ref.watch(settingsStoreProvider)),
      );
}

// ── Choice groups ─────────────────────────────────────────────

class _LanguageChoices extends ConsumerWidget {
  const _LanguageChoices();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(settingsStoreProvider);
    final code = store.locale.languageCode;
    return Row(
      children: [
        Expanded(
          child: _SelectCard(
            glyph: 'EN',
            title: 'English',
            selected: code == 'en',
            onTap: () => store.setLocale(const Locale('en')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SelectCard(
            glyph: 'ID',
            title: 'Indonesia',
            selected: code == 'id',
            onTap: () => store.setLocale(const Locale('id')),
          ),
        ),
      ],
    );
  }
}

class _CurrencyChoices extends StatelessWidget {
  const _CurrencyChoices({required this.store});
  final SettingsStore store;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final c in AppCurrency.values) ...[
          if (c != AppCurrency.values.first) const SizedBox(width: 12),
          Expanded(
            child: _SelectCard(
              glyph: c.symbol,
              title: c.label.split(' (').first,
              selected: store.currency == c,
              onTap: () => store.setCurrency(c),
            ),
          ),
        ],
      ],
    );
  }
}

/// A tappable choice tile — monogram badge, label, and a check that pops in.
/// Replaces the old radio rows.
class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.glyph,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String glyph;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: selected ? 0.22 : 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 0.95 : 0.16),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: selected ? 1 : 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    glyph,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color:
                          selected ? AppColors.violetDeep : Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  right: -6,
                  top: -6,
                  child: AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutBack,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          size: 12, color: AppColors.violetDeep),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: selected ? 1 : 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page indicator — the active dot stretches into a pill.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page});
  final int count;
  final double page;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 7,
            width: page.round() == i ? 26 : 7,
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: page.round() == i ? 1 : 0.34),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
