import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/core/preferences/volume_unit_preference.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/status/domain/baby_status_projection.dart';
import 'package:momcozy_flutter_app/features/status/presentation/status_dashboard_controller.dart';

typedef BabyGrowthSave =
    Future<bool> Function({
      required double? weightKg,
      required double? heightCm,
      required double? headCm,
    });

class BabyFeedingCard extends StatelessWidget {
  const BabyFeedingCard({
    super.key,
    required this.records,
    required this.volumeUnit,
    required this.onInfoTap,
  });

  final ValueListenable<StatusResource<List<FeedingRecord>>> records;
  final ValueListenable<MomCozyVolumeUnit> volumeUnit;
  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([records, volumeUnit]),
      builder: (context, _) {
        final resource = records.value;
        final projection = BabyFeedingProjection.fromRecords(
          resource.data ?? const <FeedingRecord>[],
        );
        return _StatusCardShell(
          key: const ValueKey('status-baby-feeding-card'),
          title: '奶量摄入',
          icon: Icons.restaurant_outlined,
          accent: const Color(0xff4f84a6),
          background: const Color(0xfff4fbff),
          child: Row(
            children: [
              Expanded(
                child: _Metric(
                  label: '今日摄入',
                  value: _feedingVolumeLabel(
                    resource,
                    projection,
                    volumeUnit.value,
                  ),
                  helpKey: const ValueKey('status-baby-feed-info-button'),
                  onHelpTap: onInfoTap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  label: '今日喂奶',
                  value: _feedingCountLabel(resource, projection),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class BabyGrowthSummaryCard extends StatefulWidget {
  const BabyGrowthSummaryCard({
    super.key,
    required this.records,
    required this.mutation,
    required this.onSave,
    required this.onMilestoneTap,
  });

  final ValueListenable<StatusResource<List<GrowthRecord>>> records;
  final ValueListenable<StatusMutationState> mutation;
  final BabyGrowthSave onSave;
  final VoidCallback onMilestoneTap;

  @override
  State<BabyGrowthSummaryCard> createState() => _BabyGrowthSummaryCardState();
}

class _BabyGrowthSummaryCardState extends State<BabyGrowthSummaryCard> {
  Future<void> _openEditor() {
    final projection = BabyGrowthProjection(
      records: widget.records.value.data ?? const <GrowthRecord>[],
      birthDate: null,
    );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => _GrowthEditorSheet(
        latest: projection.latest,
        mutation: widget.mutation,
        onSave: widget.onSave,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StatusResource<List<GrowthRecord>>>(
      valueListenable: widget.records,
      builder: (context, resource, _) {
        final projection = BabyGrowthProjection(
          records: resource.data ?? const <GrowthRecord>[],
          birthDate: null,
        );
        final latest = projection.latest;
        return _StatusCardShell(
          key: const ValueKey('status-baby-growth-card'),
          title: '成长发育',
          icon: Icons.straighten_outlined,
          accent: const Color(0xff388b72),
          background: const Color(0xfff2fffb),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: '体重',
                      value: _growthLabel(
                        resource,
                        latest?.weightKg,
                        'kg',
                        decimals: 2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: '身高',
                      value: _growthLabel(resource, latest?.heightCm, 'cm'),
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: '头围',
                      value: _growthLabel(resource, latest?.headCm, 'cm'),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 5,
                children: [
                  _CardAction(
                    key: const ValueKey('status-growth-record-action'),
                    label: '修改指标',
                    accent: const Color(0xff388b72),
                    onTap: _openEditor,
                  ),
                  _CardAction(
                    key: const ValueKey('status-growth-milestone-action'),
                    label: '成长milestone',
                    accent: const Color(0xff388b72),
                    onTap: widget.onMilestoneTap,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GrowthEditorSheet extends StatefulWidget {
  const _GrowthEditorSheet({
    required this.latest,
    required this.mutation,
    required this.onSave,
  });

  final GrowthRecord? latest;
  final ValueListenable<StatusMutationState> mutation;
  final BabyGrowthSave onSave;

  @override
  State<_GrowthEditorSheet> createState() => _GrowthEditorSheetState();
}

class _GrowthEditorSheetState extends State<_GrowthEditorSheet> {
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _headController;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: _inputValue(widget.latest?.weightKg, 2),
    );
    _heightController = TextEditingController(
      text: _inputValue(widget.latest?.heightCm, 1),
    );
    _headController = TextEditingController(
      text: _inputValue(widget.latest?.headCm, 1),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _headController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final weight = double.tryParse(_weightController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final head = double.tryParse(_headController.text.trim());
    if (!_positive(weight) || !_positive(height) || !_positive(head)) {
      setState(() => _error = '请填写完整的体重、身高与头围');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    var saved = false;
    try {
      saved = await widget.onSave(
        weightKg: weight,
        heightCm: height,
        headCm: head,
      );
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = widget.mutation.value.message ?? '保存失败，请稍后重试';
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_saving,
      child: Container(
        key: const ValueKey('status-growth-editor-dialog'),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + keyboardInset),
        decoration: const BoxDecoration(
          color: MomCozyColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MomCozyColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '修改生长指标',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭编辑',
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _GrowthInput(
              fieldKey: const ValueKey('status-growth-weight-input'),
              label: '体重 (kg)',
              controller: _weightController,
              decimalPlaces: 2,
            ),
            const SizedBox(height: 12),
            _GrowthInput(
              fieldKey: const ValueKey('status-growth-height-input'),
              label: '身高 (cm)',
              controller: _heightController,
              decimalPlaces: 1,
            ),
            const SizedBox(height: 12),
            _GrowthInput(
              fieldKey: const ValueKey('status-growth-head-input'),
              label: '头围 (cm)',
              controller: _headController,
              decimalPlaces: 1,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  key: const ValueKey('status-growth-save-error'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                key: const ValueKey('status-growth-save-button'),
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: MomCozyColors.foreground,
                  foregroundColor: MomCozyColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _saving ? '保存中…' : '保存修改',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GrowthInput extends StatelessWidget {
  const _GrowthInput({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.decimalPlaces,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final int decimalPlaces;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MomCozyColors.secondary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: MomCozyColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            key: fieldKey,
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(
              decimal: decimalPlaces > 0,
            ),
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              filled: true,
              fillColor: MomCozyColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: MomCozyColors.border.withValues(alpha: 0.6),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: MomCozyColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCardShell extends StatelessWidget {
  const _StatusCardShell({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.background,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.helpKey,
    this.onHelpTap,
  });

  final String label;
  final String value;
  final Key? helpKey;
  final VoidCallback? onHelpTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: MomCozyColors.mutedForeground,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onHelpTap != null) ...[
              const SizedBox(width: 4),
              InkWell(
                key: helpKey,
                onTap: onHelpTap,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 15,
                  height: 15,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MomCozyColors.mutedForeground.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: const Text(
                    '?',
                    style: TextStyle(fontSize: 9, height: 1),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: const Color(0xff35212c),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    super.key,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

String _feedingVolumeLabel(
  StatusResource<List<FeedingRecord>> resource,
  BabyFeedingProjection projection,
  MomCozyVolumeUnit unit,
) {
  if (resource.isLoading || resource.phase == StatusResourcePhase.initial) {
    return '加载中';
  }
  final total = projection.totalVolumeMl;
  if (total == null) return '待记录';
  return '${unit.formatMilliliters(total.toDouble())}${unit.storageValue}';
}

String _feedingCountLabel(
  StatusResource<List<FeedingRecord>> resource,
  BabyFeedingProjection projection,
) {
  if (resource.isLoading || resource.phase == StatusResourcePhase.initial) {
    return '加载中';
  }
  if (resource.hasError && resource.data == null) return '待同步';
  return '${projection.feedingCount}次';
}

String _growthLabel(
  StatusResource<List<GrowthRecord>> resource,
  double? value,
  String unit, {
  int decimals = 1,
}) {
  if (resource.isLoading || resource.phase == StatusResourcePhase.initial) {
    return '加载中';
  }
  if (value == null || !value.isFinite || value <= 0) return '待记录';
  return '${_displayNumber(value, decimals)}$unit';
}

String _displayNumber(double value, int decimals) {
  final fixed = value.toStringAsFixed(decimals);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _inputValue(double? value, int decimals) {
  if (value == null || !value.isFinite || value <= 0) return '';
  return _displayNumber(value, decimals);
}

bool _positive(double? value) {
  return value != null && value.isFinite && value > 0;
}
