import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/domain/pregnancy_diary_entry.dart';
import 'package:momcozy_flutter_app/features/status/domain/pregnancy_diary_projection.dart';
import 'package:momcozy_flutter_app/features/status/presentation/status_dashboard_controller.dart';

const _moodOptions = ['平稳', '开心', '焦虑', '低落', '容易烦躁'];
const _energyOptions = ['不错', '一般', '很累'];
const _sleepOptions = ['睡得好', '易醒', '失眠', '白天补觉'];
const _fetalMovementOptions = ['胎动正常', '比平时少', '比平时频繁', '还没明显感觉'];
const _symptomOptions = ['腰酸', '水肿', '胃口变化', '宫缩感', '胎动变化', '头晕', '腹痛', '出血'];

typedef PregnancyDiarySave =
    Future<bool> Function(DateTime entryDate, PregnancyDiaryDraft draft);

class PregnancyDiaryDashboard extends StatefulWidget {
  const PregnancyDiaryDashboard({
    super.key,
    required this.entries,
    required this.mutation,
    required this.now,
    required this.onSave,
    required this.onAgentPrompt,
  });

  final ValueListenable<StatusResource<List<PregnancyDiaryEntry>>> entries;
  final ValueListenable<StatusMutationState> mutation;
  final DateTime Function() now;
  final PregnancyDiarySave onSave;
  final ValueChanged<String> onAgentPrompt;

  @override
  State<PregnancyDiaryDashboard> createState() =>
      _PregnancyDiaryDashboardState();
}

class _PregnancyDiaryDashboardState extends State<PregnancyDiaryDashboard> {
  Future<void> _openEditor() async {
    final resource = widget.entries.value;
    if (resource.phase != StatusResourcePhase.data) return;
    final projection = PregnancyDiaryProjection(
      entries: resource.data ?? const <PregnancyDiaryEntry>[],
      now: widget.now(),
    );
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (sheetContext) => _PregnancyDiaryEditorSheet(
        existing: projection.today,
        entryDate: widget.now(),
        mutation: widget.mutation,
        onSave: widget.onSave,
      ),
    );
    if (saved == true && mounted) {
      await _openDetails(justSaved: true);
    }
  }

  Future<void> _openDetails({bool justSaved = false}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (sheetContext) => _PregnancyDiaryDetailSheet(
        entries: widget.entries,
        now: widget.now,
        justSaved: justSaved,
        onClose: () => Navigator.of(sheetContext).pop(),
        onAgentPrompt: (prompt) {
          Navigator.of(sheetContext).pop();
          widget.onAgentPrompt(prompt);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StatusResource<List<PregnancyDiaryEntry>>>(
      valueListenable: widget.entries,
      builder: (context, resource, _) {
        final projection = PregnancyDiaryProjection(
          entries: resource.data ?? const <PregnancyDiaryEntry>[],
          now: widget.now(),
        );
        return _DiaryCard(
          resource: resource,
          projection: projection,
          onViewDiary: _openDetails,
          onRecordToday: resource.phase == StatusResourcePhase.data
              ? _openEditor
              : null,
        );
      },
    );
  }
}

class _DiaryCard extends StatelessWidget {
  const _DiaryCard({
    required this.resource,
    required this.projection,
    required this.onViewDiary,
    required this.onRecordToday,
  });

  final StatusResource<List<PregnancyDiaryEntry>> resource;
  final PregnancyDiaryProjection projection;
  final VoidCallback onViewDiary;
  final VoidCallback? onRecordToday;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('status-pregnancy-diary-card'),
      decoration: BoxDecoration(
        color: const Color(0xfffffaf8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffeadfd8)),
        boxShadow: MomCozyShadows.soft,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '孕期日记',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: MomCozyColors.foreground,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _OutlineAction(
                    key: const ValueKey('status-pregnancy-diary-view-button'),
                    label: '查看日记',
                    onPressed: onViewDiary,
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xfffff7f1),
                border: Border.symmetric(
                  horizontal: BorderSide(color: Color(0xffead8ce)),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _DiaryStat(
                          value: projection.recentCount.toString(),
                          label: '近7天记录',
                        ),
                      ),
                      const _DiaryStatDivider(),
                      Expanded(
                        child: _DiaryStat(
                          value: projection.recentHealthNoteCount.toString(),
                          label: '健康咨询',
                        ),
                      ),
                      const _DiaryStatDivider(),
                      Expanded(
                        child: _DiaryStat(
                          value: projection.questionCount.toString(),
                          label: '产检问题',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xd9ead8ce)),
                  const SizedBox(height: 11),
                  const _AgentNote(text: '记录几天后，我可以帮你回顾睡眠、情绪、胎动和身体感受的变化。'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '今日日记',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: MomCozyColors.foreground,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      _FilledAction(
                        key: const ValueKey(
                          'status-pregnancy-diary-record-button',
                        ),
                        label: '记录今天',
                        icon: Icons.edit_outlined,
                        onPressed: onRecordToday,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _TodayDiaryBody(resource: resource, projection: projection),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayDiaryBody extends StatelessWidget {
  const _TodayDiaryBody({required this.resource, required this.projection});

  final StatusResource<List<PregnancyDiaryEntry>> resource;
  final PregnancyDiaryProjection projection;

  @override
  Widget build(BuildContext context) {
    if (resource.isLoading || resource.phase == StatusResourcePhase.initial) {
      return const _DiaryMessage(text: '正在加载孕期日记…', centered: true);
    }
    if (resource.hasError && resource.data == null) {
      return const _DiaryMessage(text: '孕期日记暂时无法同步，请稍后重试。', centered: true);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 17),
      decoration: BoxDecoration(
        color: const Color(0xfffffaf8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffead8ce),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (projection.todayTextBlocks.isEmpty)
            Text(
              '今天还没有记录哦。可以先写下心情、身体感受、胎动或想问医生的问题。',
              style: _bodyStyle(context, fontWeight: FontWeight.w800),
            )
          else
            for (
              var index = 0;
              index < projection.todayTextBlocks.length;
              index += 1
            ) ...[
              if (index > 0) const SizedBox(height: 8),
              Text(
                projection.todayTextBlocks[index],
                style: _bodyStyle(context, fontWeight: FontWeight.w800),
              ),
            ],
          const SizedBox(height: 12),
          const _AgentNote(text: '和我聊天时，我会自动记录你的今日情况和健康信息'),
        ],
      ),
    );
  }
}

class _PregnancyDiaryEditorSheet extends StatefulWidget {
  const _PregnancyDiaryEditorSheet({
    required this.existing,
    required this.entryDate,
    required this.mutation,
    required this.onSave,
  });

  final PregnancyDiaryEntry? existing;
  final DateTime entryDate;
  final ValueListenable<StatusMutationState> mutation;
  final PregnancyDiarySave onSave;

  @override
  State<_PregnancyDiaryEditorSheet> createState() =>
      _PregnancyDiaryEditorSheetState();
}

class _PregnancyDiaryEditorSheetState
    extends State<_PregnancyDiaryEditorSheet> {
  late final TextEditingController _gestationalWeekController;
  late final TextEditingController _otherSymptomsController;
  late final TextEditingController _appointmentController;
  late final TextEditingController _contentController;
  late String _mood;
  late String _energy;
  late String _sleep;
  late String _fetalMovement;
  late final Set<String> _symptoms;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final draft = PregnancyDiaryDraft.fromEntry(widget.existing);
    _gestationalWeekController = TextEditingController(
      text: draft.gestationalWeek,
    );
    _appointmentController = TextEditingController(text: draft.appointmentNote);
    _contentController = TextEditingController(text: draft.content);
    _mood = draft.mood;
    _energy = draft.energyLevel;
    _sleep = draft.sleepSummary;
    _fetalMovement = draft.fetalMovement;
    _symptoms = draft.symptomTags.where(_symptomOptions.contains).toSet();
    _otherSymptomsController = TextEditingController(
      text: draft.symptomTags
          .where((tag) => !_symptomOptions.contains(tag))
          .join('、'),
    );
  }

  @override
  void dispose() {
    _gestationalWeekController.dispose();
    _otherSymptomsController.dispose();
    _appointmentController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  PregnancyDiaryDraft _draft() {
    final extraSymptoms = _otherSymptomsController.text
        .split(RegExp(r'[、,，\s]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty);
    final symptomTags = <String>{
      ..._symptoms,
      ...extraSymptoms,
    }.toList(growable: false);
    return PregnancyDiaryDraft(
      gestationalWeek: _gestationalWeekController.text,
      mood: _mood,
      energyLevel: _energy,
      sleepSummary: _sleep,
      fetalMovement: _fetalMovement,
      symptomTags: symptomTags,
      appointmentNote: _appointmentController.text,
      nutritionNote: widget.existing?.nutritionNote ?? '',
      content: _contentController.text,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final draft = _draft();
    if (!draft.hasContent) {
      setState(() => _error = '至少写下一项今天的状态或记录');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    var saved = false;
    try {
      saved = await widget.onSave(widget.entryDate, draft);
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
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
        key: const ValueKey('status-pregnancy-diary-editor-dialog'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '记录今天的孕期日记',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: MomCozyColors.foreground,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.entryDate.month}月${widget.entryDate.day}日',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: MomCozyColors.mutedForeground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭编辑',
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('status-pregnancy-diary-editor-scroll'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EditorTextField(
                      label: '孕周',
                      controller: _gestationalWeekController,
                      hintText: '如 孕 32 周',
                      fieldKey: const ValueKey(
                        'status-pregnancy-diary-gestational-week-input',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ChoiceSection(
                      label: '心情',
                      options: _moodOptions,
                      selected: _mood,
                      onSelected: (value) => setState(() => _mood = value),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ChoiceSection(
                            label: '精力',
                            options: _energyOptions,
                            selected: _energy,
                            onSelected: (value) =>
                                setState(() => _energy = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ChoiceSection(
                            label: '睡眠',
                            options: _sleepOptions,
                            selected: _sleep,
                            onSelected: (value) =>
                                setState(() => _sleep = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ChoiceSection(
                      label: '胎动',
                      options: _fetalMovementOptions,
                      selected: _fetalMovement,
                      onSelected: (value) =>
                          setState(() => _fetalMovement = value),
                    ),
                    const SizedBox(height: 12),
                    _MultiChoiceSection(
                      selected: _symptoms,
                      otherController: _otherSymptomsController,
                      onChanged: (option) {
                        setState(() {
                          if (!_symptoms.remove(option)) _symptoms.add(option);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _EditorTextField(
                      label: '想问医生的问题',
                      controller: _appointmentController,
                      hintText: '比如下次产检想确认的身体变化、检查结果或用药问题',
                      minLines: 2,
                      maxLines: 4,
                      fieldKey: const ValueKey(
                        'status-pregnancy-diary-appointment-input',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _EditorTextField(
                      label: '今天想记录的事',
                      controller: _contentController,
                      hintText: '生活片段、产检点滴、情绪变化，或想留给自己的话',
                      minLines: 4,
                      maxLines: 6,
                      fieldKey: const ValueKey(
                        'status-pregnancy-diary-note-input',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xfffffaf0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '如果有明显胎动异常、出血、剧烈腹痛或其它担心的情况，请及时联系医生。',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xff6d5530),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  key: const ValueKey('status-pregnancy-diary-save-error'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                key: const ValueKey('status-pregnancy-diary-save-button'),
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: MomCozyColors.foreground,
                  foregroundColor: MomCozyColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _saving
                      ? '保存中…'
                      : widget.existing != null
                      ? '保存今天的修改'
                      : '保存今天的日记',
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

class _PregnancyDiaryDetailSheet extends StatelessWidget {
  const _PregnancyDiaryDetailSheet({
    required this.entries,
    required this.now,
    required this.justSaved,
    required this.onClose,
    required this.onAgentPrompt,
  });

  final ValueListenable<StatusResource<List<PregnancyDiaryEntry>>> entries;
  final DateTime Function() now;
  final bool justSaved;
  final VoidCallback onClose;
  final ValueChanged<String> onAgentPrompt;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('status-detail-pregnancy-diary'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                  '孕期日记',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '关闭详情',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Flexible(
            child:
                ValueListenableBuilder<
                  StatusResource<List<PregnancyDiaryEntry>>
                >(
                  valueListenable: entries,
                  builder: (context, resource, _) {
                    final projection = PregnancyDiaryProjection(
                      entries: resource.data ?? const <PregnancyDiaryEntry>[],
                      now: now(),
                    );
                    return SingleChildScrollView(
                      child: _DiaryDetailBody(
                        resource: resource,
                        projection: projection,
                        justSaved: justSaved,
                        onAgentPrompt: onAgentPrompt,
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class _DiaryDetailBody extends StatelessWidget {
  const _DiaryDetailBody({
    required this.resource,
    required this.projection,
    required this.justSaved,
    required this.onAgentPrompt,
  });

  final StatusResource<List<PregnancyDiaryEntry>> resource;
  final PregnancyDiaryProjection projection;
  final bool justSaved;
  final ValueChanged<String> onAgentPrompt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (justSaved) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xfff2fbf7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xffbfe3d8)),
            ),
            child: Text(
              '今天的记录已保存，我可以继续帮你整理产检问题或回顾最近几天的状态变化。',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xff3f7162),
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (projection.entries.isNotEmpty) ...[
          _DiaryAgentAction(
            title: projection.primaryAction,
            subtitle: projection.primarySubtitle,
            onPressed: () => onAgentPrompt(projection.primaryPrompt),
          ),
          const SizedBox(height: 16),
        ],
        if (resource.isLoading || resource.phase == StatusResourcePhase.initial)
          const _DiaryMessage(text: '正在加载孕期日记…', centered: true)
        else if (resource.hasError && resource.data == null)
          const _DiaryMessage(text: '孕期日记暂时无法同步，请稍后重试。', centered: true)
        else if (projection.entries.isEmpty)
          const _DiaryEmptyState()
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '最近记录',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MomCozyColors.foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${projection.entries.length} 篇',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: MomCozyColors.mutedForeground,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (
            var index = 0;
            index < projection.entries.length;
            index += 1
          ) ...[
            _DiaryEntryCard(
              entry: projection.entries[index],
              first: index == 0,
            ),
            if (index != projection.entries.length - 1)
              const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _DiaryEntryCard extends StatelessWidget {
  const _DiaryEntryCard({required this.entry, required this.first});

  final PregnancyDiaryEntry entry;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final signalTags = PregnancyDiaryProjection.signalTags(entry);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: first ? const Color(0xfffff7ee) : const Color(0xfffffdfb),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: first ? const Color(0xffefc8ac) : const Color(0xffeadfd8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.entryDate.month}月${entry.entryDate.day}日',
                      style: _bodyStyle(context, fontWeight: FontWeight.w900),
                    ),
                    if (entry.gestationalWeek.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.gestationalWeek.trim(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xff8a757b),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (first)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xfff4e3d5),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '今天',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xff9b552f),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            entry.content.trim().isNotEmpty
                ? entry.content.trim()
                : PregnancyDiaryProjection.summary(entry),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(context),
          ),
          if (entry.healthNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DiaryHealthNotes(notes: entry.healthNotes.take(2).toList()),
          ],
          if (signalTags.isNotEmpty || entry.hasAppointmentQuestion) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in signalTags) _DiaryTag(label: tag),
                if (entry.hasAppointmentQuestion)
                  const _DiaryTag(label: '有产检问题', emphasized: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DiaryHealthNotes extends StatelessWidget {
  const _DiaryHealthNotes({required this.notes});

  final List<PregnancyDiaryHealthNote> notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '健康咨询记录',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xffb66335),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          for (var index = 0; index < notes.length; index += 1) ...[
            const SizedBox(height: 8),
            Text(
              notes[index].topic.trim().isEmpty
                  ? '健康咨询'
                  : notes[index].topic.trim(),
              style: _bodyStyle(context, fontWeight: FontWeight.w900),
            ),
            if (notes[index].userReport.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                notes[index].userReport.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle(context),
              ),
            ],
            if (notes[index].followUp.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                notes[index].followUp.trim(),
                style: _bodyStyle(
                  context,
                ).copyWith(color: const Color(0xff8a5b3f)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DiaryAgentAction extends StatelessWidget {
  const _DiaryAgentAction({
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xffeadfd8)),
      ),
      child: InkWell(
        key: const ValueKey('status-pregnancy-diary-agent-action'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundImage: AssetImage(MomCozyAssets.agentAvatar),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _bodyStyle(context, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xff8a757b),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xfff5eee9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Color(0xff9b552f),
                  size: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiaryEmptyState extends StatelessWidget {
  const _DiaryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xfffffdfb),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffeadfd8)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.menu_book_outlined,
            color: Color(0xffb66335),
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            '还没有孕期日记',
            style: _bodyStyle(context, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '从今天开始记录心情、身体感受、胎动和产检点滴。',
            textAlign: TextAlign.center,
            style: _bodyStyle(context).copyWith(color: const Color(0xff7f6b70)),
          ),
        ],
      ),
    );
  }
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return _EditorSection(
      label: label,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final option in options)
            ChoiceChip(
              key: ValueKey('status-pregnancy-diary-choice-$option'),
              label: Text(option),
              selected: selected == option,
              onSelected: (_) => onSelected(option),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              labelStyle: TextStyle(
                color: selected == option
                    ? Colors.white
                    : const Color(0xff5c6870),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              backgroundColor: Colors.white,
              selectedColor: const Color(0xff2f8a91),
              side: BorderSide.none,
              shape: const StadiumBorder(),
            ),
        ],
      ),
    );
  }
}

class _MultiChoiceSection extends StatelessWidget {
  const _MultiChoiceSection({
    required this.selected,
    required this.otherController,
    required this.onChanged,
  });

  final Set<String> selected;
  final TextEditingController otherController;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _EditorSection(
      label: '身体感受',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final option in _symptomOptions)
                FilterChip(
                  key: ValueKey('status-pregnancy-diary-symptom-$option'),
                  label: Text(option),
                  selected: selected.contains(option),
                  onSelected: (_) => onChanged(option),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  labelStyle: TextStyle(
                    color: selected.contains(option)
                        ? Colors.white
                        : const Color(0xff5c6870),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xff2f8a91),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('status-pregnancy-diary-other-symptoms-input'),
            controller: otherController,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            decoration: _fieldDecoration('也可以补充其它感受'),
          ),
        ],
      ),
    );
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({required this.label, required this.child});

  final String label;
  final Widget child;

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
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _EditorTextField extends StatelessWidget {
  const _EditorTextField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.fieldKey,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final Key fieldKey;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return _EditorSection(
      label: label,
      child: TextField(
        key: fieldKey,
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        textInputAction: maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.done,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        decoration: _fieldDecoration(hintText),
      ),
    );
  }
}

class _DiaryMessage extends StatelessWidget {
  const _DiaryMessage({required this.text, required this.centered});

  final String text;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: MomCozyColors.background.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: _bodyStyle(
          context,
        ).copyWith(color: MomCozyColors.mutedForeground),
      ),
    );
  }
}

class _DiaryStat extends StatelessWidget {
  const _DiaryStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xff9b552f),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xff7d666d),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DiaryStatDivider extends StatelessWidget {
  const _DiaryStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xffead8ce),
    );
  }
}

class _AgentNote extends StatelessWidget {
  const _AgentNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 14,
          backgroundImage: AssetImage(MomCozyAssets.agentAvatar),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xff8a8185),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: const Color(0xff9b552f),
          backgroundColor: const Color(0xfffff7f1),
          side: const BorderSide(color: Color(0xffead8ce)),
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xff9b552f),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _FilledAction extends StatelessWidget {
  const _FilledAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: const Color(0xffb66a3c),
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
        ),
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DiaryTag extends StatelessWidget {
  const _DiaryTag({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xfff5eee9),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: emphasized ? const Color(0xff9b552f) : const Color(0xff75666b),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hintText) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: MomCozyColors.mutedForeground,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: MomCozyColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
  );
}

TextStyle _bodyStyle(
  BuildContext context, {
  FontWeight fontWeight = FontWeight.w600,
}) {
  return Theme.of(context).textTheme.bodySmall?.copyWith(
        color: const Color(0xff5f5357),
        fontSize: 12,
        fontWeight: fontWeight,
        height: 1.45,
      ) ??
      TextStyle(
        color: const Color(0xff5f5357),
        fontSize: 12,
        fontWeight: fontWeight,
        height: 1.45,
      );
}
