import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Smooths presentation only; the caller keeps the complete server text.
class AgentTextReveal extends StatefulWidget {
  const AgentTextReveal({
    super.key,
    required this.text,
    required this.streaming,
    required this.completed,
    required this.builder,
    this.replyId,
    this.onReveal,
  });

  final String text;
  final bool streaming;
  final bool completed;
  final String? replyId;
  final Widget Function(BuildContext context, String text) builder;
  final VoidCallback? onReveal;

  @override
  State<AgentTextReveal> createState() => _AgentTextRevealState();
}

class _AgentTextRevealState extends State<AgentTextReveal>
    with SingleTickerProviderStateMixin {
  static const _step = Duration(milliseconds: 24);
  late final Ticker _ticker;
  late List<String> _characters;
  late int _visible;
  Duration _lastStep = Duration.zero;
  bool _reduceMotion = false;
  int _completionStep = 1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    // Restored replies and history must never replay their typing animation.
    _characters = widget.text.characters.toList();
    _visible = _characters.length;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    if (_reduceMotion) _showAll();
  }

  @override
  void didUpdateWidget(AgentTextReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newReply =
        oldWidget.replyId != null && oldWidget.replyId != widget.replyId;
    final append = widget.text.startsWith(oldWidget.text);
    _characters = widget.text.characters.toList();
    if (_reduceMotion ||
        newReply ||
        !append ||
        (!widget.streaming && !widget.completed)) {
      // Corrections, withdrawals, cancellations and failures are authoritative.
      _showAll();
      return;
    }
    if (!widget.streaming && !oldWidget.streaming && !_ticker.isActive) {
      _showAll();
      return;
    }
    if (_visible >= _characters.length) return;
    if (widget.completed && !oldWidget.completed) {
      // Drain the final tail in at most eight ticks (192 ms).
      _completionStep = ((_characters.length - _visible) / 8).ceil();
    }
    if (_visible == 0) _visible = 1;
    if (!_ticker.isActive && _visible < _characters.length) {
      _lastStep = Duration.zero;
      _ticker.start();
    }
  }

  void _showAll() {
    _ticker.stop();
    _visible = _characters.length;
  }

  void _tick(Duration elapsed) {
    final steps = (elapsed - _lastStep).inMicroseconds ~/ _step.inMicroseconds;
    if (steps == 0) return;
    _lastStep += _step * steps;
    final pending = _characters.length - _visible;
    final batch = widget.completed
        ? _completionStep
        : math.max(1, (pending / 24).ceil());
    setState(() {
      _visible = math.min(_characters.length, _visible + batch * steps);
    });
    widget.onReveal?.call();
    if (_visible == _characters.length) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _characters.take(_visible).join());
}
