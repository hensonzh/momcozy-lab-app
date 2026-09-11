import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../domain/ibclc/workbench_reminder.dart';
import '../../../../shared/design_system/momcozy_design_system.dart';
import '../../../../shared/widgets/product_feedback.dart';
import '../../../../shared/zoned_time.dart';
import '../../shared/workbench_widgets.dart';
import '../application/reminders_controller.dart';
import '../application/reminder_presentation.dart';

class WorkbenchRemindersPage extends StatefulWidget {
  const WorkbenchRemindersPage({
    super.key,
    required this.createController,
    required this.timezone,
    required this.onOpen,
  });
  final WorkbenchRemindersController Function() createController;
  final String timezone;
  final Future<void> Function(String route) onOpen;
  @override
  State<WorkbenchRemindersPage> createState() => _WorkbenchRemindersPageState();
}

class _WorkbenchRemindersPageState extends State<WorkbenchRemindersPage>
    with WidgetsBindingObserver {
  late final controller = widget.createController();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(controller.load());
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!controller.busy) unawaited(controller.load());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !controller.busy) {
      unawaited(controller.load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> _open(WorkbenchReminder item) async {
    if (!await controller.markRead(item) || !mounted) return;
    await widget.onOpen(WorkbenchReminderPresentation(item).route);
    if (mounted) await controller.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final data = controller.data;
      final appointments =
          data?.items
              .where(
                (item) => WorkbenchReminderPresentation(item).isAppointment,
              )
              .toList() ??
          <WorkbenchReminder>[];
      final cases =
          data?.items
              .where(
                (item) => !WorkbenchReminderPresentation(item).isAppointment,
              )
              .toList() ??
          <WorkbenchReminder>[];
      return WorkbenchPageBody(
        children: [
          WorkbenchHeading(
            title: '工作提醒',
            subtitle: '只显示需要你处理的预约、病例和服务事项。',
            actions: [
              if (data != null)
                WorkbenchBadge(
                  '${data.unreadCount} 条未读',
                  color: MomCozyColors.primary,
                  background: MomCozyColors.roseSoft,
                ),
              IconButton(
                tooltip: '刷新工作提醒',
                onPressed: controller.busy ? null : controller.load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (controller.loading)
            const LinearProgressIndicator(semanticsLabel: '正在读取工作提醒'),
          if (controller.failure != null)
            ProductErrorView(
              failure: controller.failure!,
              onRetry: controller.load,
            ),
          if (data != null && data.items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                child: ProductEmptyView(
                  title: '暂无工作提醒',
                  description: '当前没有需要处理的预约变更、病例复核或服务跟进。',
                ),
              ),
            ),
          if (appointments.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                '预约提醒',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            for (final item in appointments) _card(item),
          ],
          if (cases.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 14),
              child: Text(
                '病例与服务',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            for (final item in cases) _card(item),
          ],
          if (data != null && data.total > data.limit)
            WorkbenchPagination(
              total: data.total,
              offset: data.offset,
              limit: data.limit,
              onPage: controller.page,
              loading: controller.busy,
            ),
        ],
      );
    },
  );

  Widget _card(WorkbenchReminder item) {
    final presentation = WorkbenchReminderPresentation(item);
    final unread = item.readAt == null,
        reading = controller.readingId == item.event.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: unread && !controller.busy
              ? () => unawaited(controller.markRead(item))
              : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: presentation.isAppointment
                        ? MomCozyColors.roseSoft
                        : MomCozyColors.violetSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    presentation.isAppointment
                        ? Icons.calendar_today_outlined
                        : Icons.description_outlined,
                    size: 22,
                    color: presentation.isAppointment
                        ? MomCozyColors.primary
                        : MomCozyColors.violet,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            presentation.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          WorkbenchBadge(
                            reading
                                ? '正在保存'
                                : unread
                                ? '未读'
                                : '已读',
                            color: unread
                                ? MomCozyColors.primary
                                : MomCozyColors.mutedForeground,
                            background: unread
                                ? MomCozyColors.roseSoft
                                : MomCozyColors.muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${item.displayName} · ${item.packageName}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.startsAt != null && item.timezone != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            '${appointmentDay(item.startsAt!, item.timezone!)} ${zonedClock(item.startsAt!, item.timezone!)} · ${item.timezone}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: MomCozyColors.mutedForeground,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        presentation.body,
                        style: const TextStyle(
                          fontSize: 13,
                          color: MomCozyColors.mutedForeground,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${dateInTimezone(item.event.occurredAt, widget.timezone)} ${zonedClock(item.event.occurredAt, widget.timezone)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: MomCozyColors.mutedForeground,
                            ),
                          ),
                          TextButton(
                            onPressed: controller.busy
                                ? null
                                : () => _open(item),
                            child: Text(presentation.actionLabel),
                          ),
                          if (unread)
                            TextButton(
                              onPressed: controller.busy
                                  ? null
                                  : () => controller.markRead(item),
                              child: const Text('标记已读'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
