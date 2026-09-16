import 'package:flutter/material.dart';

/// Keep state changes and navigation usable without decorative movement.
abstract final class MomCozyMotion {
  static AnimationStyle? animationStyle(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null;

  static Duration duration(BuildContext context, Duration regular) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : regular;

  static Future<void> scrollTo(
    BuildContext context,
    ScrollController controller,
    double offset, {
    required Duration duration,
    required Curve curve,
  }) async {
    if (!context.mounted || !controller.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      final atEnd = offset >= controller.position.maxScrollExtent;
      controller.jumpTo(
        offset.clamp(
          controller.position.minScrollExtent,
          controller.position.maxScrollExtent,
        ),
      );
      // Lazy lists can revise their estimated extent after the jump lays out
      // the destination. Keep feedback visible without a corrective animation.
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted || !controller.hasClients) return;
      final target = atEnd
          ? controller.position.maxScrollExtent
          : offset.clamp(
              controller.position.minScrollExtent,
              controller.position.maxScrollExtent,
            );
      if (controller.offset != target) controller.jumpTo(target);
    } else {
      await controller.animateTo(offset, duration: duration, curve: curve);
    }
  }
}

final momCozyPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    for (final platform in TargetPlatform.values)
      platform: _MotionAwarePageTransitions(
        const PageTransitionsTheme().builders[platform] ??
            const ZoomPageTransitionsBuilder(),
      ),
  },
);

class _MotionAwarePageTransitions extends PageTransitionsBuilder {
  const _MotionAwarePageTransitions(this.delegate);
  final PageTransitionsBuilder delegate;

  @override
  Duration get transitionDuration => delegate.transitionDuration;
  @override
  Duration get reverseTransitionDuration => delegate.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition {
    final build = delegate.delegatedTransition;
    if (build == null) return null;
    return (context, animation, secondaryAnimation, allowSnapshotting, child) {
      final reduced = MediaQuery.disableAnimationsOf(context);
      return build(
        context,
        reduced ? kAlwaysCompleteAnimation : animation,
        reduced ? kAlwaysDismissedAnimation : secondaryAnimation,
        allowSnapshotting,
        child,
      );
    };
  }

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    // Keep the platform delegate (including the iOS back gesture) while
    // presenting settled visual values when movement is disabled.
    return delegate.buildTransitions(
      route,
      context,
      reduced ? kAlwaysCompleteAnimation : animation,
      reduced ? kAlwaysDismissedAnimation : secondaryAnimation,
      child,
    );
  }
}
