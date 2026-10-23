import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_actions.dart';
import 'package:momcozy_flutter_app/services/baby/baby_profiles_api_repository.dart';

import '../data/chat_first_record_repository.dart';
import '../domain/chat_first_record.dart';

Future<String?> showChatFirstRecordSheet(
  BuildContext context, {
  required MomCozyApiRuntime runtime,
  required ChatFirstRecordKind kind,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: const Color(0xFFFFFDFA),
  constraints: const BoxConstraints(maxWidth: 430),
  shape: const RoundedRectangleBorder(),
  builder: (context) => ChatFirstRecordSheet(runtime: runtime, kind: kind),
);

class ChatFirstRecordSheet extends StatefulWidget {
  const ChatFirstRecordSheet({
    super.key,
    required this.runtime,
    required this.kind,
  });

  final MomCozyApiRuntime runtime;
  final ChatFirstRecordKind kind;

  @override
  State<ChatFirstRecordSheet> createState() => _ChatFirstRecordSheetState();
}

class _ChatFirstRecordSheetState extends State<ChatFirstRecordSheet> {
  late final ChatFirstRecordDraft _draft = ChatFirstRecordDraft(
    kind: widget.kind,
    startedAt: widget.runtime.now(),
  );
  final _volume = TextEditingController(text: '50');
  final _duration = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String _error = '';
  String? _pendingKey;
  Future<bool>? _selectedBabyCheck;
  String _candidateBabyId = '';

  bool get _requiresBaby => widget.kind != ChatFirstRecordKind.pumping;

  @override
  void initState() {
    super.initState();
    _checkSelectedBaby();
  }

  @override
  void didUpdateWidget(covariant ChatFirstRecordSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runtime != widget.runtime ||
        oldWidget.kind != widget.kind ||
        (_requiresBaby &&
            _candidateBabyId != widget.runtime.currentSession.babyId.trim())) {
      _checkSelectedBaby();
    }
  }

  void _checkSelectedBaby() {
    final candidate = _requiresBaby
        ? widget.runtime.currentSession.babyId.trim()
        : '';
    _candidateBabyId = candidate;
    _selectedBabyCheck = candidate.isEmpty
        ? null
        : BabyProfilesApiRepository(transport: widget.runtime.jsonTransport)
              .list()
              .then((profiles) => profiles.any((baby) => baby.id == candidate));
  }

  @override
  void dispose() {
    _volume.dispose();
    _duration.dispose();
    _weight.dispose();
    _height.dispose();
    _note.dispose();
    super.dispose();
  }

  void _changed() => setState(() {
    _pendingKey = null;
    _error = '';
  });

  @override
  Widget build(BuildContext context) {
    final requiresBaby = _requiresBaby;
    if (!requiresBaby || _candidateBabyId.isEmpty) {
      return _buildSheet(
        context,
        requiresBaby: requiresBaby,
        selectedBabyId: '',
      );
    }
    return FutureBuilder<bool>(
      future: _selectedBabyCheck,
      builder: (context, snapshot) => _buildSheet(
        context,
        requiresBaby: true,
        selectedBabyId: snapshot.data == true ? _candidateBabyId : '',
        babyCheckLoading: snapshot.connectionState != ConnectionState.done,
        babyCheckError: snapshot.hasError,
      ),
    );
  }

  Widget _buildSheet(
    BuildContext context, {
    required bool requiresBaby,
    required String selectedBabyId,
    bool babyCheckLoading = false,
    bool babyCheckError = false,
  }) {
    return Padding(
      key: const ValueKey('chat-first-record-sheet'),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 4, 15, 4),
              child: SizedBox(
                height: 54,
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('record-close'),
                      tooltip: '关闭表单',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 21),
                    ),
                    Expanded(
                      child: Text(
                        widget.kind.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF382F33),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(15, 16, 15, 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFEEE7E3)),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0649343A),
                        blurRadius: 22,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (requiresBaby && babyCheckLoading) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('正在核对当前账号的宝宝档案…'),
                        ),
                      ] else if (requiresBaby && babyCheckError) ...[
                        const Text('暂时无法核对宝宝档案，请检查网络后重试。不会将记录误标为已同步。'),
                        TextButton(
                          onPressed: () => setState(_checkSelectedBaby),
                          child: const Text('重试'),
                        ),
                      ] else if (requiresBaby && selectedBabyId.isEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('请先创建宝宝档案并选择宝宝，再保存此类记录。不会将未关联记录误标为已同步。'),
                        ),
                        TextButton.icon(
                          key: const ValueKey('record-create-baby'),
                          onPressed: () {
                            final router = GoRouter.of(context);
                            Navigator.of(context).pop();
                            router.go('/baby');
                          },
                          icon: const Icon(Icons.child_care_outlined),
                          label: const Text('创建宝宝档案'),
                        ),
                      ] else ...[
                        _timeField(
                          switch (widget.kind) {
                            ChatFirstRecordKind.formula ||
                            ChatFirstRecordKind.expressed ||
                            ChatFirstRecordKind.pumping ||
                            ChatFirstRecordKind.nursing ||
                            ChatFirstRecordKind.sleep => '开始时间',
                            ChatFirstRecordKind.diaper => '更换时间',
                            ChatFirstRecordKind.growth => '测量时间',
                          },
                          'record-start',
                          _draft.startedAt,
                          _chooseStart,
                        ),
                        if (widget.kind == ChatFirstRecordKind.sleep) ...[
                          const SizedBox(height: 14),
                          _timeField(
                            '结束时间',
                            'record-end',
                            _draft.endedAt,
                            _chooseEnd,
                          ),
                        ],
                        const SizedBox(height: 18),
                        _kindFields(),
                        if (widget.kind == ChatFirstRecordKind.pumping) ...[
                          const SizedBox(height: 18),
                          _timeField(
                            '结束时间 · 可选',
                            'record-end',
                            _draft.endedAt,
                            _chooseEnd,
                          ),
                        ],
                        if (widget.kind != ChatFirstRecordKind.growth) ...[
                          const SizedBox(height: 18),
                          const Text(
                            '备注',
                            style: TextStyle(
                              color: Color(0xFF5F5254),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            key: const ValueKey('record-note'),
                            controller: _note,
                            enabled: !_busy,
                            maxLines: 2,
                            maxLength: requiresBaby ? 2000 : 255,
                            buildCounter:
                                (
                                  context, {
                                  required currentLength,
                                  required isFocused,
                                  maxLength,
                                }) => null,
                            decoration: InputDecoration(
                              hintText: '选填，记录更多细节',
                              hintStyle: const TextStyle(fontSize: 13),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 9,
                              ),
                              border: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: Color(0xFFEEE7E3),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (_) => _changed(),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          '保存成功后同步至当前账号。失败时保留填写内容，便于重试。',
                          style: TextStyle(
                            color: Color(0xFF786E6B),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        if (_error.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Semantics(
                              liveRegion: true,
                              child: Container(
                                key: const ValueKey('record-error'),
                                width: double.infinity,
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0F1),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Text(
                                  _error,
                                  style: const TextStyle(
                                    color: Color(0xFFA1304A),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (!requiresBaby || selectedBabyId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 9, 15, 18),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    key: const ValueKey('record-save'),
                    onPressed: _busy ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFA55776),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(_busy ? '正在保存…' : '保存'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _timeField(
    String title,
    String key,
    DateTime? value,
    VoidCallback onTap,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF382F33),
        ),
      ),
      const SizedBox(height: 7),
      OutlinedButton(
        key: ValueKey(key),
        onPressed: _busy ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF544B4D),
          backgroundColor: const Color(0xFFFBF8F7),
          side: const BorderSide(color: Color(0xFFEEE7E3)),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null ? '选择日期与时间' : _format(value),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: Color(0xFF874D65),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _milkVolumeField() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Row(
        children: [
          Text(
            '奶量',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF382F33),
            ),
          ),
          Spacer(),
          Flexible(
            child: Text(
              '毫升 · 可直接输入',
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 11, color: Color(0xFF82777A)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          IconButton.filledTonal(
            key: const ValueKey('record-volume-minus'),
            tooltip: '减少 5 毫升',
            onPressed: _busy ? null : () => _stepVolume(-5),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF8EFF2),
              foregroundColor: const Color(0xFF874D65),
            ),
            icon: const Icon(Icons.remove_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              key: const ValueKey('record-volume'),
              controller: _volume,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '奶量',
                suffixText: 'ml',
                filled: true,
                fillColor: const Color(0xFFF8F4F3),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (_) => _changed(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            key: const ValueKey('record-volume-plus'),
            tooltip: '增加 5 毫升',
            onPressed: _busy ? null : () => _stepVolume(5),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF8EFF2),
              foregroundColor: const Color(0xFF874D65),
            ),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
          const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFF8EFF2),
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: SizedBox(
              width: 40,
              height: 44,
              child: Icon(Icons.local_drink_outlined, color: Color(0xFFA55776)),
            ),
          ),
        ],
      ),
    ],
  );

  void _stepVolume(int step) {
    final current = double.tryParse(_volume.text.trim()) ?? 0;
    final maximum = widget.kind == ChatFirstRecordKind.pumping ? 3000 : 1000;
    final next = (current + step).clamp(1, maximum);
    _volume
      ..text = next == next.roundToDouble()
          ? next.toInt().toString()
          : next.toString()
      ..selection = TextSelection.collapsed(offset: _volume.text.length);
    _changed();
  }

  Widget _kindFields() => switch (widget.kind) {
    ChatFirstRecordKind.nursing => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('喂养侧'),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in const [
              ('left', '左侧'),
              ('right', '右侧'),
              ('both', '双侧'),
            ])
              ChoiceChip(
                key: ValueKey('record-side-${entry.$1}'),
                label: Text(entry.$2),
                selected: _draft.side == entry.$1,
                onSelected: _busy
                    ? null
                    : (_) {
                        _draft.side = entry.$1;
                        _changed();
                      },
              ),
          ],
        ),
        const SizedBox(height: 13),
        _numeric('record-duration', '喂养时长（分钟）', _duration),
      ],
    ),
    ChatFirstRecordKind.formula ||
    ChatFirstRecordKind.expressed ||
    ChatFirstRecordKind.pumping => _milkVolumeField(),
    ChatFirstRecordKind.growth => Column(
      children: [
        _numeric('record-weight', '体重（kg）', _weight),
        const SizedBox(height: 13),
        _numeric('record-height', '身长（cm）', _height),
      ],
    ),
    ChatFirstRecordKind.diaper => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('尿布状态'),
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in const [
              ('wet', '嘘嘘'),
              ('dirty', '臭臭'),
              ('both', '嘘嘘 + 臭臭'),
            ])
              ChoiceChip(
                key: ValueKey('record-diaper-${entry.$1}'),
                label: Text(entry.$2),
                selected: _draft.diaperKind == entry.$1,
                onSelected: _busy
                    ? null
                    : (_) {
                        _draft.diaperKind = entry.$1;
                        _changed();
                      },
              ),
          ],
        ),
      ],
    ),
    ChatFirstRecordKind.sleep => const Text('请选择睡眠开始与结束时间。'),
  };

  Widget _numeric(String key, String label, TextEditingController controller) =>
      TextField(
        key: ValueKey(key),
        controller: controller,
        enabled: !_busy,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => _changed(),
      );

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(widget.runtime.now().year - 2, 1),
      lastDate: widget.runtime.now(),
    );
    if (day == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null || !mounted) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Future<void> _chooseStart() async {
    final next = await _pickDateTime(_draft.startedAt);
    if (next != null && mounted) {
      _draft.startedAt = next;
      _changed();
    }
  }

  Future<void> _chooseEnd() async {
    final next = await _pickDateTime(_draft.endedAt ?? widget.runtime.now());
    if (next != null && mounted) {
      _draft.endedAt = next;
      _changed();
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_requiresBaby) {
      bool verified = false;
      try {
        verified = await _selectedBabyCheck ?? false;
      } catch (_) {
        // A failed lookup must not turn a stale selection into a real baby.
      }
      if (!mounted) return;
      if (!verified ||
          _candidateBabyId.isEmpty ||
          _candidateBabyId != widget.runtime.currentSession.babyId.trim()) {
        setState(() => _error = '请先核对并选择当前账号的真实宝宝档案。');
        return;
      }
    }
    _draft
      ..volumeMl = double.tryParse(_volume.text.trim())
      ..durationMinutes = int.tryParse(_duration.text.trim())
      ..weightKg = double.tryParse(_weight.text.trim())
      ..heightCm = double.tryParse(_height.text.trim())
      ..note = _note.text;
    try {
      _draft.payload(widget.runtime.now());
    } on FormatException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    _pendingKey ??= const Uuid().v4();
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final ownerUserId = widget.runtime.currentSession.userId;
      final selectedBabyId = widget.runtime.currentSession.babyId;
      final savedId =
          await ChatFirstRecordRepository(
            transport: widget.runtime.jsonTransport,
            ownerUserId: ownerUserId,
            babyId: selectedBabyId,
          ).save(
            _draft,
            now: widget.runtime.now(),
            timezone: widget.kind == ChatFirstRecordKind.growth
                ? await widget.runtime.timezoneProvider()
                : '',
            idempotencyKey: _pendingKey!,
          );
      if (!mounted) return;
      final currentSession = widget.runtime.currentSession;
      final scopeChanged =
          currentSession.userId != ownerUserId ||
          (_requiresBaby && currentSession.babyId != selectedBabyId);
      widget.runtime.notifyRecordsChanged();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(savedId);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            scopeChanged
                ? '${widget.kind.label}已由服务器确认保存，但账号或宝宝已切换，请返回原记录范围核对。'
                : '${widget.kind.label} · 保存成功，已同步至当前账号',
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，未同步。请检查网络并重试，填写内容已保留。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _format(DateTime value) =>
      '${value.year}年${value.month}月${value.day}日 '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
