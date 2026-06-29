import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../shared/models/competition.dart';
import '../../shared/models/match.dart';
import '../../shared/models/match_report.dart';
import '../../shared/models/match_stream.dart';
import '../../shared/widgets/brand.dart';
import '../auth/auth_controller.dart';
import '../competitions/competitions_controller.dart';
import 'matches_controller.dart';

class MatchDetailScreen extends ConsumerWidget {
  const MatchDetailScreen({super.key, required this.matchId});
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(singleMatchProvider(matchId));
    return Scaffold(
      appBar: AppBar(title: const Text('Match')),
      body: matchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(title: 'Could not load', subtitle: '$e'),
        data: (match) => match == null
            ? const EmptyState(title: 'Match not found')
            : _MatchView(match: match),
      ),
    );
  }
}

class _MatchView extends ConsumerWidget {
  const _MatchView({required this.match});
  final GameMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);
    final streams = ref.watch(matchStreamsProvider(match.id));
    final reports = ref.watch(matchReportsProvider(match.id));

    Competition? comp;
    for (final c in ref.watch(competitionsControllerProvider).valueOrNull ??
        const <Competition>[]) {
      if (c.id == match.competitionId) comp = c;
    }
    final isManager = user != null &&
        (user.isAdmin || (comp != null && comp.organizerId == user.id));
    final isPlayer =
        user != null && (user.id == match.player1Id || user.id == match.player2Id);
    final isCompleted = match.status == MatchStatus.completed;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Versus(match: match),
        const SizedBox(height: 12),
        Center(child: _statusPill(match.status)),
        if (isCompleted && match.winnerName != null) ...[
          const SizedBox(height: 12),
          Center(
            child: TagPill('Winner: ${match.winnerName}',
                icon: Icons.emoji_events, color: AppColors.gold),
          ),
        ],
        const SizedBox(height: 24),

        // ── Pre-match streams ──
        _SectionTitle('Live streams', icon: Icons.live_tv),
        streams.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (list) => Column(
            children: [
              if (list.isEmpty)
                const _Hint('No stream links yet.'),
              ...list.map((s) => _StreamTile(stream: s)),
              if (isPlayer && !isCompleted)
                TextButton.icon(
                  onPressed: () => _addStream(context, ref),
                  icon: const Icon(Icons.add_link),
                  label: const Text('Add your stream link'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Post-match reports ──
        _SectionTitle('Result reports', icon: Icons.fact_check_outlined),
        reports.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (list) => Column(
            children: [
              if (list.isEmpty) const _Hint('No reports yet.'),
              ...list.map((r) => _ReportTile(match: match, report: r)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (user != null &&
            isPlayer &&
            !isCompleted &&
            match.bothPlayersPresent)
          FilledButton.icon(
            onPressed: () => _report(context, ref, user.id, user.displayName),
            icon: const Icon(Icons.upload_file),
            label: const Text('Report result + screenshot'),
          ),

        if (isManager && match.status == MatchStatus.disputed) ...[
          const SizedBox(height: 16),
          _DisputeResolver(match: match),
        ],
        if (isManager &&
            !isCompleted &&
            match.status != MatchStatus.disputed &&
            match.bothPlayersPresent) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(matchesServiceProvider).resolveNow(match),
            icon: const Icon(Icons.gavel),
            label: const Text('Resolve now (skip 5-min wait)'),
          ),
        ],
      ],
    );
  }

  Future<void> _addStream(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<({StreamPlatform p, String url})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _StreamSheet(),
    );
    if (result == null) return;
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    await ref
        .read(matchesServiceProvider)
        .addStream(match, user.id, result.p, result.url);
  }

  Future<void> _report(
      BuildContext context, WidgetRef ref, String uid, String name) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ReportSheet(match: match, reporterId: uid, reporterName: name),
    );
  }

  static Widget _statusPill(MatchStatus s) {
    final color = switch (s) {
      MatchStatus.completed => AppColors.success,
      MatchStatus.disputed => AppColors.danger,
      MatchStatus.awaitingReports || MatchStatus.autoResolving => AppColors.gold,
      MatchStatus.scheduled => AppColors.cyan,
    };
    return TagPill(s.label, color: color);
  }
}

class _Versus extends StatelessWidget {
  const _Versus({required this.match});
  final GameMatch match;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _player(match.player1Name, match.winnerId == match.player1Id)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('VS',
              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white38)),
        ),
        Expanded(child: _player(match.player2Name, match.winnerId == match.player2Id)),
      ],
    );
  }

  Widget _player(String? name, bool isWinner) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        gradient: isWinner ? AppColors.brand : null,
        color: isWinner ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            child: Text(
              (name == null || name.isEmpty) ? '?' : name[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          Text(name ?? 'TBD',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StreamTile extends StatelessWidget {
  const _StreamTile({required this.stream});
  final MatchStreamEntry stream;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.live_tv, color: AppColors.cyan),
        title: Text(stream.platform.label),
        subtitle: Text(stream.url,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.match, required this.report});
  final GameMatch match;
  final MatchReport report;

  String _name(String? id) {
    if (id == match.player1Id) return match.player1Name ?? 'Player 1';
    if (id == match.player2Id) return match.player2Name ?? 'Player 2';
    return 'Player';
  }

  @override
  Widget build(BuildContext context) {
    final claimed = _name(report.claimedWinnerId);
    final reporter =
        report.reporterName.isNotEmpty ? report.reporterName : _name(report.reporterId);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Screenshot(report: report),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$reporter reported',
                      style: const TextStyle(color: Colors.white54)),
                  const SizedBox(height: 2),
                  Text('Winner: $claimed',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Screenshot extends StatelessWidget {
  const _Screenshot({required this.report});
  final MatchReport report;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (report.screenshotBytes != null) {
      child = Image.memory(report.screenshotBytes!, fit: BoxFit.cover);
    } else if (report.screenshotUrl != null && report.screenshotUrl!.isNotEmpty) {
      child = CachedNetworkImage(imageUrl: report.screenshotUrl!, fit: BoxFit.cover);
    } else {
      child = const Icon(Icons.image_not_supported_outlined, color: Colors.white24);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 64,
        height: 64,
        color: AppColors.surfaceHigh,
        child: child,
      ),
    );
  }
}

class _DisputeResolver extends ConsumerWidget {
  const _DisputeResolver({required this.match});
  final GameMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppColors.danger.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resolve dispute',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Players disagree on the result. Pick the winner.',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ref
                        .read(matchesServiceProvider)
                        .resolveDispute(match, match.player1Id!),
                    child: Text(match.player1Name ?? 'Player 1'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ref
                        .read(matchesServiceProvider)
                        .resolveDispute(match, match.player2Id!),
                    child: Text(match.player2Name ?? 'Player 2'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sheets ─────────────────────────────────────────────────────
class _StreamSheet extends StatefulWidget {
  const _StreamSheet();
  @override
  State<_StreamSheet> createState() => _StreamSheetState();
}

class _StreamSheetState extends State<_StreamSheet> {
  StreamPlatform _platform = StreamPlatform.youtube;
  final _url = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add stream link',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: StreamPlatform.values
                .map((p) => ChoiceChip(
                      label: Text(p.label),
                      selected: _platform == p,
                      onSelected: (_) => setState(() => _platform = p),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
                labelText: 'Stream URL', prefixIcon: Icon(Icons.link)),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (_url.text.trim().isEmpty) return;
              Navigator.of(context)
                  .pop((p: _platform, url: _url.text.trim()));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.match,
    required this.reporterId,
    required this.reporterName,
  });
  final GameMatch match;
  final String reporterId;
  final String reporterName;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  String? _winnerId;
  Uint8List? _shot;
  bool _simulateDispute = false;
  bool _busy = false;

  bool get _opponentIsBot {
    final m = widget.match;
    final oppId =
        m.player1Id == widget.reporterId ? m.player2Id : m.player1Id;
    return oppId != null && oppId.startsWith('bot-');
  }

  Future<void> _pickShot() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) {
      final bytes = await x.readAsBytes();
      setState(() => _shot = bytes);
    }
  }

  Future<void> _submit() async {
    if (_winnerId == null) return;
    setState(() => _busy = true);
    await ref.read(matchesServiceProvider).reportResult(
          match: widget.match,
          reporterId: widget.reporterId,
          reporterName: widget.reporterName,
          claimedWinnerId: _winnerId!,
          screenshot: _shot,
          simulateDispute: _simulateDispute,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Report result',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Who won?', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _winnerChoice(m.player1Id, m.player1Name)),
              const SizedBox(width: 12),
              Expanded(child: _winnerChoice(m.player2Id, m.player2Name)),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickShot,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(_shot == null ? 'Attach screenshot' : 'Screenshot attached'),
          ),
          if (_shot != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_shot!, height: 120, fit: BoxFit.cover),
            ),
          ],
          if (_opponentIsBot) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _simulateDispute,
              onChanged: (v) => setState(() => _simulateDispute = v),
              title: const Text('Simulate opponent disagreeing'),
              subtitle: const Text('Triggers the dispute flow (demo).',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy || _winnerId == null ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit report'),
          ),
        ],
      ),
    );
  }

  Widget _winnerChoice(String? id, String? name) {
    final selected = _winnerId == id;
    return OutlinedButton(
      onPressed: id == null ? null : () => setState(() => _winnerId = id),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.violet.withValues(alpha: 0.25) : null,
        side: BorderSide(
            color: selected ? AppColors.violet : Colors.white24),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(name ?? 'TBD'),
    );
  }
}

// ── small shared bits ──
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.icon});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.cyan),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text, style: const TextStyle(color: Colors.white38)),
        ),
      );
}
