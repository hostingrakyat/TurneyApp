import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../../../shared/models/competition.dart';
import '../../../shared/widgets/brand.dart';

class CompetitionCard extends StatelessWidget {
  const CompetitionCard({super.key, required this.competition, this.onTap});

  final Competition competition;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = competition;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(competition: c),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TagPill(c.format.label,
                          icon: c.format == CompetitionFormat.roundRobin
                              ? Icons.sync_alt
                              : Icons.account_tree),
                      TagPill(
                        '${c.participantCount}/${c.maxParticipants}',
                        icon: Icons.group,
                        color: c.isFull ? AppColors.danger : AppColors.cyan,
                      ),
                      if (c.prizePool > 0)
                        TagPill('Prize ${Format.rupiah(c.prizePool)}',
                            icon: Icons.military_tech, color: AppColors.gold),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        Format.rupiah(c.entryFee),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: c.entryFee == 0
                              ? AppColors.success
                              : Colors.white,
                        ),
                      ),
                      const Spacer(),
                      if (c.startsAt != null)
                        Text(Format.date(c.startsAt!),
                            style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.competition});
  final Competition competition;

  @override
  Widget build(BuildContext context) {
    final url = competition.bannerUrl;
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: url != null && url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const _GradientBanner(),
              placeholder: (_, __) => const _GradientBanner(),
            )
          : const _GradientBanner(),
    );
  }
}

class _GradientBanner extends StatelessWidget {
  const _GradientBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.brand),
      child: const Center(
        child: Icon(Icons.account_tree, color: Colors.white24, size: 44),
      ),
    );
  }
}
