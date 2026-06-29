enum StreamPlatform {
  youtube,
  tiktok,
  twitch,
  other;

  static StreamPlatform fromString(String? v) =>
      StreamPlatform.values.firstWhere(
        (e) => e.name == v,
        orElse: () => StreamPlatform.other,
      );

  String get label => switch (this) {
        StreamPlatform.youtube => 'YouTube',
        StreamPlatform.tiktok => 'TikTok',
        StreamPlatform.twitch => 'Twitch',
        StreamPlatform.other => 'Other',
      };
}

class MatchStreamEntry {
  const MatchStreamEntry({
    required this.id,
    required this.matchId,
    required this.userId,
    required this.platform,
    required this.url,
  });

  final String id;
  final String matchId;
  final String userId;
  final StreamPlatform platform;
  final String url;

  factory MatchStreamEntry.fromMap(Map<String, dynamic> m) => MatchStreamEntry(
        id: m['id'] as String,
        matchId: m['match_id'] as String,
        userId: m['user_id'] as String,
        platform: StreamPlatform.fromString(m['platform'] as String?),
        url: (m['url'] ?? '') as String,
      );

  Map<String, dynamic> toInsert() => {
        'match_id': matchId,
        'user_id': userId,
        'platform': platform.name,
        'url': url,
      };
}
