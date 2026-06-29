import 'dart:typed_data';

/// A player's post-match report: who they say won + a screenshot.
class MatchReport {
  const MatchReport({
    required this.id,
    required this.matchId,
    required this.reporterId,
    required this.reporterName,
    required this.claimedWinnerId,
    this.screenshotUrl,
    this.screenshotBytes,
  });

  final String id;
  final String matchId;
  final String reporterId;
  final String reporterName;
  final String claimedWinnerId;
  final String? screenshotUrl;

  /// Offline-only: in-memory screenshot bytes (not persisted).
  final Uint8List? screenshotBytes;

  factory MatchReport.fromMap(Map<String, dynamic> m, {String? reporterName}) =>
      MatchReport(
        id: m['id'] as String,
        matchId: m['match_id'] as String,
        reporterId: m['reporter_id'] as String,
        reporterName: reporterName ?? (m['reporter_name'] as String? ?? 'Player'),
        claimedWinnerId: (m['claimed_winner_id'] ?? '') as String,
        screenshotUrl: m['screenshot_url'] as String?,
      );

  Map<String, dynamic> toInsert() => {
        'match_id': matchId,
        'reporter_id': reporterId,
        'claimed_winner_id': claimedWinnerId,
        'screenshot_url': screenshotUrl,
      };
}
