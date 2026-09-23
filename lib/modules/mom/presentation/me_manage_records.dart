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
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !busy,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) back();
    },
    child: MePage(
      title: '管理记录',
      onBack: back,
      scroll: false,
      footer: MeButton('保存', busy: busy, onPressed: dirty ? save : null),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '首页排列顺序',
                  style: MeDesign.text(16, weight: FontWeight.w700, line: 24),
                ),
                const SizedBox(height: 9),
                Text(
                  '长按左侧图标拖动排序',
                  style: MeDesign.text(14, color: MeDesign.muted, line: 22),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              buildDefaultDragHandles: false,
              itemCount: order.length,
              onReorderItem: (from, to) {
                if (busy) return;
                setState(() {
                  order.insert(to, order.removeAt(from));
                });
              },
              itemBuilder: (context, index) {
                final kind = order[index];
                return Padding(
                  key: ValueKey(kind),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    height: 58,
                    decoration: MeDesign.card(radius: 16),
                    child: Row(
                      children: [
                        ReorderableDelayedDragStartListener(
                          index: index,
                          enabled: !busy,
                          child: const SizedBox(
                            width: 46,
                            height: 58,
                            child: Icon(
                              Icons.drag_handle,
                              size: 20,
                              color: MeDesign.muted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
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
                                '显示在首页',
                                style: MeDesign.text(
                                  10,
                                  color: MeDesign.muted,
                                  line: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: busy || index == 0
                              ? null
                              : () => setState(
                                  () => order.insert(0, order.removeAt(index)),
                                ),
                          child: Text(
                            index == 0 ? '首位' : '移到最前',
                            style: MeDesign.text(11, color: MeDesign.rose),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (dirty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '已调整，保存后应用到首页。',
                style: MeDesign.text(12, color: MeDesign.muted),
              ),
            ),
          if (failed)
            const Padding(padding: EdgeInsets.all(20), child: MeError()),
        ],
      ),
    ),
  );
}
