import '../../../domain/shared/knowledge_article.dart';

enum MotherKnowledgeTopic { body, rest, mood, lactation }

// Approved editorial content from the product design, not generated clinical advice.
const motherKnowledgeArticles = <MotherKnowledgeTopic, KnowledgeArticle>{
  MotherKnowledgeTopic.body: KnowledgeArticle(
    title: "Recovery is not a straight line",
    summary:
        "Your energy, discomfort, and daily needs may change from day to day. Tracking them over time can help you understand your body without pressure to “bounce back.”",
    points: [
      "Note where you feel discomfort, how strong it is, and whether it affects walking, resting, or caring for your baby.",
      "Comparing today with yesterday may tell you more about recovery than one isolated check-in.",
      "If discomfort suddenly worsens, gets in the way of caring for yourself, or worries you, contact a healthcare professional promptly.",
    ],
  ),
  MotherKnowledgeTopic.rest: KnowledgeArticle(
    title: "Rest is more than a number of hours",
    summary:
        "Even with the same total sleep time, interruptions, longest stretch, and how rested you feel may vary.",
    points: [
      "Total hours, interruptions, and longest stretch describe different aspects of rest. They do not need to become a single score.",
      "How rested you feel when you wake up adds context to the numbers and is worth noting.",
      "If ongoing fatigue affects daily life, share your records with a healthcare professional.",
    ],
  ),
  MotherKnowledgeTopic.mood: KnowledgeArticle(
    title: "Your feelings are not a score",
    summary:
        "Feeling tense, low, or easily overwhelmed does not mean you are doing anything wrong. Tracking your mood and what affects it may help you see what you need.",
    points: [
      "Choose the feeling that fits best right now. You do not need to reduce a complex day to “good” or “bad.”",
      "What is causing stress and whether it affects sleep or daily life may tell you more than a single mood label.",
      "If low mood or anxiety persists, worsens, or affects daily life, talk with a healthcare professional soon.",
    ],
  ),
  MotherKnowledgeTopic.lactation: KnowledgeArticle(
    title: "One pumping session does not define your body",
    summary:
        "The amount you pump can vary with time, intervals, and how you feel. Records show change over time, not your total milk production or ability to feed your baby.",
    points: [
      "Record the time, method, and side as they happened. One session does not measure your worth.",
      "Pumped milk amounts and nursing duration measure different things. They cannot be converted directly or combined into one number.",
      "If pain persists or you have feeding concerns, share your records with a healthcare or lactation professional.",
    ],
  ),
};
