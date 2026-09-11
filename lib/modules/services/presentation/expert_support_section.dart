import '../../../shared/care/care_labels.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../domain/care/care_episode.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/service_package.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../application/care_overview_controller.dart';

class ExpertSupportSection extends StatefulWidget {
  const ExpertSupportSection({
    super.key,
    required this.repository,
    required this.onCatalog,
    required this.onProgress,
    required this.onBook,
  });
  final CareRepository repository;
  final Future<void> Function() onCatalog;
  final Future<void> Function(CareEpisode) onProgress, onBook;
  @override
  State<ExpertSupportSection> createState() => _ExpertSupportSectionState();
}

class _ExpertSupportSectionState extends State<ExpertSupportSection> {
  late final controller = CareOverviewController(widget.repository);
  bool _navigating = false;

  Future<void> _open(Future<void> Function() navigate) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await navigate();
      if (mounted) await controller.load();
    } finally {
      _navigating = false;
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(controller.load());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final data = controller.overview;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MomCozySectionHeading(
            title: '专家支持',
            icon: Icons.volunteer_activism_outlined,
            action: data?.episodes.isNotEmpty == true
                ? TextButton(
                    onPressed: () => _open(widget.onCatalog),
                    child: const Text(
                      '其他服务包 →',
                      style: TextStyle(fontSize: MomCozyTypography.captionSize),
                    ),
                  )
                : null,
          ),
          if (controller.loading && data == null)
            const ProductLoadingView()
          else if (controller.failure case final failure?)
            ProductErrorView(failure: failure, onRetry: controller.load)
          else if (data != null && data.episodes.isEmpty)
            OutlinedButton(
              onPressed: () => _open(widget.onCatalog),
              style: OutlinedButton.styleFrom(padding: MomCozyInsets.card),
              child: const Row(
                children: [
                  Icon(Icons.people_outline_rounded, size: 30),
                  SizedBox(width: MomCozySpacing.headingGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '按需选择专家支持',
                          style: TextStyle(
                            fontSize: MomCozyTypography.titleSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          '当前 4 类泌乳方案 · 更多方向陆续加入',
                          style: TextStyle(
                            fontSize: MomCozyTypography.labelSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            )
          else
            for (final episode in data?.episodes ?? <CareEpisode>[])
              if (controller.catalog!.packages
                      .where((item) => item.id == episode.packageId)
                      .firstOrNull
                  case final package?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ExpertServiceCard(
                    episode: episode,
                    package: package,
                    provider: controller.catalog!.providers
                        .where((item) => item.id == episode.assignedIbclcId)
                        .firstOrNull,
                    onProgress: () => _open(() => widget.onProgress(episode)),
                    onBook: () => _open(() => widget.onBook(episode)),
                  ),
                ),
        ],
      );
    },
  );
}

class ExpertServiceCard extends StatelessWidget {
  const ExpertServiceCard({
    super.key,
    required this.episode,
    required this.package,
    required this.onProgress,
    required this.onBook,
    this.provider,
  });
  final CareEpisode episode;
  final ServicePackage package;
  final CareProvider? provider;
  final VoidCallback onProgress, onBook;
  @override
  Widget build(BuildContext context) => MomCozySurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.circle, size: 6, color: MomCozyColors.care),
            const SizedBox(width: 6),
            Text(
              episodeStatusLabels[episode.status]!,
              style: const TextStyle(
                fontSize: MomCozyTypography.captionSize,
                color: MomCozyColors.care,
              ),
            ),
          ],
        ),
        const SizedBox(height: MomCozySpacing.statusGap),
        Text(
          package.name,
          style: const TextStyle(
            fontSize: MomCozyTypography.headingSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: MomCozySpacing.page),
        Row(
          children: [
            CircleAvatar(
              backgroundColor: MomCozyColors.violetSoft,
              child: Text(
                provider?.displayName.characters.firstOrNull ?? 'IB',
                style: const TextStyle(color: MomCozyColors.violet),
              ),
            ),
            const SizedBox(width: MomCozySpacing.content),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider?.displayName ?? 'IBCLC 专家团队',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    provider == null ? '预约时确认本次专家' : 'IBCLC · 哺乳顾问',
                    style: const TextStyle(
                      fontSize: MomCozyTypography.labelSize,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: MomCozySpacing.card),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            Text('${package.durationDays} 天支持'),
            Text('剩余 ${episode.remainingSessions} 次咨询'),
          ],
        ),
        const Divider(height: 30),
        Text(
          careStageLabels[episode.stage]!,
          style: const TextStyle(
            fontSize: MomCozyTypography.labelSize,
            color: MomCozyColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          episode.canBook
              ? '可预约下一次咨询'
              : episode.remainingSessions == 0
              ? '本服务包的咨询权益已用完'
              : episodeStatusLabels[episode.status]!,
        ),
        const SizedBox(height: MomCozySpacing.page),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: onProgress,
                child: const Text('服务进度 ›'),
              ),
            ),
            const SizedBox(width: MomCozySpacing.content),
            Expanded(
              child: FilledButton(
                onPressed: episode.canBook ? onBook : null,
                child: const Text('预约咨询'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
