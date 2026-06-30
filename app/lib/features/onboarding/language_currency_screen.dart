import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/settings_store.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_logo.dart';

class LanguageCurrencyScreen extends ConsumerWidget {
  const LanguageCurrencyScreen({super.key, this.firstRun = false});
  final bool firstRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(settingsStoreProvider);
    final s = ref.watch(stringsProvider);

    return Scaffold(
      appBar: firstRun ? null : AppBar(title: Text(s.t('profile.settings'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (firstRun) ...[
                    const SizedBox(height: 12),
                    const AppLogo(size: 84, full: true),
                    const SizedBox(height: 24),
                  ],
                  Text(s.t('onboarding.title'),
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(s.t('onboarding.subtitle'),
                      style: const TextStyle(color: Colors.white60)),
                  const SizedBox(height: 24),
                  _Label(s.t('onboarding.language')),
                  _Choice(
                    selected: store.locale.languageCode == 'en',
                    title: 'English',
                    onTap: () => store.setLocale(const Locale('en')),
                  ),
                  _Choice(
                    selected: store.locale.languageCode == 'id',
                    title: 'Bahasa Indonesia',
                    onTap: () => store.setLocale(const Locale('id')),
                  ),
                  const SizedBox(height: 20),
                  _Label(s.t('onboarding.currency')),
                  for (final c in AppCurrency.values)
                    _Choice(
                      selected: store.currency == c,
                      title: c.label,
                      onTap: () => store.setCurrency(c),
                    ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: () async {
                      if (firstRun) {
                        await store.completeOnboarding();
                        if (context.mounted) context.go('/');
                      } else {
                        context.pop();
                      }
                    },
                    child: Text(s.t(firstRun ? 'common.continue' : 'common.save')),
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: Colors.white54)),
      );
}

class _Choice extends StatelessWidget {
  const _Choice(
      {required this.selected, required this.title, required this.onTap});
  final bool selected;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? AppColors.violet.withValues(alpha: 0.25) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: selected ? AppColors.violet : Colors.white12, width: 1.5),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: selected
            ? const Icon(Icons.check_circle, color: AppColors.violet)
            : const Icon(Icons.circle_outlined, color: Colors.white24),
      ),
    );
  }
}
