import 'package:flutter/material.dart';
import '../../../domain/care/appointment.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../application/booking_controller.dart';
import 'mom_appointment_widgets.dart';

Widget _stack(List<Widget> children, {double gap = 14}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) SizedBox(height: gap),
      children[i],
    ],
  ],
);

class BookingNotice extends StatelessWidget {
  const BookingNotice({super.key, required this.title, this.body, this.action});
  final String title;
  final String? body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: MomSettingsCard(
      color: MomCozyColors.amberSoft,
      children: [
        Text(
          title,
          style: MomHomeTokens.text(
            14,
            weight: FontWeight.w700,
            color: MomCozyColors.amber,
          ),
        ),
        if (body != null)
          Text(
            body!,
            style: MomHomeTokens.text(
              13,
              height: 1.55,
              color: MomCozyColors.amber,
            ),
          ),
        ?action,
      ],
    ),
  );
}

class BookingPrecheckDialog extends StatefulWidget {
  const BookingPrecheckDialog({super.key, required this.controller});
  final BookingController controller;
  @override
  State<BookingPrecheckDialog> createState() => _BookingPrecheckDialogState();
}

class _BookingPrecheckDialogState extends State<BookingPrecheckDialog> {
  BookingController get controller => widget.controller;
  bool _waiting = false;

  Widget _group(String title, Widget child) => MomSettingsCard(
    children: [
      Text(title, style: MomHomeTokens.text(16, weight: FontWeight.w700)),
      child,
    ],
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final c = controller;
      return PopScope(
        canPop: !c.busy && !_waiting,
        child: Theme(
          data: momSettingsTheme(Theme.of(context)),
          child: MomSettingsFlowDialog(
            title: '预约前确认',
            closeLabel: '关闭预约前确认',
            maxHeight: 680,
            onClose: c.busy || _waiting ? null : () => Navigator.pop(context),
            child: _stack([
              const Text(
                '当前所在州',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              DropdownButtonFormField<String>(
                initialValue: c.region,
                isExpanded: true,
                itemHeight: null,
                hint: const Text('请选择当前所在州'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                items:
                    {
                          'CA',
                          'NY',
                          'TX',
                          ...?c.data?.providers.expand((p) => p.regions),
                        }
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(switch (value) {
                              'CA' => 'California (CA)',
                              'NY' => 'New York (NY)',
                              'TX' => 'Texas (TX)',
                              _ => value,
                            }),
                          ),
                        )
                        .toList(),
                onChanged: c.canEdit && !_waiting ? c.setRegion : null,
              ),
              if (c.region != null && !c.regionSupported)
                const BookingNotice(title: '当前服务暂未覆盖该州，暂不能继续预约。'),
              _group(
                '服务适用性',
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: MomHomeTokens.rose,
                  title: const Text(
                    '我需要的是哺乳或喂养相关的 IBCLC 咨询',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  value: c.serviceSuitable,
                  onChanged: c.canEdit && !_waiting
                      ? (v) => c.setSuitable(v ?? false)
                      : null,
                ),
              ),
              _group(
                '紧急风险判断',
                _stack([
                  const Text(
                    '如妈妈或宝宝出现呼吸困难、无法唤醒、大量出血等情况，应先寻求紧急医疗帮助。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: MomHomeTokens.secondary,
                    ),
                  ),
                  RadioGroup<EmergencyStatus>(
                    groupValue: c.emergencyStatus,
                    onChanged: c.setEmergency,
                    child: _stack([
                      for (final item in {
                        EmergencyStatus.clear: '目前没有上述紧急情况',
                        EmergencyStatus.needsHelp: '有，或我不确定',
                      }.entries)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: MomHomeTokens.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: RadioListTile<EmergencyStatus>(
                            value: item.key,
                            enabled: c.canEdit && !_waiting,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            activeColor: MomHomeTokens.rose,
                            title: Text(
                              item.value,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ], gap: 9),
                  ),
                ], gap: 9),
              ),
              if (c.emergencyStatus == EmergencyStatus.needsHelp)
                const BookingNotice(
                  title: '请先寻求紧急帮助',
                  body: '请先联系当地急救服务。IBCLC 预约不能替代紧急医疗。',
                ),
              if (c.failure != null || c.message != null)
                BookingNotice(title: c.message ?? '暂时无法确认，请检查网络后重试。'),
              FilledButton(
                onPressed: c.canPrecheck && !_waiting
                    ? () async {
                        setState(() => _waiting = true);
                        try {
                          await c.precheck();
                          if (context.mounted && c.precheckReady) {
                            Navigator.pop(context, true);
                          }
                        } finally {
                          if (mounted) setState(() => _waiting = false);
                        }
                      }
                    : null,
                child: Text(c.busy || _waiting ? '正在确认…' : '继续选择时间'),
              ),
            ]),
          ),
        ),
      );
    },
  );
}

class BookingSelectionDialog extends StatelessWidget {
  const BookingSelectionDialog({
    super.key,
    required this.controller,
    required this.appointment,
    required this.reminder,
    required this.onReminderChanged,
  });
  final BookingController controller;
  final CareAppointment appointment;
  final bool reminder;
  final ValueChanged<bool> onReminderChanged;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final c = controller;
      final current = c.activeAppointment;
      final valid =
          current?.id == appointment.id &&
          current?.status == AppointmentStatus.held;
      final confirmed =
          current?.id == appointment.id &&
          current?.status == AppointmentStatus.confirmed;
      final seconds = appointment.holdExpiresAt
          .difference(c.now)
          .inSeconds
          .clamp(0, 600);
      Future<void> confirm({bool retry = false}) async {
        if (retry) {
          await c.retry();
        } else {
          await c.confirm();
        }
        if (context.mounted &&
            c.activeAppointment?.status == AppointmentStatus.confirmed) {
          Navigator.pop(context, true);
        } else if (context.mounted &&
            c.activeAppointment == null &&
            !c.unresolvedMutation &&
            c.failure == null) {
          Navigator.pop(context, false);
        }
      }

      return PopScope(
        canPop: !c.busy,
        child: Theme(
          data: momSettingsTheme(Theme.of(context)),
          child: MomSettingsFlowDialog(
            title: '确认预约时间',
            closeLabel: '关闭预约时间确认',
            maxHeight: 620,
            onClose: c.busy ? null : () => Navigator.pop(context),
            child: _stack([
              MomAppointmentSummary(
                appointment: appointment,
                title: '本次咨询',
              ),
              if (valid) ...[
                const Text(
                  '所选时间已暂时保留',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: MomHomeTokens.secondary,
                  ),
                ),
                Text(
                  '请在 ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} 内确认',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: MomHomeTokens.secondary,
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: reminder,
                  title: const Text(
                    '提前 15 分钟提醒我',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text(
                    '开启前会检查通知权限。',
                    style: TextStyle(fontSize: 13),
                  ),
                  onChanged: c.canEdit
                      ? (v) => onReminderChanged(v ?? false)
                      : null,
                ),
              ] else if (confirmed)
                const Text(
                  '预约已确认',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: MomHomeTokens.teal),
                )
              else if (!c.unresolvedMutation)
                const BookingNotice(title: '所选时段的保留时间已到，请重新选择'),
              if (c.failure != null || c.message != null)
                BookingNotice(
                  title: c.message ?? '暂时无法确认预约，请检查网络后重试。',
                  action: !c.unresolvedMutation && !c.busy
                      ? TextButton(
                          onPressed: c.loading ? null : c.load,
                          child: const Text('查询最新预约'),
                        )
                      : null,
                ),
              if (confirmed)
                FilledButton(
                  onPressed: c.canEdit
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text('继续填写信息采集表'),
                )
              else if (c.unresolvedMutation)
                FilledButton(
                  onPressed: c.busy ? null : () => confirm(retry: true),
                  child: Text(c.busy ? '正在确认…' : '重试上次提交'),
                )
              else if (valid)
                FilledButton(
                  onPressed: c.canEdit ? confirm : null,
                  child: Text(c.busy ? '正在确认…' : '确认预约'),
                ),
              if (!confirmed)
                TextButton(
                  onPressed: c.canEdit
                      ? () async {
                          if (valid) await c.cancel();
                          if (context.mounted &&
                              c.activeAppointment == null &&
                              !c.unresolvedMutation) {
                            Navigator.pop(context);
                          }
                        }
                      : null,
                  child: const Text('重新选择'),
                ),
            ]),
          ),
        ),
      );
    },
  );
}
