import '../../../domain/shared/knowledge_article.dart';

enum MotherKnowledgeTopic { body, rest, mood, lactation }

// Approved editorial content from the product design, not generated clinical advice.
const motherKnowledgeArticles = <MotherKnowledgeTopic, KnowledgeArticle>{
  MotherKnowledgeTopic.body: KnowledgeArticle(
    title: "恢复不是直线，变化本身也值得被看见",
    summary: "体力、不适部位和对日常照护的影响可能每天不同。连续记录这些变化，比要求自己尽快“恢复正常”更能帮你理解身体。",
    points: [
      "先写下今天实际感受到的部位、程度，以及是否影响走路、休息或照护宝宝。",
      "把今天和昨天放在一起看，通常比孤立的一次感受更容易看见恢复过程。",
      "如果不适突然加重、妨碍照顾自己或让你担心，请及时联系医疗专业人员。",
    ],
  ),
  MotherKnowledgeTopic.rest: KnowledgeArticle(
    title: "休息不只看时长，也要看身体有没有缓过来",
    summary: "同样的睡眠时长，被打断次数、最长连续休息和醒来后的恢复感不同，身体的负担也可能不同。",
    points: [
      "总时长、被打断次数和最长连续休息，描述的是不同维度，不需要合成一个分数。",
      "醒来后的恢复感能补充数字没有说出的部分，也值得和睡眠时长一起记录。",
      "如果持续疲惫已经影响日常生活，可以把连续记录带给医疗专业人员一起讨论。",
    ],
  ),
  MotherKnowledgeTopic.mood: KnowledgeArticle(
    title: "情绪不是成绩，它也在告诉你需要什么",
    summary: "紧绷、低落或容易被触发，并不代表你做得不好。连续记录情绪、压力来源和日常影响，有助于更早看见自己的需要。",
    points: [
      "记录当下最接近的感受即可，不需要把复杂情绪压缩成“好”或“不好”。",
      "压力来自哪里、是否影响睡眠或日常事情，往往比一次情绪标签更有信息。",
      "如果低落或焦虑持续、加重，或已经影响日常生活，请尽早和医疗专业人员沟通。",
    ],
  ),
  MotherKnowledgeTopic.lactation: KnowledgeArticle(
    title: "一次泌乳记录，不定义你的身体",
    summary: "单次泵奶量会受到时间、间隔和当时状态影响；连续记录适合用来回看变化，不等于你的总产奶量或喂养能力。",
    points: [
      "按实际发生的时间、方式和侧别记录，不需要用一次结果评价自己。",
      "泵奶量和亲喂时长是不同口径，不能直接相互换算，也不必合成一个数字。",
      "如果持续疼痛或对喂养有担心，可以把连续记录带给医疗或泌乳专业人员。",
    ],
  ),
};
