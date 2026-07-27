import 'package:flutter/widgets.dart';
import 'package:app/features/agent_hub/data/ibclc_consult_store.dart';

class IbclcConsultStoreScope extends InheritedNotifier<IbclcConsultStore> {
  const IbclcConsultStoreScope({
    super.key,
    required IbclcConsultStore store,
    required super.child,
  }) : super(notifier: store);

  static IbclcConsultStore? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<IbclcConsultStoreScope>()
        ?.notifier;
  }
}
