import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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
  Uint8List? _bannerBytes;
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
        entryFee: int.tryParse(_entryFee.text) ?? 0,
        prizePool: int.tryParse(_prizePool.text) ?? 0,
        status: CompetitionStatus.open,
        slug: '',
        bannerUrl: bannerUrl,
        bannerBytes: bannerBytes,
        techMeetingUrl:
            _meetingUrl.text.trim().isEmpty ? null : _meetingUrl.text.trim(),
        techMeetingType: _meetingType,
        startsAt: _startsAt,
      );
      final created =
          await ref.read(competitionsControllerProvider.notifier).create(draft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created · share link ${created.shareUrl}')),
        );
        context.pushReplacement('/competition/${created.id}');
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
    final fee = int.tryParse(_entryFee.text) ?? 0;
    final net = (fee * 0.9).round();
    return Scaffold(
      appBar: AppBar(title: const Text('New competition')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _label('Basics'),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Mobile Legends Weekend Cup',
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? 'Add a title' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description / rules',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _banner,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Banner image URL (optional)',
                prefixIcon: Icon(Icons.image_outlined),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickBanner,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_bannerBytes == null
                  ? 'Or upload a banner image'
                  : 'Banner image selected'),
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
            _label('Format'),
            SegmentedButton<CompetitionFormat>(
              segments: const [
                ButtonSegment(
                  value: CompetitionFormat.singleElim,
                  label: Text('Elimination'),
                  icon: Icon(Icons.account_tree),
                ),
                ButtonSegment(
                  value: CompetitionFormat.roundRobin,
                  label: Text('Round robin'),
                  icon: Icon(Icons.sync_alt),
                ),
              ],
              selected: {_format},
              onSelectionChanged: (s) => setState(() => _format = s.first),
            ),
            const SizedBox(height: 20),
            _label('Capacity & money'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _maxParticipants,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Max participants',
                      prefixIcon: Icon(Icons.group_outlined),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return (n == null || n < 2) ? 'Min 2' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _entryFee,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Entry fee (Rp)',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _prizePool,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Prize pool (Rp, optional)',
                prefixIcon: Icon(Icons.military_tech_outlined),
              ),
            ),
            const SizedBox(height: 8),
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
                            ? 'Free entry — no platform fee.'
                            : 'Platform fee is 10%. You receive Rp $net per paid '
                                'registration.',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label('Schedule & technical meeting'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(_startsAt == null
                  ? 'Pick a start date'
                  : 'Starts ${_startsAt!.toLocal().toString().split(' ').first}'),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Choose'),
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
                labelText: '${_meetingType.label} invite link',
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
              label: const Text('Publish competition'),
            ),
            const SizedBox(height: 8),
            const Text(
              'A public share link is generated automatically on publish.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

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
