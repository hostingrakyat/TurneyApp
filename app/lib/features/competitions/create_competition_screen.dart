import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_settings.dart';
import '../../core/env.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../shared/models/competition.dart';
import '../auth/auth_controller.dart';
import 'competitions_controller.dart';

class CreateCompetitionScreen extends ConsumerStatefulWidget {
  const CreateCompetitionScreen({super.key});

  @override
  ConsumerState<CreateCompetitionScreen> createState() =>
      _CreateCompetitionScreenState();
}

class _CreateCompetitionScreenState
    extends ConsumerState<CreateCompetitionScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _banner = TextEditingController();
  final _maxParticipants = TextEditingController(text: '16');
  final _entryFee = TextEditingController(text: '25000');
  final _prizePool = TextEditingController(text: '0');
  final _meetingUrl = TextEditingController();

  CompetitionFormat _format = CompetitionFormat.singleElim;
  TechMeetingType _meetingType = TechMeetingType.discord;
  DateTime? _startsAt;
  DateTime? _deadline;
  Uint8List? _bannerBytes;
  int _groupSize = 0; // 0 = single group
  final _advance = TextEditingController(text: '2');
  bool _hasPlayoff = false;
  final _lobby = TextEditingController(text: '8'); // FFA players per match
  final _ffaAdvance = TextEditingController(text: '1'); // FFA advance per lobby
  final _finalWinners = TextEditingController(text: '1'); // FFA final podium
  bool _busy = false;

  Future<void> _pickBanner() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) {
      final bytes = await x.readAsBytes();
      setState(() => _bannerBytes = bytes);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _banner,
      _maxParticipants,
      _entryFee,
      _prizePool,
      _meetingUrl,
      _advance,
      _lobby,
      _ffaAdvance,
      _finalWinners,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _startsAt ?? now.add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _startsAt = picked);
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: (_startsAt ?? now.add(const Duration(days: 365))),
      initialDate: _deadline ?? now.add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    setState(() => _busy = true);
    try {
      String? bannerUrl =
          _banner.text.trim().isEmpty ? null : _banner.text.trim();
      Uint8List? bannerBytes;
      final client = ref.read(supabaseClientProvider);
      if (_bannerBytes != null) {
        if (client == null) {
          bannerBytes = _bannerBytes; // offline: keep in memory
        } else {
          final path = '${const Uuid().v4()}.png';
          await client.storage.from('banners').uploadBinary(
                path,
                _bannerBytes!,
                fileOptions:
                    const FileOptions(upsert: true, contentType: 'image/png'),
              );
          bannerUrl = client.storage.from('banners').getPublicUrl(path);
        }
      }
      final draft = Competition(
        id: '',
        organizerId: user.id,
        title: _title.text.trim(),
        description: _description.text.trim(),
        format: _format,
        maxParticipants: int.tryParse(_maxParticipants.text) ?? 16,
        entryFee:
            Env.paymentsEnabled ? (int.tryParse(_entryFee.text) ?? 0) : 0,
        prizePool:
            Env.paymentsEnabled ? (int.tryParse(_prizePool.text) ?? 0) : 0,
        status: CompetitionStatus.open,
        slug: '',
        bannerUrl: bannerUrl,
        bannerBytes: bannerBytes,
        techMeetingUrl:
            _meetingUrl.text.trim().isEmpty ? null : _meetingUrl.text.trim(),
        techMeetingType: _meetingType,
        startsAt: _startsAt,
        registrationDeadline: _deadline,
        groupSize: _format == CompetitionFormat.roundRobin ? _groupSize : 0,
        hasPlayoff:
            _format == CompetitionFormat.roundRobin && _hasPlayoff,
        advancePerGroup: _format == CompetitionFormat.freeForAll
            ? (int.tryParse(_ffaAdvance.text) ?? 1)
            : (int.tryParse(_advance.text) ?? 2),
        lobbySize: int.tryParse(_lobby.text) ?? 8,
        finalWinners: int.tryParse(_finalWinners.text) ?? 1,
      );
      final created =
          await ref.read(competitionsControllerProvider.notifier).create(draft);
      if (mounted) {
        final domain = ref.read(appSettingsProvider).domain;
        final s = ref.read(stringsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(s
                  .t('create.createdShare')
                  .replaceFirst('{x}', created.shareUrlFor(domain)))),
        );
        context.pushReplacement('/competition/${created.id}');
      }
    } catch (e) {
      if (mounted) {
        final s = ref.read(stringsProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(s.t('create.failed').replaceFirst('{x}', '$e'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final fee = int.tryParse(_entryFee.text) ?? 0;
    final net = (fee * 0.9).round();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('create.title'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _label(s.t('create.basics')),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: s.t('create.fieldTitle'),
                hintText: s.t('create.titleHint'),
              ),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? s.t('create.addTitle')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: s.t('create.description'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _banner,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: s.t('create.bannerUrl'),
                prefixIcon: const Icon(Icons.image_outlined),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickBanner,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_bannerBytes == null
                  ? s.t('create.uploadBanner')
                  : s.t('create.bannerSelected')),
            ),
            if (_bannerBytes != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_bannerBytes!,
                    height: 120, width: double.infinity, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 20),
            _label(s.t('create.format')),
            Wrap(
              spacing: 8,
              children: [
                for (final f in const [
                  (CompetitionFormat.singleElim, Icons.account_tree),
                  (CompetitionFormat.roundRobin, Icons.sync_alt),
                  (CompetitionFormat.freeForAll, Icons.groups),
                ])
                  ChoiceChip(
                    avatar: Icon(f.$2,
                        size: 18,
                        color: _format == f.$1
                            ? AppColors.violetDeep
                            : Colors.white70),
                    label: Text(_formatLabel(s, f.$1)),
                    selected: _format == f.$1,
                    onSelected: (_) => setState(() => _format = f.$1),
                  ),
              ],
            ),
            if (_format == CompetitionFormat.freeForAll) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _lobby,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: s.t('create.lobbySize'),
                  helperText: s.t('create.lobbySizeHelp'),
                  prefixIcon: const Icon(Icons.groups),
                ),
                validator: (v) {
                  if (_format != CompetitionFormat.freeForAll) return null;
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 2) ? s.t('create.min2') : null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ffaAdvance,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: s.t('create.ffaAdvance'),
                        prefixIcon: const Icon(Icons.trending_up),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _finalWinners,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: s.t('create.finalWinners'),
                        prefixIcon: const Icon(Icons.workspace_premium),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(s.t('create.ffaHelp'),
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
            if (_format == CompetitionFormat.roundRobin) ...[
              const SizedBox(height: 12),
              _label(s.t('create.groups')),
              Wrap(
                spacing: 8,
                children: [
                  for (final g in const [0, 3, 4, 5, 6])
                    ChoiceChip(
                      label: Text(g == 0
                          ? s.t('create.oneGroup')
                          : s.t('create.perGroup').replaceFirst('{n}', '$g')),
                      selected: _groupSize == g,
                      onSelected: (_) => setState(() => _groupSize = g),
                    ),
                ],
              ),
              if (_groupSize > 0) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _advance,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: s.t('create.advance'),
                    prefixIcon: const Icon(Icons.trending_up),
                  ),
                ),
                ..._groupWarnings(s),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _hasPlayoff,
                onChanged: (v) => setState(() => _hasPlayoff = v),
                title: Text(s.t('create.playoff')),
                subtitle: Text(s.t('create.playoffSub')),
              ),
            ],
            const SizedBox(height: 20),
            _label(s.t('create.capacityMoney')),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _maxParticipants,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: s.t('create.maxParticipants'),
                      prefixIcon: const Icon(Icons.group_outlined),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n < 2) ? s.t('create.min2') : null;
                    },
                  ),
                ),
                // Entry fee / prizes are hidden in store builds — see
                // Env.storeBuild (Google Play payments policy).
                if (Env.paymentsEnabled) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _entryFee,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: s.t('create.entryFee'),
                        prefixIcon: const Icon(Icons.payments_outlined),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (Env.paymentsEnabled) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _prizePool,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: s.t('create.prizePool'),
                  prefixIcon: const Icon(Icons.military_tech_outlined),
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (Env.paymentsEnabled)
              Card(
              color: AppColors.surfaceHigh,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: AppColors.cyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fee == 0
                            ? s.t('create.feeFree')
                            : s
                                .t('create.feeNote')
                                .replaceFirst('{x}', Format.money(net)),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label(s.t('create.schedule')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(_startsAt == null
                  ? s.t('create.pickDate')
                  : s.t('create.startsOn').replaceFirst('{x}',
                      _startsAt!.toLocal().toString().split(' ').first)),
              trailing: TextButton(
                onPressed: _pickDate,
                child: Text(s.t('create.choose')),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.how_to_reg_outlined),
              title: Text(_deadline == null
                  ? s.t('create.deadlineNone')
                  : s.t('create.deadlineOn').replaceFirst('{x}',
                      _deadline!.toLocal().toString().split(' ').first)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_deadline != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _deadline = null),
                    ),
                  TextButton(
                    onPressed: _pickDeadline,
                    child: Text(s.t('create.choose')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: TechMeetingType.values
                  .map((t) => ChoiceChip(
                        label: Text(t.label),
                        selected: _meetingType == t,
                        onSelected: (_) => setState(() => _meetingType = t),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _meetingUrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: s
                    .t('create.meetingLink')
                    .replaceFirst('{x}', _meetingType.label),
                prefixIcon: const Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.rocket_launch),
              label: Text(s.t('create.publish')),
            ),
            const SizedBox(height: 8),
            Text(
              s.t('create.shareNote'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// Inline validation hints for round-robin group settings.
  List<Widget> _groupWarnings(AppStrings s) {
    final warnings = <String>[];
    final advance = int.tryParse(_advance.text) ?? 0;
    final maxP = int.tryParse(_maxParticipants.text) ?? 0;
    if (advance >= _groupSize) {
      warnings.add(s.t('create.validateAdvance'));
    }
    if (maxP > 0 && maxP % _groupSize != 0) {
      warnings.add(s
          .t('create.validateDivide')
          .replaceFirst('{n}', '$maxP')
          .replaceFirst('{g}', '$_groupSize'));
    }
    if (warnings.isEmpty) return const [];
    return [
      const SizedBox(height: 8),
      for (final w in warnings)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(w,
                    style:
                        const TextStyle(color: AppColors.gold, fontSize: 12)),
              ),
            ],
          ),
        ),
    ];
  }

  String _formatLabel(AppStrings s, CompetitionFormat f) => switch (f) {
        CompetitionFormat.singleElim => s.t('create.elimination'),
        CompetitionFormat.roundRobin => s.t('create.roundRobin'),
        CompetitionFormat.freeForAll => s.t('create.freeForAll'),
      };

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white54,
                letterSpacing: 0.5)),
      );
}
