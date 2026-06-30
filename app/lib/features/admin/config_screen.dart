import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_settings.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';

/// Admin Configuration — captures the non-secret settings needed to take
/// ProTourney live on a cPanel-hosted web build backed by Supabase:
/// public domain, QRIS merchant details (mock toggle), and the sender email.
///
/// Secret values (QRIS API key, callback secret, Resend key) are NEVER stored
/// in the client-readable `app_settings` row — the screen shows the exact
/// `supabase secrets set …` commands to run instead.
class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  final _domain = TextEditingController();
  final _merchantId = TextEditingController();
  final _storeId = TextEditingController();
  final _emailFrom = TextEditingController();
  bool _qrisMock = true;
  bool _busy = false;
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in [_domain, _merchantId, _storeId, _emailFrom]) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(AppSettings s) {
    if (_loaded) return;
    _loaded = true;
    _domain.text = s.domain ?? '';
    _merchantId.text = s.qrisMerchantId ?? '';
    _storeId.text = s.qrisStoreId ?? '';
    _emailFrom.text = s.emailFrom ?? '';
    _qrisMock = s.qrisMock;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(appSettingsServiceProvider).setConfig(
            domain: _domain.text.trim(),
            qrisMock: _qrisMock,
            qrisMerchantId: _merchantId.text.trim(),
            qrisStoreId: _storeId.text.trim(),
            emailFrom: _emailFrom.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Configuration saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    _hydrate(settings);
    final backendConnected = ref.watch(supabaseClientProvider) != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuration')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _ReadinessCard(settings: settings, backendConnected: backendConnected),
          const SizedBox(height: 20),

          // ── Domain ──────────────────────────────────────────────
          _SectionLabel('Domain'),
          const _Hint(
              'The public domain your web build is hosted on (cPanel). Used to '
              'build competition share links.'),
          const SizedBox(height: 8),
          TextField(
            controller: _domain,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Domain',
              hintText: 'protourney.id',
              prefixIcon: Icon(Icons.public),
            ),
          ),
          const SizedBox(height: 24),

          // ── QRIS ────────────────────────────────────────────────
          _SectionLabel('QRIS payments'),
          Card(
            child: SwitchListTile(
              value: _qrisMock,
              onChanged: (v) => setState(() => _qrisMock = v),
              secondary:
                  const Icon(Icons.science_outlined, color: AppColors.gold),
              title: const Text('Mock mode',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text(
                  'On = simulate payments (no real money). Turn off only once '
                  'live QRIS keys are set as Supabase secrets.'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _merchantId,
            decoration: const InputDecoration(
              labelText: 'QRIS merchant ID',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _storeId,
            decoration: const InputDecoration(
              labelText: 'QRIS store ID',
              prefixIcon: Icon(Icons.point_of_sale_outlined),
            ),
          ),
          const SizedBox(height: 12),
          const _SecretGuidance(
            title: 'Secret keys (server-side only)',
            lines: [
              'supabase secrets set QRIS_API_KEY=…',
              'supabase secrets set QRIS_CALLBACK_SECRET=…',
            ],
            note:
                'These are never stored in the app. Set them as Supabase secrets '
                'so only the Edge Functions can read them.',
          ),
          const SizedBox(height: 24),

          // ── Email ───────────────────────────────────────────────
          _SectionLabel('Transactional email'),
          const _Hint(
              'Sender address for receipts and dispute notifications.'),
          const SizedBox(height: 8),
          TextField(
            controller: _emailFrom,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'From address',
              hintText: 'no-reply@protourney.id',
              prefixIcon: Icon(Icons.alternate_email),
            ),
          ),
          const SizedBox(height: 12),
          const _SecretGuidance(
            title: 'Email provider key (server-side only)',
            lines: ['supabase secrets set RESEND_API_KEY=…'],
            note:
                'Required for the resolve-matches function to email organizers '
                'on disputes.',
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('Save configuration'),
          ),
          const SizedBox(height: 12),
          const _Hint(
              'See docs/DEPLOY_CPANEL.md for the full build → upload → point '
              'domain → set secrets walkthrough.'),
        ],
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard(
      {required this.settings, required this.backendConnected});
  final AppSettings settings;
  final bool backendConnected;

  @override
  Widget build(BuildContext context) {
    final items = <(bool, String)>[
      (settings.hasDomain, 'Domain set'),
      (
        settings.hasQrisLive,
        settings.qrisMock ? 'QRIS live (mock is on)' : 'QRIS live keys configured'
      ),
      (settings.hasEmail, 'Sender email set'),
      (backendConnected, 'Backend connected (Supabase)'),
    ];
    final done = items.where((i) => i.$1).length;
    return Card(
      color: AppColors.surfaceHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist, color: AppColors.cyan),
                const SizedBox(width: 8),
                Text('Deployment readiness  $done/${items.length}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            for (final i in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      i.$1
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: i.$1 ? AppColors.success : Colors.white38,
                    ),
                    const SizedBox(width: 10),
                    Text(i.$2,
                        style: TextStyle(
                            color: i.$1 ? Colors.white : Colors.white60)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SecretGuidance extends StatelessWidget {
  const _SecretGuidance(
      {required this.title, required this.lines, required this.note});
  final String title;
  final List<String> lines;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceHigh,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline,
                    size: 18, color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final line in lines)
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: line));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Command copied')));
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(line,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Colors.white70)),
                      ),
                      const Icon(Icons.copy, size: 14, color: Colors.white38),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(note,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white54,
                letterSpacing: 0.5)),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.cyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white54)),
          ),
        ],
      );
}
