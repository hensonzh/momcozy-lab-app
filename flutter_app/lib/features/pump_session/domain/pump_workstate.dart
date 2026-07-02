abstract interface class PumpWorkstateRepository {
  Future<PumpWorkstateReply> uploadWorkstate({
    String deviceId = 'app-pump-session',
    PumpSideWorkstate? left,
    PumpSideWorkstate? right,
  });
}

class PumpSideWorkstate {
  const PumpSideWorkstate({
    required this.state,
    required this.mode,
    required this.level,
  });

  final int state;
  final String mode;
  final int level;

  Map<String, Object?> toRequestJson() {
    return {'state': state, 'mode': mode, 'level': level};
  }
}

class PumpWorkstateReply {
  const PumpWorkstateReply({
    required this.needReply,
    required this.output,
    this.replyCode,
    this.replySide,
  });

  final bool needReply;
  final String output;
  final String? replyCode;
  final String? replySide;

  bool get isEmpty => !needReply && output.isEmpty;
}
