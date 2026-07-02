import 'dart:typed_data';

enum CompetitionFormat {
  roundRobin,
  singleElim;

  static CompetitionFormat fromString(String? v) => switch (v) {
        'round_robin' => CompetitionFormat.roundRobin,
        'single_elim' => CompetitionFormat.singleElim,
        _ => CompetitionFormat.singleElim,
      };

  String get value =>
      this == CompetitionFormat.roundRobin ? 'round_robin' : 'single_elim';

  String get label => this == CompetitionFormat.roundRobin
      ? 'Round Robin'
      : 'Single Elimination';
}

enum CompetitionStatus {
  draft,
  open,
  ongoing,
  completed,
  cancelled;

  static CompetitionStatus fromString(String? v) =>
      CompetitionStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => CompetitionStatus.draft,
      );

  String get label => switch (this) {
        CompetitionStatus.draft => 'Draft',
        CompetitionStatus.open => 'Open',
        CompetitionStatus.ongoing => 'Ongoing',
        CompetitionStatus.completed => 'Completed',
        CompetitionStatus.cancelled => 'Cancelled',
      };
}

enum TechMeetingType {
  discord,
  whatsapp,
  other;

  static TechMeetingType fromString(String? v) =>
      TechMeetingType.values.firstWhere(
        (e) => e.name == v,
        orElse: () => TechMeetingType.other,
      );

  String get label => switch (this) {
        TechMeetingType.discord => 'Discord',
        TechMeetingType.whatsapp => 'WhatsApp',
        TechMeetingType.other => 'Other',
      };
}

class Competition {
  const Competition({
    required this.id,
    required this.organizerId,
    required this.title,
    required this.description,
    required this.format,
    required this.maxParticipants,
    required this.entryFee,
    required this.status,
    required this.slug,
    this.bannerUrl,
    this.prizePool = 0,
    this.techMeetingUrl,
    this.techMeetingType = TechMeetingType.other,
    this.startsAt,
    this.registrationDeadline,
    this.participantCount = 0,
    this.createdAt,
    this.bannerBytes,
    this.groupSize = 0,
    this.advancePerGroup = 2,
    this.hasPlayoff = false,
  });

  final String id;
  final String organizerId;
  final String title;
  final String description;
  final CompetitionFormat format;
  final int maxParticipants;
  final int entryFee;
  final CompetitionStatus status;
  final String slug;
  final String? bannerUrl;
  final int prizePool;
  final String? techMeetingUrl;
  final TechMeetingType techMeetingType;
  final DateTime? startsAt;

  /// Optional cutoff after which no new registrations are accepted.
  final DateTime? registrationDeadline;
  final int participantCount;
  final DateTime? createdAt;

  /// True when registration is closed by the deadline (independent of status).
  bool get registrationClosed =>
      registrationDeadline != null &&
      DateTime.now().isAfter(registrationDeadline!);

  /// Offline-only: in-memory banner image bytes (not persisted).
  final Uint8List? bannerBytes;

  /// Round-robin grouping: split players into groups of this size (0 = one
  /// group). With [hasPlayoff], the top [advancePerGroup] of each group advance
  /// to a final single-elimination playoff.
  final int groupSize;
  final int advancePerGroup;
  final bool hasPlayoff;

  /// Auto-generated public share link. Pass the configured [domain] (admin
  /// Configuration) to produce a real link; falls back to a placeholder.
  String shareUrlFor(String? domain) {
    final host = (domain == null || domain.isEmpty)
        ? 'protourney.example'
        : domain.replaceAll(RegExp(r'^https?://|/+$'), '');
    return 'https://$host/c/$slug';
  }

  String get shareUrl => shareUrlFor(null);

  bool get isFull => participantCount >= maxParticipants;

  Competition copyWith({
    String? title,
    String? description,
    CompetitionStatus? status,
    int? participantCount,
    String? bannerUrl,
    Uint8List? bannerBytes,
  }) =>
      Competition(
        id: id,
        organizerId: organizerId,
        title: title ?? this.title,
        description: description ?? this.description,
        format: format,
        maxParticipants: maxParticipants,
        entryFee: entryFee,
        status: status ?? this.status,
        slug: slug,
        bannerUrl: bannerUrl ?? this.bannerUrl,
        prizePool: prizePool,
        techMeetingUrl: techMeetingUrl,
        techMeetingType: techMeetingType,
        startsAt: startsAt,
        registrationDeadline: registrationDeadline,
        participantCount: participantCount ?? this.participantCount,
        createdAt: createdAt,
        bannerBytes: bannerBytes ?? this.bannerBytes,
        groupSize: groupSize,
        advancePerGroup: advancePerGroup,
        hasPlayoff: hasPlayoff,
      );

  factory Competition.fromMap(Map<String, dynamic> m) => Competition(
        id: m['id'] as String,
        organizerId: m['organizer_id'] as String,
        title: (m['title'] ?? '') as String,
        description: (m['description'] ?? '') as String,
        format: CompetitionFormat.fromString(m['format'] as String?),
        maxParticipants: (m['max_participants'] ?? 0) as int,
        entryFee: (m['entry_fee'] ?? 0) as int,
        status: CompetitionStatus.fromString(m['status'] as String?),
        slug: (m['slug'] ?? '') as String,
        bannerUrl: m['banner_url'] as String?,
        prizePool: (m['prize_pool'] ?? 0) as int,
        techMeetingUrl: m['tech_meeting_url'] as String?,
        techMeetingType:
            TechMeetingType.fromString(m['tech_meeting_type'] as String?),
        startsAt: m['starts_at'] == null
            ? null
            : DateTime.parse(m['starts_at'] as String),
        registrationDeadline: m['registration_deadline'] == null
            ? null
            : DateTime.parse(m['registration_deadline'] as String),
        participantCount: (m['participant_count'] ?? 0) as int,
        createdAt: m['created_at'] == null
            ? null
            : DateTime.parse(m['created_at'] as String),
        groupSize: (m['group_size'] ?? 0) as int,
        advancePerGroup: (m['advance_per_group'] ?? 2) as int,
        hasPlayoff: (m['has_playoff'] ?? false) as bool,
      );

  Map<String, dynamic> toInsert() => {
        'organizer_id': organizerId,
        'title': title,
        'description': description,
        'format': format.value,
        'max_participants': maxParticipants,
        'entry_fee': entryFee,
        'status': status.name,
        'slug': slug,
        'banner_url': bannerUrl,
        'prize_pool': prizePool,
        'tech_meeting_url': techMeetingUrl,
        'tech_meeting_type': techMeetingType.name,
        'starts_at': startsAt?.toIso8601String(),
        'registration_deadline': registrationDeadline?.toIso8601String(),
        'group_size': groupSize,
        'advance_per_group': advancePerGroup,
        'has_playoff': hasPlayoff,
      };
}
