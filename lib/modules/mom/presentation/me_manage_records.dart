import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../application/me_controller.dart';
import '../domain/me_experience.dart';
import 'me_design.dart';

class MeManageRecords extends StatefulWidget {
  const MeManageRecords({super.key, required this.controller});
  final MeController controller;
  @override
  State<MeManageRecords> createState() => _MeManageRecordsState();
}

class _MeManageRecordsState extends State<MeManageRecords> {
  final scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  late final baseline = List<MeMetric>.of(
    widget.controller.state!.visibleMetrics,
  );
  late final order = List<MeMetric>.of(baseline);
  bool busy = false, failed = false;
  bool get dirty => !listEquals(order, baseline);
  Future<void> back() async {
    if (!busy && (!dirty || await meDiscard(context)) && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> save() async {
    if (busy || !dirty) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await widget.controller.saveOrder(order);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          failed = true;
        });
        if (stacked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && scrollController.hasClients) {
              scrollController.animateTo(
                scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    }
  }

  bool get stacked => MediaQuery.textScalerOf(context).scale(14) > 21;
  Widget get updatedMessage => Padding(
    padding: const EdgeInsets.all(20),
    child: Text(
      'Order updated. Save to apply it to your home page.',
      style: MeDesign.text(12, color: MeDesign.muted),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !busy,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) back();
    },
    child: MePage(
      title: 'Manage records',
      onBack: back,
      scroll: false,
      footer: MeButton('Save', busy: busy, onPressed: dirty ? save : null),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order on home',
                  style: MeDesign.text(16, weight: FontWeight.w700, line: 24),
                ),
                const SizedBox(height: 9),
                Text(
                  'Drag the handle to rearrange',
                  style: MeDesign.text(14, color: MeDesign.muted, line: 22),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              scrollController: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              buildDefaultDragHandles: false,
              itemCount: order.length,
              footer: stacked && (dirty || failed)
                  ? Column(
                      children: [
                        if (dirty) updatedMessage,
                        if (failed)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: MeError(),
                          ),
                      ],
                    )
                  : null,
              onReorderItem: (from, to) {
                if (busy) return;
                setState(() {
                  order.insert(to, order.removeAt(from));
                });
              },
              itemBuilder: (context, index) {
                final kind = order[index];
                final moveToTop = TextButton(
                  onPressed: busy || index == 0
                      ? null
                      : () => setState(
                          () => order.insert(0, order.removeAt(index)),
                        ),
                  child: Text(
                    index == 0 ? 'First' : 'Move to top',
                    style: MeDesign.text(11, color: MeDesign.rose),
                  ),
                );
                return Padding(
                  key: ValueKey(kind),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 58),
                    padding: EdgeInsets.symmetric(vertical: stacked ? 10 : 0),
                    decoration: MeDesign.card(radius: 16),
                    child: Row(
                      crossAxisAlignment: stacked
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          enabled: !busy,
                          child: const ColoredBox(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: 46,
                              height: 58,
                              child: Icon(
                                Icons.drag_handle,
                                size: 20,
                                color: MeDesign.muted,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kind.label,
                                style: MeDesign.text(
                                  14,
                                  weight: FontWeight.w500,
                                  line: 21,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Show on home',
                                style: MeDesign.text(
                                  10,
                                  color: MeDesign.muted,
                                  line: 15,
                                ),
                              ),
                              if (stacked)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: moveToTop,
                                ),
                            ],
                          ),
                        ),
                        if (!stacked) moveToTop,
                        if (!stacked) const SizedBox(width: 12),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (dirty && !stacked) updatedMessage,
          if (failed && !stacked)
            const Padding(padding: EdgeInsets.all(20), child: MeError()),
        ],
      ),
    ),
  );
}
