import 'package:flutter/material.dart';
import '../../../shared/design_system/momcozy_motion.dart';

abstract final class BabyMotion {
  static const press = Duration(milliseconds: 100);
  static const feedback = Duration(milliseconds: 160);
  static const content = Duration(milliseconds: 180);
  static const resize = Duration(milliseconds: 240);
  static Duration duration(BuildContext context, Duration value) =>
      MomCozyMotion.duration(context, value);
  static AnimationStyle sheet(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(
          duration: Duration(milliseconds: 280),
          reverseDuration: Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
}

/// Only visual feedback: the original control owns taps, focus and semantics.
class BabyPressFeedback extends StatefulWidget {
  const BabyPressFeedback({super.key, required this.child});
  final Widget child;
  @override
  State<BabyPressFeedback> createState() => _BabyPressFeedbackState();
}

class _BabyPressFeedbackState extends State<BabyPressFeedback> {
  int? _pointer;
  Offset? _origin;
  bool get _enabled => switch (widget.child) {
    ButtonStyleButton button => button.enabled,
    IconButton button => button.onPressed != null,
    _ => true,
  };
  void _release() {
    if (_pointer != null) {
      setState(() {
        _pointer = null;
        _origin = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (event) {
        if (_enabled && !reduced && _pointer == null) {
          setState(() {
            _pointer = event.pointer;
            _origin = event.position;
          });
        }
      },
      onPointerMove: (event) {
        if (_pointer == event.pointer &&
            (event.position - _origin!).distance > 12) {
          _release();
        }
      },
      onPointerUp: (event) {
        if (_pointer == event.pointer) _release();
      },
      onPointerCancel: (event) {
        if (_pointer == event.pointer) _release();
      },
      child: AnimatedScale(
        scale: _pointer != null && _enabled && !reduced ? .98 : 1,
        duration: BabyMotion.duration(context, BabyMotion.press),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Keep just the live form mounted: an outgoing form must never receive edits.
/// The controller owns drafts; changing [selection] does not replace its state.
class BabyContentTransition extends StatefulWidget {
  const BabyContentTransition({
    super.key,
    required this.selection,
    required this.child,
  });
  final Object selection;
  final Widget child;
  @override
  State<BabyContentTransition> createState() => _BabyContentTransitionState();
}

class _BabyContentTransitionState extends State<BabyContentTransition>
    with SingleTickerProviderStateMixin {
  final _contentKey = GlobalKey();
  late final _fade = AnimationController(
    vsync: this,
    value: 1,
    duration: BabyMotion.content,
  );
  late final _opacity = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeOutCubic,
  );
  @override
  void didUpdateWidget(BabyContentTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _fade.value = 1;
      } else {
        _fade.forward(from: 0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _fade.value = 1;
  }

  @override
  void dispose() {
    _opacity.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = FadeTransition(
      key: _contentKey,
      opacity: _opacity,
      child: widget.child,
    );
    // Skip resize animation entirely for reduced motion. A zero-duration
    // RenderAnimatedSize can invalidate its own layout as constraints change.
    if (MediaQuery.disableAnimationsOf(context)) return content;
    return AnimatedSize(
      duration: BabyMotion.resize,
      alignment: Alignment.topCenter,
      curve: Curves.easeOutCubic,
      child: content,
    );
  }
}

class BabyAnimatedLabel extends StatelessWidget {
  const BabyAnimatedLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: BabyMotion.duration(context, BabyMotion.feedback),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.center,
      children: [
        for (final child in previous) ExcludeSemantics(child: child),
        ?current,
      ],
    ),
    child: Text(text, key: ValueKey(text)),
  );
}
