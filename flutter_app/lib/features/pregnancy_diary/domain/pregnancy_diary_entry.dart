class PregnancyDiaryEntry {
  const PregnancyDiaryEntry({
    required this.id,
    required this.entryDate,
    required this.content,
    this.gestationalWeek = '',
    this.mood = '',
    this.energyLevel = '',
    this.sleepSummary = '',
    this.fetalMovement = '',
    this.symptomTags = const [],
    this.appointmentNote = '',
    this.nutritionNote = '',
    this.attachments = const [],
  });

  final String id;
  final DateTime entryDate;
  final String content;
  final String gestationalWeek;
  final String mood;
  final String energyLevel;
  final String sleepSummary;
  final String fetalMovement;
  final List<Object?> symptomTags;
  final String appointmentNote;
  final String nutritionNote;
  final List<Object?> attachments;
}

abstract interface class PregnancyDiaryRepository {
  Future<List<PregnancyDiaryEntry>> fetchEntries({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 7,
  });

  Future<PregnancyDiaryEntry> createEntry({
    required DateTime entryDate,
    required String content,
  });

  Future<PregnancyDiaryEntry> updateEntry({
    required DateTime entryDate,
    required String content,
  });

  Future<void> deleteEntry({required DateTime entryDate});
}
