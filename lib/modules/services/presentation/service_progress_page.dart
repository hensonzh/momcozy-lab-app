import '../../../shared/care/care_labels.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/widgets/momcozy_components.dart';
import '../../../domain/care/care_episode.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/appointment.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../application/care_overview_controller.dart';

class ServiceProgressPage extends StatefulWidget {
  const ServiceProgressPage({
    super.key,
    required this.repository,
    required this.episodeId,
    required this.onBack,
    required this.onBook,
    this.appointmentRepository,
    this.onOpenAppointment,
  });
  final CareRepository repository;
  final String episodeId;
  final VoidCallback onBack;
  final ValueChanged<CareEpisode> onBook;
  final AppointmentRepository? appointmentRepository;
  final ValueChanged<CareAppointment>? onOpenAppointment;
  @override
  State<ServiceProgressPage> createState() => _ServiceProgressPageState();
}

class _ServiceProgressPageState extends State<ServiceProgressPage> {
  late final controller = CareOverviewController(widget.repository);
  CareAppointment? _appointment;
  bool _appointmentLoading = false;
  @override
  void initState() {
    super.initState();
    unawaited(controller.load());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('服务进度'),
      leading: BackButton(onPressed: widget.onBack),
    ),
    body: MomCozyPageBody(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.failure case final failure?) {
            return ProductErrorView(failure: failure, onRetry: controller.load);
          }
          if (controller.overview == null) {
            return const ProductLoadingView();
          }
          final episode = controller.overview!.episodes
              .where((item) => item.id == widget.episodeId)
              .firstOrNull;
          if (episode == null) {
            return const ProductEmptyView(title: '没有找到这个服务');
          }
          final order = controller.overview!.orders
              .where((item) => item.id == episode.orderId)
              .first;
          final package = controller.catalog!.packages
              .where((item) => item.id == episode.packageId)
              .first;
          if (widget.appointmentRepository != null && !_appointmentLoading) {
            _appointmentLoading = true;
            unawaited(_loadAppointment(episode.id));
          }
          return RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              padding: MomCozyInsets.page,
              children: [
                Text(
                  package.name,
                  style: const TextStyle(
                    fontSize: MomCozyTypography.pageTitleSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: MomCozySpacing.statusGap),
                Text(
                  '${episodeStatusLabels[episode.status]} · ${careStageLabels[episode.stage]}',
                  style: const TextStyle(color: MomCozyColors.care),
                ),
                const SizedBox(height: MomCozySpacing.section),
                _Event(
                  date: order.createdAt,
                  title: '服务包已购买',
                  description:
                      '${order.durationDays} 天支持 · ${order.totalSessions} 次 IBCLC 在线咨询',
                ),
                if (episode.startsAt != null)
                  _Event(
                    date: episode.startsAt!,
                    title: '服务已开始',
                    description:
                        '${careStageLabels[episode.stage]} · 剩余 ${episode.remainingSessions} 次咨询',
                  ),
                if (_appointment != null)
                  _Event(
                    date: _appointment!.startsAt,
                    title: switch (_appointment!.status) {
                      AppointmentStatus.held => '咨询时段待确认',
                      AppointmentStatus.confirmed => '已预约咨询',
                      AppointmentStatus.inProgress => '咨询进行中',
                      AppointmentStatus.completed => '咨询已完成',
                      AppointmentStatus.cancelled => '预约已取消',
                      AppointmentStatus.expired => '预约已过期',
                    },
                    description:
                        '${_appointment!.providerName} · ${_appointment!.timezone}',
                  ),
                if (episode.canBook)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: FilledButton(
                      onPressed: () => widget.onBook(episode),
                      child: const Text('预约咨询'),
                    ),
                  ),
                if (_appointment != null &&
                    _appointment!.status != AppointmentStatus.cancelled &&
                    _appointment!.status != AppointmentStatus.expired)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: OutlinedButton(
                      onPressed: () =>
                          widget.onOpenAppointment?.call(_appointment!),
                      child: Text(
                        _appointment!.status == AppointmentStatus.completed
                            ? '查看咨询总结'
                            : '打开预约详情',
                      ),
                    ),
                  ),
                const SizedBox(height: MomCozySpacing.section),
                Text(
                  '已显示当前服务记录\n${episodeStatusLabels[episode.status]} · 仅展示已同步的信息',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: MomCozyColors.mutedForeground,
                    fontSize: MomCozyTypography.captionSize,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  Future<void> _loadAppointment(String episodeId) async {
    try {
      final context = await widget.appointmentRepository!.context(episodeId);
      if (!mounted) return;
      final active =
          context.appointments
              .where((item) => item.status != AppointmentStatus.expired)
              .toList()
            ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
      setState(() => _appointment = active.firstOrNull);
    } catch (_) {
      // The rest of the durable service timeline remains available.
    }
  }
}

class _Event extends StatelessWidget {
  const _Event({
    required this.date,
    required this.title,
    required this.description,
  });
  final DateTime date;
  final String title, description;
  @override
  Widget build(BuildContext context) {
    final time = date.toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: MediaQuery.textScalerOf(context).scale(58),
            child: Text(
              '${time.month}/${time.day}\n${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: MomCozyTypography.labelSize,
                color: MomCozyColors.mutedForeground,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 5, right: 12),
            child: Icon(Icons.circle, size: 8, color: MomCozyColors.primary),
          ),
          Expanded(
            child: MomCozySurface(
              padding: MomCozyInsets.compactCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: MomCozySpacing.compact),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: MomCozyTypography.secondarySize,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
