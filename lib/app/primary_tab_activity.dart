import 'package:flutter/widgets.dart';

/// Carries tab selection through the nested navigators without discarding pages.
class PrimaryTabActivity extends InheritedWidget {
  const PrimaryTabActivity({
    super.key,
    required this.selectedIndex,
    required this.activation,
    required super.child,
  });

  final int selectedIndex;
  final int activation;

  static PrimaryTabActivity? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrimaryTabActivity>();

  @override
  bool updateShouldNotify(PrimaryTabActivity oldWidget) =>
      selectedIndex != oldWidget.selectedIndex ||
      activation != oldWidget.activation;
}

/// Skip a duplicate initial request and avoid refetching on rapid tab switches.
class PrimaryTabRefresh {
  PrimaryTabRefresh(this.index);

  final int index;
  int? _seenActivation;
  DateTime? _lastRefresh;

  bool shouldRefresh(BuildContext context, DateTime now) {
    final tab = PrimaryTabActivity.maybeOf(context);
    if (tab == null || tab.selectedIndex != index) return false;
    if (_seenActivation == null) {
      _seenActivation = tab.activation;
      _lastRefresh = now;
      return false;
    }
    if (_seenActivation == tab.activation) return false;
    _seenActivation = tab.activation;
    if (now.difference(_lastRefresh!) < const Duration(seconds: 30)) {
      return false;
    }
    _lastRefresh = now;
    return true;
  }
}
