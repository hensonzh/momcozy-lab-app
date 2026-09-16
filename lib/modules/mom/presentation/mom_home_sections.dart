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
                  child: const Text('＋ 记录一次泌乳'),
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

class MomRecoveryStatus extends StatelessWidget {
  const MomRecoveryStatus({
    super.key,
    required this.data,
    required this.onBody,
    required this.onRest,
    required this.onMood,
  });
  final MomHomeViewData data;
  final VoidCallback onBody, onRest;
  final ValueChanged<int?> onMood;
  @override
  Widget build(BuildContext context) {
    final body = _StatusCard(
      title: '身体与精力',
      value: data.bodyValue,
      recorded: data.bodyRecorded,
      meta: data.bodyMeta,
      gradient: MomHomeTokens.body,
      onTap: onBody,
      body: true,
    );
    final rest = _StatusCard(
      title: '昨夜休息',
      value: data.sleepValue,
      recorded: data.sleepRecorded,
      meta: data.sleepMeta,
      gradient: MomHomeTokens.sleep,
      onTap: onRest,
      body: false,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (MediaQuery.textScalerOf(context).scale(1) > 1.3)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [body, const SizedBox(height: 12), rest],
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: body),
                const SizedBox(width: 11),
                Expanded(child: rest),
              ],
            ),
          ),
        const SizedBox(height: 12),
        _MoodCard(data: data, onMood: onMood),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.value,
    required this.meta,
    required this.gradient,
    required this.onTap,
    required this.body,
    required this.recorded,
  });
  final String title, value, meta;
  final Gradient gradient;
  final VoidCallback onTap;
  final bool body, recorded;
  @override
  Widget build(BuildContext context) => MomHomeSurface(
    gradient: gradient,
    radius: 20,
    onTap: onTap,
    semanticLabel: '$title，$value',
    child: Stack(
      children: [
        if (body) ...[
          Positioned(
            right: -43,
            bottom: -26,
            child: momDecoration('imgDecorationBodyRecoveryGlow', 92, 92),
          ),
          Positioned(
            right: -38,
            bottom: -21,
            child: momDecoration('imgDecorationBodyRecoveryRing', 76, 76),
          ),
          Positioned(
            right: 28,
            bottom: 3,
            child: momDecoration('imgDecorationBodyRecoverySoftDot', 28, 28),
          ),
        ] else
          Positioned(
            right: 9,
            top: 14,
            child: momDecoration('imgDecorationSleepCrescent', 42, 42),
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 108),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MomHomeTokens.text(12, color: const Color(0xff66574a)),
                ),
                const SizedBox(height: 14),
                Text(
                  value,
                  style: MomHomeTokens.text(
                    recorded ? 22 : 18,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  meta,
                  style: MomHomeTokens.text(10, color: const Color(0xff7a6957)),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.data, required this.onMood});
  final MomHomeViewData data;
  final ValueChanged<int?> onMood;
  @override
  Widget build(BuildContext context) => MomHomeSurface(
    gradient: MomHomeTokens.mood,
    radius: 20,
    child: Stack(
      children: [
        Positioned(
          right: 25,
          top: 0,
          child: momDecoration('imgDecorationMoodWave', 210, 64),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LayoutBuilder(
            builder: (context, c) {
              final title = Semantics(
                button: true,
                child: InkWell(
                  onTap: () => onMood(null),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '今日心情',
                          style: MomHomeTokens.text(
                            11,
                            color: const Color(0xff755e59),
                          ),
                        ),
                        Text(
                          data.moodValue,
                          style: MomHomeTokens.text(
                            13,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              final choices = Wrap(
                spacing: 6,
                children: [
                  for (var i = 0; i < 3; i++)
                    Semantics(
                      selected: data.moodSelection == i,
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onMood(i),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: data.moodSelection == i
                                    ? MomHomeTokens.rose
                                    : const Color(0xfffff9f7),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                ['不太好', '一般', '不错'][i],
                                style: MomHomeTokens.text(
                                  10,
                                  color: data.moodSelection == i
                                      ? Colors.white
                                      : const Color(0xff85595e),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
              if (c.maxWidth < 329 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.2) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, choices],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 4),
                  choices,
                ],
              );
            },
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
    label: '正在加载妈妈首页',
    child: ListView(
      padding: MomHomeTokens.padding,
      children: [
        for (final height in [58.0, 138.0, 44.0, 132.0, 44.0, 184.0, 88.0])
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
