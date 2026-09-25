import 'package:flutter/material.dart';
import '../../../shared/widgets/mom_companion_widgets.dart';
export '../../../shared/widgets/mom_companion_widgets.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../application/mom_home_view_data.dart';

class MomHomeHeader extends StatelessWidget {
  const MomHomeHeader({super.key, required this.data});
  final MomHomeViewData data;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 58),
    child: Align(
      alignment: Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final large =
              MediaQuery.textScalerOf(context).scale(1) > 1.2 ||
              constraints.maxWidth < 328 ||
              data.greeting.length > 12;
          final greeting = Text(
            data.greeting,
            style: MomHomeTokens.text(20, weight: FontWeight.w700, height: 1.7),
          );
          final phase = Text(
            data.phaseLabel,
            style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
          );
          return large
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [greeting, phase],
                )
              : Row(
                  children: [
                    Expanded(child: greeting),
                    const SizedBox(width: 8),
                    phase,
                  ],
                );
        },
      ),
    ),
  );
}

class MomAiInsightCard extends StatelessWidget {
  const MomAiInsightCard({
    super.key,
    required this.insight,
    required this.onTap,
  });
  final MomDailyInsight insight;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MomHomeSurface(
    gradient: MomHomeTokens.ai,
    onTap: onTap,
    child: Stack(
      children: [
        Positioned(
          left: -42,
          bottom: -42,
          child: momDecoration('imgDecorationAiBlushGlow', 150, 92),
        ),
        Positioned(
          right: -37,
          top: -36,
          child: momDecoration('imgDecorationAiLilacGlow', 128, 128),
        ),
        Positioned(
          right: 27,
          top: 74,
          child: momDecoration('imgDecorationAiSparkle', 20, 20),
        ),
        Positioned(
          right: 18,
          top: 12,
          child: Image.asset(
            MomHomeAssets.cozymate,
            width: 50,
            height: 50,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 138),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 60),
                  child: Text(
                    insight.eyebrow,
                    style: MomHomeTokens.text(
                      12,
                      color: const Color(0xff665b8a),
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(right: 60),
                  child: Text(
                    insight.title,
                    style: MomHomeTokens.text(
                      16,
                      weight: FontWeight.w700,
                      height: 25 / 16,
                      color: const Color(0xff292733),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        insight.body,
                        style: MomHomeTokens.text(
                          11,
                          height: 17 / 11,
                          color: const Color(0xff706d78),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '→',
                      style: MomHomeTokens.text(
                        22,
                        color: const Color(0xff665b8a),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class MomLactationCard extends StatelessWidget {
  const MomLactationCard({
    super.key,
    required this.data,
    required this.onRecord,
  });
  final MomHomeViewData data;
  final VoidCallback onRecord;
  @override
  Widget build(BuildContext context) => MomHomeSurface(
    gradient: MomHomeTokens.milk,
    child: Stack(
      children: [
        Positioned(
          right: 17,
          top: 4,
          child: momDecoration('imgDecorationLactationDroplet', 42, 49),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 132),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: Text(
                    data.lactationValue,
                    style: MomHomeTokens.text(
                      data.lactationRecorded ? 22 : 18,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: onRecord,
                  style: FilledButton.styleFrom(
                    backgroundColor: MomHomeTokens.rose,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: const StadiumBorder(),
                    textStyle: MomHomeTokens.text(14, weight: FontWeight.w700),
                  ),
                  child: const Text('+ Log a feeding or pumping session'),
                ),
                const SizedBox(height: 8),
                Text(
                  data.lactationMeta,
                  style: MomHomeTokens.text(
                    10,
                    color: const Color(0xff7a6663),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class MomHomeSkeleton extends StatelessWidget {
  const MomHomeSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading your home page',
    child: ListView(
      padding: MomHomeTokens.padding,
      children: [
        for (final height in [58.0, 138.0, 44.0, 132.0, 184.0])
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: MomHomeTokens.border.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
      ],
    ),
  );
}
