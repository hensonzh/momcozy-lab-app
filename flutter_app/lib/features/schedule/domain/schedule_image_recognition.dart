enum ScheduleImageTaskKind { pumping, feeding, other }

class ScheduleImageTaskPreview {
  const ScheduleImageTaskPreview({
    required this.time,
    required this.title,
    required this.kind,
  });

  final String time;
  final String title;
  final ScheduleImageTaskKind kind;
}

class ScheduleImageRecognitionResult {
  const ScheduleImageRecognitionResult._({
    required this.cancelled,
    required this.tasks,
  });

  const ScheduleImageRecognitionResult.cancelled()
    : this._(cancelled: true, tasks: const <ScheduleImageTaskPreview>[]);

  ScheduleImageRecognitionResult.preview(List<ScheduleImageTaskPreview> tasks)
    : this._(
        cancelled: false,
        tasks: List<ScheduleImageTaskPreview>.unmodifiable(tasks),
      );

  final bool cancelled;
  final List<ScheduleImageTaskPreview> tasks;
}

abstract interface class ScheduleImageRecognitionGateway {
  Future<ScheduleImageRecognitionResult> pickAndRecognize();
}

class ScheduleImageRecognitionException implements Exception {
  const ScheduleImageRecognitionException(this.code, this.userMessage);

  final String code;
  final String userMessage;

  @override
  String toString() => 'ScheduleImageRecognitionException($code)';
}
