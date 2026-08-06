import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/env.dart';
import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../../../shared/models/competition.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/surface.dart';

class CompetitionCard extends StatelessWidget {
  const CompetitionCard({super.key, required this.competition, this.onTap});

  final Competition competition;
  final VoidCallback? onTap;

  IconData get _formatIcon => switch (competition.format) {
        CompetitionFormat.roundRobin => Icons.sync_alt,
        CompetitionFormat.freeForAll => Icons.groups,
        CompetitionFormat.singleElim => Icons.account_tree,
      };

  @override
  Widget build(BuildContext context) {
    final c = competition;
    final free = c.entryFee == 0;
    return PanelSurface(
      padding: EdgeInsets.zero,
      radius: 22,
      pattern: PatternType.grid,
      patternOpacity: 0.10,
      patternSpacing: 26,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Banner(competition: c, formatIcon: _formatIcon),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TagPill(c.format.label, icon: _formatIcon),
                        TagPill(
                          '${c.participantCount}/${c.maxParticipants}',
                          icon: Icons.group,
                          color: c.isFull ? AppColors.danger : AppColors.cyan,
                        ),
                        // Prize money is hidden in store builds.
                        if (Env.paymentsEnabled && c.prizePool > 0)
                          TagPill(Format.rupiah(c.prizePool),
                              icon: Icons.military_tech,
                              color: AppColors.gold),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(
                        height: 1, color: Colors.white.withValues(alpha: 0.06)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (Env.paymentsEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: (free ? AppColors.success : Colors.white)
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              Format.rupiah(c.entryFee),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color:
                                    free ? AppColors.success : Colors.white,
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (c.startsAt != null) ...[
                          const Icon(Icons.event,
                              size: 15, color: Colors.white38),
                          const SizedBox(width: 6),
                          Text(Format.date(c.startsAt!),
                              style: const TextStyle(color: Colors.white54)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.competition, required this.formatIcon});
  final Competition competition;
  final IconData formatIcon;

  @override
  Widget build(BuildContext context) {
    final url = competition.bannerUrl;
    final bytes = competition.bannerBytes;
    return SizedBox(
      height: 126,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bytes != null)
            Image.memory(bytes, fit: BoxFit.cover)
          else if (url != null && url.isNotEmpty)
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _GradientBanner(icon: formatIcon),
              placeholder: (_, __) => _GradientBanner(icon: formatIcon),
            )
          else
            _GradientBanner(icon: formatIcon),
          // Scrim so the card body reads as one continuous surface.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (competition.status == CompetitionStatus.open)
            Positioned(
              top: 10,
              right: 10,
              child: TagPill(competition.status.label,
                  color: AppColors.success),
            ),
        ],
      ),
    );
  }
}

class _GradientBanner extends StatelessWidget {
  const _GradientBanner({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.brand)),
        const PatternOverlay(
            type: PatternType.bracket, opacity: 0.18, spacing: 20),
        Center(child: Icon(icon, color: Colors.white30, size: 42)),
      ],
    );
  }
}
