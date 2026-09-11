import '../../../domain/shared/knowledge_article.dart';

enum BabyKnowledgeTopic {
  feeding,
  feedingCues,
  sleep,
  diaper,
  growth,
  development,
}

// Source pages checked on 2026-09-08; educational copy follows the product baseline.
const babyKnowledgeArticles = <BabyKnowledgeTopic, KnowledgeArticle>{
  BabyKnowledgeTopic.feeding: KnowledgeArticle(
    title: "每一顿不必一样，连续记录更有意义",
    summary: "喂养次数、间隔和实际记录的奶量各自说明不同的事。把几天的记录放在一起看，比盯住某一顿更容易理解宝宝的节奏。",
    points: [
      "先看每次发生的时间和一天的次数，不需要追求完全整齐的间隔。",
      "瓶喂量只代表实际填写的毫升数；亲喂时长不能直接换算成摄入量。",
      "如果担心宝宝吃得太多或太少，把连续记录带给儿科医生或喂养专业人员一起判断。",
    ],
    source: (
      label: "CDC · 婴幼儿营养",
      url:
          "https://www.cdc.gov/infant-toddler-nutrition/breastfeeding/how-much-and-how-often.html",
    ),
  ),
  BabyKnowledgeTopic.feedingCues: KnowledgeArticle(
    title: "比时间表更早出现的，是宝宝的饥饱信号",
    summary: "新生宝宝会用动作表达需要。把记录时间和当时看到的信号放在一起回想，能更从容地认识宝宝自己的节奏。",
    points: [
      "手靠近嘴、转头寻找乳房或奶瓶、咂嘴，可能是在表达饥饿。",
      "闭嘴、转开头或双手放松，可能是在表达已经吃饱。",
      "每个宝宝都不完全一样；连续观察比用一次表现下结论更可靠。",
    ],
    source: (
      label: "CDC · 饥饿与饱足信号",
      url:
          "https://www.cdc.gov/infant-toddler-nutrition/mealtime/signs-your-child-is-hungry-or-full.html",
    ),
  ),
  BabyKnowledgeTopic.sleep: KnowledgeArticle(
    title: "记录睡眠，也要把安全睡眠放在第一位",
    summary: "睡眠段数和时长帮助你看见节奏；睡眠姿势与环境则需要每一次都重新确认。",
    points: [
      "每次睡眠都让宝宝仰卧，并使用坚实、平坦的睡眠表面。",
      "睡眠区域只保留合身床单，不放枕头、松软被褥、防撞垫或毛绒玩具。",
      "起止时间适合用来统计总时长和最长连续睡眠，但不能代替对睡眠环境的检查。",
    ],
    source: (
      label: "CDC · 婴儿安全睡眠",
      url: "https://www.cdc.gov/sudden-infant-death/sleep-safely/",
    ),
  ),
  BabyKnowledgeTopic.diaper: KnowledgeArticle(
    title: "尿布里的连续变化，比单次印象更有信息",
    summary: "尿湿次数、便便时间、颜色和性状分开记录，之后回看或与医生沟通时会更清楚。",
    points: [
      "按次记录实际看到的尿湿或便便，不确定颜色或性状时不需要猜。",
      "便便频率本来就可能有较大差异，连续变化通常比某一次更值得回看。",
      "若明确看到红色、灰白色，或已过最初胎便阶段仍是黑色，应尽快联系儿科医生确认。",
    ],
    source: (
      label: "AAP HealthyChildren · 婴儿便便颜色",
      url:
          "https://www.healthychildren.org/English/ages-stages/baby/Pages/The-Many-Colors-of-Poop.aspx",
    ),
  ),
  BabyKnowledgeTopic.growth: KnowledgeArticle(
    title: "看成长，关键是同一口径下的连续变化",
    summary: "体重、身长和头围需要结合年龄与连续测量来理解，单独一个数字不能说明宝宝的生长状态。",
    points: [
      "尽量在相近条件下测量，并记下实际测量日期。",
      "先比较一段时间内的变化，不用让一次波动替你下结论。",
      "正式评估应由专业人员结合标准生长曲线、喂养和整体情况完成。",
    ],
    source: (
      label: "WHO · 儿童生长标准",
      url: "https://www.who.int/tools/child-growth-standards/standards",
    ),
  ),
  BabyKnowledgeTopic.development: KnowledgeArticle(
    title: "一次没看到，不等于宝宝不会",
    summary: "发育观察适合记录带日期的具体行为，而不是给宝宝打分。持续观察会比一次结果更接近真实情况。",
    points: [
      "只写你实际看到的动作、声音或反应，并保留观察日期。",
      "“尚未观察到”只描述这一次，不应直接解释为宝宝做不到。",
      "里程碑清单不能代替标准化发育筛查；有担心时应和宝宝的医生沟通。",
    ],
    source: (
      label: "CDC · 婴幼儿发育里程碑",
      url: "https://www.cdc.gov/act-early/milestones/2-months.html",
    ),
  ),
};
