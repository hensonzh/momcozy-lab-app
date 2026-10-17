import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum ChatFirstAvatarMode { idle, thinking, replying, happy, concern, listening }

/// A tiny two-dimensional reaction model. There is intentionally no inferred
/// text-to-lip motion: the native App has no timed audio/viseme service.
class ChatFirstAvatarController extends ChangeNotifier {
  ChatFirstAvatarController({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  ChatFirstAvatarMode _phase = ChatFirstAvatarMode.idle;
  ChatFirstAvatarMode _reaction = ChatFirstAvatarMode.idle;
  DateTime _reactionUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastInteraction = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _replyPulse;

  ChatFirstAvatarMode get mode => _phase != ChatFirstAvatarMode.idle
      ? _phase
      : _now().isBefore(_reactionUntil)
      ? _reaction
      : ChatFirstAvatarMode.idle;
  bool get hasSpeechTrack => false;
  DateTime get reactionUntil => _reactionUntil;
  DateTime? get replyPulse => _replyPulse;

  void signal(String event) {
    final time = _now();
    switch (event) {
      case 'request-start':
        _phase = ChatFirstAvatarMode.thinking;
        _reaction = ChatFirstAvatarMode.idle;
        _replyPulse = null;
      case 'reply-chunk':
        _phase = ChatFirstAvatarMode.replying;
        _replyPulse = time;
      case 'reply-done':
        _phase = ChatFirstAvatarMode.idle;
        _reaction = ChatFirstAvatarMode.happy;
        _reactionUntil = time.add(const Duration(milliseconds: 1400));
      case 'request-error':
        _phase = ChatFirstAvatarMode.idle;
        _reaction = ChatFirstAvatarMode.concern;
        _reactionUntil = time.add(const Duration(milliseconds: 1600));
      case 'request-end':
        if (_phase == ChatFirstAvatarMode.thinking ||
            _phase == ChatFirstAvatarMode.replying) {
          _phase = ChatFirstAvatarMode.idle;
        }
      case 'listen-start':
        _phase = ChatFirstAvatarMode.listening;
      case 'listen-end':
        if (_phase == ChatFirstAvatarMode.listening) {
          _phase = ChatFirstAvatarMode.idle;
        }
      case 'interact' || 'greet':
        if (_phase == ChatFirstAvatarMode.idle &&
            time.difference(_lastInteraction) >=
                const Duration(milliseconds: 650)) {
          _lastInteraction = time;
          _reaction = ChatFirstAvatarMode.happy;
          _reactionUntil = time.add(const Duration(milliseconds: 900));
        }
      default:
        return;
    }
    notifyListeners();
  }
}

class ChatFirstAvatarScope
    extends InheritedNotifier<ChatFirstAvatarController> {
  const ChatFirstAvatarScope({
    super.key,
    required this.controller,
    required super.child,
  }) : super(notifier: controller);

  final ChatFirstAvatarController controller;

  static ChatFirstAvatarController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ChatFirstAvatarScope>()
      ?.controller;
}

class ChatFirstAvatarPainter extends CustomPainter {
  const ChatFirstAvatarPainter({
    required this.image,
    required this.controller,
    required this.elapsedMilliseconds,
    required this.now,
  });

  final ui.Image image;
  final ChatFirstAvatarController controller;
  final int elapsedMilliseconds;
  final DateTime now;

  @override
  void paint(Canvas canvas, Size size) {
    final sourceWidth = image.width.toDouble();
    final sourceHeight = image.height.toDouble();
    final scale = math.max(
      size.width / sourceWidth,
      size.height / sourceHeight,
    );
    final left = (size.width - sourceWidth * scale) / 2;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(left, 0);
    canvas.scale(scale);
    canvas.drawImage(
      image,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.low,
    );

    final milliseconds = elapsedMilliseconds.toDouble();
    final mode = controller.mode;
    final blinkTime = milliseconds % 4200;
    final blink = (1 - (blinkTime - 3100).abs() / 130).clamp(0.0, 1.0);
    final remaining = controller.reactionUntil.difference(now).inMilliseconds;
    final nodLength = mode == ChatFirstAvatarMode.happy ? 1400 : 900;
    final nod = mode == ChatFirstAvatarMode.happy
        ? math
              .pow(
                math.sin(math.pi * (remaining / nodLength).clamp(0.0, 1.0)),
                2,
              )
              .toDouble()
        : 0.0;
    final gaze = mode == ChatFirstAvatarMode.thinking
        ? -0.65
        : mode == ChatFirstAvatarMode.listening
        ? 0.45
        : 0.0;
    final headX = math.sin(milliseconds / 1450) * 4 + gaze * 10;
    final pulse = controller.replyPulse;
    final replyAge = pulse == null
        ? 9999
        : now.difference(pulse).inMilliseconds;
    final headY =
        math.sin(milliseconds / 1550) * 3 -
        nod * 14 -
        (mode == ChatFirstAvatarMode.replying
            ? math.exp(-replyAge / 380) * 5
            : 0) +
        (mode == ChatFirstAvatarMode.concern ? 5 : 0);
    final breath = math.sin(milliseconds / 1130) * 2.5;
    final tilePaint = Paint()..filterQuality = FilterQuality.low;
    for (var y = 0; y < 720; y += 60) {
      for (var x = 720; x < 1380; x += 60) {
        Offset warp(double px, double py) {
          final head = math.exp(
            -math.pow((px - 1060) / 280, 2) - math.pow((py - 240) / 265, 2),
          );
          final torso = math.exp(
            -math.pow((px - 1060) / 330, 2) - math.pow((py - 670) / 275, 2),
          );
          return Offset(head * headX, head * headY + torso * breath);
        }

        final l = warp(x.toDouble(), y + 30);
        final r = warp(x + 60, y + 30);
        final t = warp(x + 30, y.toDouble());
        final b = warp(x + 30, y + 60);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 60, 60),
          Rect.fromLTWH(
            x + l.dx,
            y + t.dy,
            60 + r.dx - l.dx + .7,
            60 + b.dy - t.dy + .7,
          ),
          tilePaint,
        );
      }
    }
    if (blink > .02) {
      canvas.save();
      canvas.translate(headX, headY);
      for (final eye in [
        (
          x: 987.0,
          y: 288.0,
          rx: 43.0,
          ry: 32.0,
          top: const Color(0xFFDFAA83),
          bottom: const Color(0xFFB56E4E),
        ),
        (
          x: 1136.0,
          y: 282.0,
          rx: 47.0,
          ry: 33.0,
          top: const Color(0xFFF7C499),
          bottom: const Color(0xFFDC9368),
        ),
      ]) {
        final lid = eye.y - eye.ry + 2 * eye.ry * blink;
        canvas.save();
        canvas.clipPath(
          Path()..addOval(
            Rect.fromCenter(
              center: Offset(eye.x, eye.y),
              width: eye.rx * 2,
              height: eye.ry * 2,
            ),
          ),
        );
        canvas.drawRect(
          Rect.fromLTRB(eye.x - eye.rx, eye.y - eye.ry, eye.x + eye.rx, lid),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(eye.x, eye.y - eye.ry),
              Offset(eye.x, lid),
              [eye.top, eye.bottom],
            ),
        );
        canvas.restore();
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ChatFirstAvatarPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.elapsedMilliseconds != elapsedMilliseconds ||
      oldDelegate.controller != controller;
}
