import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_knowledge_content.dart';
import 'package:url_launcher/url_launcher.dart';

// General education, never selected from a child's records or inferred health.
const _knowledge =
    <
      BabyKnowledgeTopic,
      ({String title, String summary, List<String> points, String question})
    >{
      BabyKnowledgeTopic.feeding: (
        title: '观察喂养节奏',
        summary: '不同的喂养记录呈现不同信息，连续观察比单次数字更有帮助。',
        points: [
          '记录实际发生的喂养时间和方式。',
          '瓶喂奶量仅代表已记录的数值；亲喂时长不能直接换算成奶量。',
          '如果担心宝宝的摄入情况，可以带着多天记录咨询儿科或喂养专业人员。',
        ],
        question: '关于观察宝宝的喂养节奏，我想了解哪些基本方法？',
      ),
      BabyKnowledgeTopic.feedingCues: (
        title: '认识饥饿与吃饱信号',
        summary: '留意宝宝的行为，而不只看时钟或单次奶量。',
        points: [
          '手靠近嘴巴、转向乳房或奶瓶、咂嘴，可能是饥饿信号。',
          '闭嘴、转头或放松双手，可能表示已经吃饱。',
          '每个宝宝都有差异，尝试结合多次观察理解节奏。',
        ],
        question: '关于宝宝饥饿和吃饱的信号，我想了解哪些基本知识？',
      ),
      BabyKnowledgeTopic.sleep: (
        title: '宝宝安全睡眠',
        summary: '记录睡眠时长的同时，每次睡眠都要留意安全的睡眠环境。',
        points: [
          '每次睡眠都让宝宝仰卧，使用坚实、平坦的睡眠表面。',
          '睡眠空间保持简洁，不放枕头、松散被褥或毛绒玩具。',
          '起止时间可帮助观察睡眠节奏，但不能代替对睡眠环境的检查。',
        ],
        question: '关于宝宝安全睡眠，我想了解哪些基本注意事项？',
      ),
      BabyKnowledgeTopic.diaper: (
        title: '观察尿布与便便',
        summary: '记录湿尿布和便便的实际情况，不确定颜色或性状时不要猜测。',
        points: [
          '分别记录湿尿布与便便，留意随时间发生的变化。',
          '如果便便明显呈红色、灰白色，或胎便阶段后仍持续黑色，请尽快咨询儿科医生。',
        ],
        question: '关于观察宝宝尿布和便便，我想了解哪些基本知识？',
      ),
      BabyKnowledgeTopic.growth: (
        title: '看待生长记录',
        summary: '体重、身长和头围需要结合年龄与连续测量理解。',
        points: ['尽可能在相近条件下测量，并记录实际测量日期。', '单次波动不足以判断生长状况；专业评估还会结合生长曲线和整体情况。'],
        question: '关于记录宝宝的生长变化，我想了解哪些基本方法？',
      ),
      BabyKnowledgeTopic.development: (
        title: '观察宝宝发育',
        summary: '记录具体、带日期的观察，不将“尚未观察到”视作能力结论。',
        points: ['只记录实际看到或听到的动作、声音与反应。', '发育里程碑信息不能替代规范筛查；如有疑虑，请与儿科医生讨论。'],
        question: '关于观察宝宝的发育表现，我想了解哪些基本方法？',
      ),
    };

Future<void> showChatFirstBabyKnowledge(
  BuildContext context, {
  ValueChanged<String>? onAsk,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: const Color(0xFFFFFDFA),
  builder: (_) => _BabyKnowledgeSheet(onAsk: onAsk),
);

class _BabyKnowledgeSheet extends StatefulWidget {
  const _BabyKnowledgeSheet({this.onAsk});

  final ValueChanged<String>? onAsk;

  @override
  State<_BabyKnowledgeSheet> createState() => _BabyKnowledgeSheetState();
}

class _BabyKnowledgeSheetState extends State<_BabyKnowledgeSheet> {
  BabyKnowledgeTopic? _selected;

  Future<void> _openSource(String url) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // The source URL is static; an unavailable browser is not a health result.
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂时无法打开来源，请稍后重试。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final article = selected == null ? null : _knowledge[selected]!;
    final source = selected == BabyKnowledgeTopic.development
        ? (
            label: 'CDC · Developmental Milestones',
            url: 'https://www.cdc.gov/act-early/milestones/index.html',
          )
        : selected == null
        ? null
        : babyKnowledgeArticles[selected]?.source;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                if (selected != null)
                  IconButton(
                    tooltip: '返回知识目录',
                    onPressed: () => setState(() => _selected = null),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                Expanded(
                  child: Text(
                    article?.title ?? '照护知识',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭照护知识',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: selected == null
                  ? [
                      const Text(
                        '以下为通用照护信息，不依据当前宝宝的记录评估健康。',
                        style: TextStyle(color: Color(0xFF77717B)),
                      ),
                      const SizedBox(height: 18),
                      for (final topic in BabyKnowledgeTopic.values)
                        Card(
                          color: Colors.white,
                          child: ListTile(
                            key: ValueKey('baby-knowledge-topic-${topic.name}'),
                            title: Text(_knowledge[topic]!.title),
                            subtitle: Text(_knowledge[topic]!.summary),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => setState(() => _selected = topic),
                          ),
                        ),
                    ]
                  : [
                      Text(
                        article!.summary,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 18),
                      for (final point in article.points) ...[
                        Text('• $point', style: const TextStyle(height: 1.5)),
                        const SizedBox(height: 12),
                      ],
                      if (source != null) ...[
                        Text('来源：${source.label}'),
                        TextButton(
                          onPressed: () => _openSource(source.url),
                          child: const Text('查看原始来源'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        '以上为通用照护信息，不依据当前宝宝的记录评估健康，也不能代替专业诊疗。',
                        style: TextStyle(color: Color(0xFF77717B)),
                      ),
                    ],
            ),
          ),
          if (article != null && widget.onAsk != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('baby-knowledge-ask'),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onAsk!(article.question);
                  },
                  child: const Text('带着问题去对话'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
