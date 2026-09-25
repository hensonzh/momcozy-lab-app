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
    title: "Every feeding can be different. Patterns matter more.",
    summary:
        "Feeding frequency, timing, and recorded milk amounts tell different parts of the story. Looking at several days together can help you understand your baby's rhythm.",
    points: [
      "Look at when feedings happen and how many occur each day. They do not need to be evenly spaced.",
      "Bottle amounts reflect only what you recorded. Nursing time cannot be converted directly into milk intake.",
      "If you are worried about how much your baby is eating, share several days of records with your pediatrician or a feeding professional.",
    ],
    source: (
      label: "CDC · Infant and Toddler Nutrition",
      url:
          "https://www.cdc.gov/infant-toddler-nutrition/breastfeeding/how-much-and-how-often.html",
    ),
  ),
  BabyKnowledgeTopic.feedingCues: KnowledgeArticle(
    title: "Notice hunger and fullness cues, not just the clock",
    summary:
        "Babies show what they need through their behavior. Pair feeding times with the cues you noticed to better understand your baby's rhythm.",
    points: [
      "Hands near the mouth, turning toward the breast or bottle, or smacking lips may be signs of hunger.",
      "Closing the mouth, turning away, or relaxing the hands may be signs of fullness.",
      "Every baby is different. Look for patterns over time rather than relying on a single feeding.",
    ],
    source: (
      label: "CDC · Hunger and Fullness Cues",
      url:
          "https://www.cdc.gov/infant-toddler-nutrition/mealtime/signs-your-child-is-hungry-or-full.html",
    ),
  ),
  BabyKnowledgeTopic.sleep: KnowledgeArticle(
    title: "Track sleep while keeping safe sleep first",
    summary:
        "Sleep duration can help you see a pattern. Check your baby's sleep position and surroundings every time.",
    points: [
      "Place your baby on their back for every sleep, on a firm, flat sleep surface.",
      "Keep only a fitted sheet in the sleep space. Leave out pillows, loose bedding, bumpers, and stuffed toys.",
      "Start and end times can show total and longest stretches of sleep, but they do not replace a check of the sleep space.",
    ],
    source: (
      label: "CDC · Safe Sleep for Babies",
      url: "https://www.cdc.gov/sudden-infant-death/sleep-safely/",
    ),
  ),
  BabyKnowledgeTopic.diaper: KnowledgeArticle(
    title: "Diaper patterns tell you more than one change",
    summary:
        "Track wet and dirty diapers, stool color, and consistency separately so you can discuss changes more clearly with your baby's doctor.",
    points: [
      "Record the daily totals for wet and dirty diapers. If you are unsure about color or consistency, do not guess.",
      "Stool frequency can vary. Changes over time are often more useful to review than a single diaper.",
      "If stool is clearly red or pale, or stays black after the first meconium stools, contact your pediatrician promptly.",
    ],
    source: (
      label: "AAP HealthyChildren · Baby Stool Colors",
      url:
          "https://www.healthychildren.org/English/ages-stages/baby/Pages/The-Many-Colors-of-Poop.aspx",
    ),
  ),
  BabyKnowledgeTopic.growth: KnowledgeArticle(
    title: "Growth is about change over time",
    summary:
        "Weight, length, and head circumference make more sense alongside your baby's age and a series of measurements. One number does not tell the whole story.",
    points: [
      "When possible, measure under similar conditions and record the actual measurement date.",
      "Compare changes over time rather than drawing conclusions from a single fluctuation.",
      "A professional assessment should consider standard growth charts, feeding, and your baby's overall health.",
    ],
    source: (
      label: "WHO · Child Growth Standards",
      url: "https://www.who.int/tools/child-growth-standards/standards",
    ),
  ),
  BabyKnowledgeTopic.development: KnowledgeArticle(
    title: "Not seeing it once does not mean your baby cannot do it",
    summary:
        "Development notes are for recording specific, dated behaviors, not scoring your baby. Observations over time give a fuller picture.",
    points: [
      "Record only the movements, sounds, or responses you actually see, along with the date.",
      "“Not observed yet” describes this observation, not what your baby is capable of.",
      "Milestone lists do not replace standardized developmental screening. Talk with your baby's doctor if you have concerns.",
    ],
    source: (
      label: "CDC · Developmental Milestones",
      url: "https://www.cdc.gov/act-early/milestones/2-months.html",
    ),
  ),
};
