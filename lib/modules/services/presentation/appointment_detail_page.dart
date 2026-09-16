import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/care/appointment.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../features/notifications/presentation/appointment_reminder_tile.dart';
import 'mom_appointment_widgets.dart';
import 'appointment_cancel_dialog.dart';
import 'service_flow_theme.dart';

class AppointmentDetailPage extends StatefulWidget {
  const AppointmentDetailPage({
    super.key,
    required this.repository,
    required this.appointmentId,
  });
  final AppointmentRepository repository;
  final String appointmentId;
  @override
  State<AppointmentDetailPage> createState() => _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends State<AppointmentDetailPage>
    with WidgetsBindingObserver {
  CareAppointment? _appointment;
  bool _loading = true, _failed = false, _cancelOpen = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(AppointmentDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appointmentId != widget.appointmentId ||
        oldWidget.repository != widget.repository) {
      unawaited(_load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_cancelOpen) unawaited(_load());
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() => _loading = true);
    try {
      final value = await widget.repository.read(widget.appointmentId);
      if (mounted && request == _request) {
        setState(() {
          _appointment = value;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _failed = true;
          _appointment = null;
        });
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) await _load();
  }

  Future<void> _cancel(CareAppointment value) async {
    if (_cancelOpen) return;
    _cancelOpen = true;
    final cancelled = await showAppointmentCancellation(
      context,
      repository: widget.repository,
      appointment: value,
    );
    _cancelOpen = false;
    if (!mounted) return;
    if (cancelled != null) {
      context.go('/me');
    } else {
      await _load();
    }
  }

  void _back() =>
      context.canPop() ? context.pop() : context.go('/notifications');

  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.3
            ? 96
            : 56,
        leadingWidth: MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 88 : 64,
        centerTitle: false,
        title: const Text('预约详情'),
        leading: TextButton(onPressed: _back, child: const Text('返回')),
      ),
      body: ClipRect(child: MomCozyPageBody(child: _body())),
    ),
  );
  Widget _body() {
    final value = _appointment;
    if (_loading) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: MomSettingsCard(
          children: [
            Text(
              '正在加载预约…',
              style: MomHomeTokens.text(16, weight: FontWeight.w700),
            ),
            const LinearProgressIndicator(),
          ],
        ),
      );
    }
    if (_failed || value == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: MomSettingsCard(
          children: [
            Text(
              '暂时无法打开预约',
              style: MomHomeTokens.text(16, weight: FontWeight.w700),
            ),
            Text(
              '请稍后重试，核对最新预约状态。',
              style: MomHomeTokens.text(13, color: MomHomeTokens.secondary),
            ),
            TextButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    final active = {
      AppointmentStatus.confirmed,
      AppointmentStatus.inProgress,
    }.contains(value.status);
    final status = switch (value.status) {
      AppointmentStatus.confirmed => '已确认',
      AppointmentStatus.inProgress => '咨询中',
      AppointmentStatus.completed => '已完成',
      AppointmentStatus.cancelled => '已取消',
      AppointmentStatus.expired => '已过期',
      AppointmentStatus.held => '待确认',
    };
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          MomAppointmentSummary(
            appointment: value,
            title: '$status · IBCLC 咨询',
            action: value.status == AppointmentStatus.confirmed
                ? OutlinedButton(
                    onPressed: () => _cancel(value),
                    style: ServiceFlowTheme.cancellationStyle(
                      context,
                      tinted: true,
                    ),
                    child: const Text('取消预约'),
                  )
                : null,
          ),
          if (active) ...[
            const SizedBox(height: 14),
            MomSettingsCard(
              children: [
                Text(
                  '下一步',
                  style: MomHomeTokens.text(18, weight: FontWeight.w700),
                ),
                FilledButton(
                  onPressed: () =>
                      _open('/services/appointments/${value.id}/intake'),
                  child: Text(value.intakeVersion > 0 ? '查看信息采集表' : '填写信息采集表'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      _open('/services/appointments/${value.id}/room'),
                  child: Text(
                    value.status == AppointmentStatus.inProgress
                        ? '返回咨询室'
                        : '咨询前准备',
                  ),
                ),
              ],
            ),
          ],
          if (value.status == AppointmentStatus.completed) ...[
            const SizedBox(height: 14),
            MomSettingsCard(
              children: [
                Text(
                  '咨询总结',
                  style: MomHomeTokens.text(18, weight: FontWeight.w700),
                ),
                FilledButton(
                  onPressed: () =>
                      _open('/services/appointments/${value.id}/summary'),
                  child: const Text('查看咨询总结'),
                ),
              ],
            ),
          ],
          if (value.status == AppointmentStatus.held) ...[
            const SizedBox(height: 14),
            MomSettingsCard(
              children: [
                Text(
                  '完成预约确认',
                  style: MomHomeTokens.text(18, weight: FontWeight.w700),
                ),
                FilledButton(
                  onPressed: () =>
                      _open('/services/episodes/${value.episodeId}/booking'),
                  child: const Text('继续确认预约'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          MomSettingsCard(
            children: [
              TextButton(
                onPressed: () => _open('/services/episodes/${value.episodeId}'),
                child: const Text('查看服务详情'),
              ),
            ],
          ),
          if (value.status == AppointmentStatus.confirmed) ...[
            const SizedBox(height: 14),
            MomSettingsCard(
              children: [
                AppointmentReminderTile(
                  key: ValueKey('${value.id}-${value.version}'),
                  appointmentId: value.id,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
