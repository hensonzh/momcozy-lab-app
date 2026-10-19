import 'dart:async';

import 'package:flutter/material.dart';

import 'chat_first_demo_icon.dart';

import '../domain/chat_first_cry_audio.dart';
import '../domain/chat_first_cry_task.dart';

enum ChatFirstCryCapturePhase { idle, preparing, recording, preview, failed }

/// In-memory capture state; never serialized into conversation history.
class ChatFirstCryTaskController extends ChangeNotifier {
  ChatFirstCryTaskController(this._createAudio);

  final ChatFirstCryAudioFactory _createAudio;
  ChatFirstCryAudioSession? _audio;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;
  Future<void>? _pendingCapture;
  Timer? _ticker;
  DateTime? _startedAt;
  int _generation = 0;
  bool _closed = false;

  ChatFirstCryCapturePhase phase = ChatFirstCryCapturePhase.idle;
  Duration elapsed = Duration.zero;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  bool playing = false;
  String? error;

  bool get voicePreviewBlocked => phase != ChatFirstCryCapturePhase.idle;

  void _listenTo(ChatFirstCryAudioSession audio) {
    _positionSubscription = audio.positionStream.listen((next) {
      if (_closed || phase != ChatFirstCryCapturePhase.preview) return;
      position = next > duration ? duration : next;
      notifyListeners();
    });
    _playingSubscription = audio.playingStream.listen((next) {
      if (_closed) return;
      playing = next;
      notifyListeners();
    });
  }

  void _track(Future<void> operation) {
    _pendingCapture = operation;
    unawaited(
      operation.then((_) {
        if (identical(_pendingCapture, operation)) _pendingCapture = null;
      }),
    );
  }

  Future<void> start() {
    if (_closed ||
        phase == ChatFirstCryCapturePhase.preparing ||
        phase == ChatFirstCryCapturePhase.recording) {
      return Future.value();
    }
    final generation = ++_generation;
    phase = ChatFirstCryCapturePhase.preparing;
    error = null;
    elapsed = Duration.zero;
    duration = Duration.zero;
    position = Duration.zero;
    playing = false;
    notifyListeners();
    final operation = _startCapture(generation);
    _track(operation);
    return operation;
  }

  Future<void> _startCapture(int generation) async {
    try {
      final audio = _audio ??= _createAudio();
      if (_positionSubscription == null) _listenTo(audio);
      await audio.start();
      if (_closed || generation != _generation) return;
      phase = ChatFirstCryCapturePhase.recording;
      _startedAt = DateTime.now();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_closed || phase != ChatFirstCryCapturePhase.recording) return;
        elapsed = DateTime.now().difference(_startedAt!);
        notifyListeners();
        if (elapsed >= const Duration(seconds: 20)) unawaited(stop());
      });
      notifyListeners();
    } on ChatFirstCryPermissionException {
      _fail(generation, '无法使用麦克风，请开启麦克风权限后重试。');
    } catch (_) {
      _fail(generation, '无法开始录音，请检查麦克风后重试。');
    }
  }

  void _fail(int generation, String message) {
    if (_closed || generation != _generation) return;
    _ticker?.cancel();
    _ticker = null;
    phase = ChatFirstCryCapturePhase.failed;
    error = message;
    notifyListeners();
  }

  Future<void> stop() {
    if (_closed || phase != ChatFirstCryCapturePhase.recording) {
      return Future.value();
    }
    final generation = ++_generation;
    _ticker?.cancel();
    _ticker = null;
    phase = ChatFirstCryCapturePhase.preparing;
    notifyListeners();
    final operation = _stopCapture(generation);
    _track(operation);
    return operation;
  }

  Future<void> _stopCapture(int generation) async {
    try {
      final length = await _audio!.stop();
      if (_closed || generation != _generation) return;
      if (length <= Duration.zero) throw StateError('Empty recording');
      duration = length;
      position = Duration.zero;
      phase = ChatFirstCryCapturePhase.preview;
      notifyListeners();
    } catch (_) {
      _fail(generation, '无法完成录音，请重新录制。');
      try {
        await _audio?.clear();
      } catch (_) {
        // The release path will still dispose the private audio session.
      }
    }
  }

  Future<void> togglePlayback() async {
    if (_closed || phase != ChatFirstCryCapturePhase.preview) return;
    try {
      if (playing) {
        await _audio!.pause();
        if (!_closed) {
          playing = false;
          notifyListeners();
        }
      } else {
        if (position >= duration) await _audio!.seek(Duration.zero);
        await _audio!.play();
      }
    } catch (_) {
      if (!_closed) {
        playing = false;
        error = '无法播放这段录音，请重新录制。';
        notifyListeners();
      }
    }
  }

  Future<void> seek(Duration next) async {
    if (_closed || phase != ChatFirstCryCapturePhase.preview) return;
    final clamped = next < Duration.zero
        ? Duration.zero
        : next > duration
        ? duration
        : next;
    position = clamped;
    notifyListeners();
    try {
      await _audio!.seek(clamped);
    } catch (_) {
      if (!_closed) {
        error = '无法调整试听进度，请重新录制。';
        notifyListeners();
      }
    }
  }

  /// Invalidates in-flight permission/recording operations before cleanup.
  Future<void> release() async {
    if (_closed) return;
    _closed = true;
    _generation++;
    _ticker?.cancel();
    _ticker = null;
    final audio = _audio;
    // Invalidate even a pending permission prompt now. The native adapter
    // checks this cancellation before it ever starts a late microphone grant.
    final immediateClear = audio?.clear();
    try {
      await _pendingCapture;
    } catch (_) {
      // Capture errors are presented as local, retryable UI states.
    }
    try {
      await immediateClear;
    } catch (_) {
      // Still retry cleanup after a native interruption.
    }
    try {
      await audio?.clear();
    } catch (_) {
      // Native disposal below remains mandatory.
    }
    await _positionSubscription?.cancel();
    await _playingSubscription?.cancel();
    try {
      await audio?.dispose();
    } catch (_) {
      // Never revive a discarded recording after a native cleanup failure.
    }
    super.dispose();
  }
}

class ChatFirstCryTaskCard extends StatelessWidget {
  const ChatFirstCryTaskCard({
    super.key,
    required this.status,
    required this.onStart,
    required this.onAbandon,
    this.canStart = true,
    this.controller,
  });

  final ChatFirstCryTaskStatus status;
  final ChatFirstCryTaskController? controller;
  final bool canStart;
  final VoidCallback onStart;
  final VoidCallback onAbandon;

  @override
  Widget build(BuildContext context) => _content(context);

  Widget _content(BuildContext context) {
    final capture = controller;
    final phase = capture?.phase ?? ChatFirstCryCapturePhase.idle;
    return Container(
      key: const ValueKey('chat-first-topic-cry'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3F5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 6, 0),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E3E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: ChatFirstDemoIcon(
                      'sound-wave',
                      size: 17,
                      color: Color(0xFF965873),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    '听听宝宝的哭声',
                    style: TextStyle(
                      color: Color(0xFF382F33),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (status == ChatFirstCryTaskStatus.cancelled)
                  const Text('本次任务已取消。')
                else if (phase == ChatFirstCryCapturePhase.idle) ...[
                  const Text(
                    '录一段约 10–20 秒的哭声',
                    style: TextStyle(
                      color: Color(0xFF3F3539),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '靠近宝宝，避开电视和人声，让哭声更清楚。',
                    style: TextStyle(color: Color(0xFF6D6264), fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('chat-first-cry-start'),
                      onPressed: canStart ? onStart : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF925670),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.mic_none_rounded, size: 18),
                      label: const Text('开始录宝宝哭声'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      '点一下开始，无需按住',
                      style: TextStyle(color: Color(0xFF74696B), fontSize: 12),
                    ),
                  ),
                ] else ...[
                  const Text(
                    '本次录音',
                    style: TextStyle(
                      color: Color(0xFF382F33),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (phase == ChatFirstCryCapturePhase.preparing)
                    const Text('正在准备录音…')
                  else if (phase == ChatFirstCryCapturePhase.recording)
                    Row(
                      children: [
                        Expanded(
                          child: Text('正在录宝宝哭声 ${_clock(capture!.elapsed)}'),
                        ),
                        TextButton(
                          key: const ValueKey('chat-first-cry-stop'),
                          onPressed: () => unawaited(capture.stop()),
                          child: const Text('结束录制'),
                        ),
                      ],
                    )
                  else if (phase == ChatFirstCryCapturePhase.preview) ...[
                    Container(
                      key: const ValueKey('chat-first-cry-player'),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F4F5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            key: ValueKey(
                              capture!.playing
                                  ? 'chat-first-cry-pause'
                                  : 'chat-first-cry-play',
                            ),
                            tooltip: capture.playing ? '暂停录音' : '播放录音',
                            onPressed: () =>
                                unawaited(capture.togglePlayback()),
                            icon: Icon(
                              capture.playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 19,
                            ),
                            color: const Color(0xFF844B62),
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_clock(capture.position)} / ${_clock(capture.duration)}',
                            style: const TextStyle(
                              color: Color(0xFF544C50),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 7,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14,
                                ),
                              ),
                              child: Slider(
                                key: const ValueKey('chat-first-cry-seek'),
                                value: capture.position.inMilliseconds
                                    .toDouble()
                                    .clamp(
                                      0,
                                      capture.duration.inMilliseconds
                                          .toDouble(),
                                    ),
                                max: capture.duration.inMilliseconds.toDouble(),
                                activeColor: const Color(0xFF925670),
                                onChanged: (value) => unawaited(
                                  capture.seek(
                                    Duration(milliseconds: value.round()),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (capture.duration < const Duration(seconds: 10)) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFAF6F2),
                          border: Border(
                            left: BorderSide(
                              color: Color(0xFFD6B5A3),
                              width: 2,
                            ),
                          ),
                        ),
                        child: const Text(
                          '录音不足 10 秒，可能影响分析效果。',
                          style: TextStyle(
                            color: Color(0xFF76665F),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (capture?.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      capture!.error!,
                      key: const ValueKey('chat-first-cry-error'),
                      style: const TextStyle(color: Color(0xFFAA385A)),
                    ),
                  ],
                  if (phase == ChatFirstCryCapturePhase.preview) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const ValueKey('chat-first-cry-re-record'),
                            onPressed: canStart ? onStart : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF844B62),
                              side: const BorderSide(color: Color(0xFFDCBAC9)),
                              minimumSize: const Size.fromHeight(42),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('重新录制'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Semantics(
                            label: '上传并分析暂不可用',
                            button: true,
                            enabled: false,
                            child: FilledButton(
                              onPressed: null,
                              style: FilledButton.styleFrom(
                                disabledBackgroundColor: const Color(
                                  0xFFF2E8ED,
                                ),
                                disabledForegroundColor: const Color(
                                  0xFF876F7A,
                                ),
                                minimumSize: const Size.fromHeight(42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('上传并分析'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        key: const ValueKey('chat-first-cry-abandon'),
                        onPressed: onAbandon,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF70656A),
                          backgroundColor: const Color(0xFFFAF8F8),
                          side: const BorderSide(color: Color(0xFFE9E1E1)),
                          minimumSize: const Size.fromHeight(42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('放弃本次录音'),
                      ),
                    ),
                  ] else if (phase == ChatFirstCryCapturePhase.failed)
                    OutlinedButton(
                      key: const ValueKey('chat-first-cry-retry'),
                      onPressed: canStart ? onStart : null,
                      child: const Text('重新录制'),
                    ),
                  if (phase == ChatFirstCryCapturePhase.failed)
                    TextButton(
                      key: const ValueKey('chat-first-cry-abandon'),
                      onPressed: onAbandon,
                      child: const Text('放弃本次录音'),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _clock(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
}
