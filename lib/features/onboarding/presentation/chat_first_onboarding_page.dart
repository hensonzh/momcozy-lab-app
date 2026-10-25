import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/design_system/momcozy_design_system.dart';
import '../domain/chat_first_onboarding.dart';
import 'onboarding_controller.dart';

const _paper = Color(0xFFFFFDFC);
const _ink = Color(0xFF2B2826);
const _muted = Color(0xFF786E6B);
const _accent = Color(0xFFA55776);
const _border = Color(0xFFEDE6E3);
const _selected = Color(0xFFF1DCE6);

typedef ChatFirstDatePicker =
    Future<DateTime?> Function(BuildContext context, DateTime initialDate);

class ChatFirstOnboardingPage extends StatefulWidget {
  const ChatFirstOnboardingPage({
    super.key,
    required this.controller,
    this.entryPath = '/',
    this.now = DateTime.now,
    this.pickDate,
  });

  final OnboardingController controller;
  final String entryPath;
  final DateTime Function() now;
  final ChatFirstDatePicker? pickDate;

  @override
  State<ChatFirstOnboardingPage> createState() =>
      _ChatFirstOnboardingPageState();
}

class _ChatFirstOnboardingPageState extends State<ChatFirstOnboardingPage> {
  late final ChatFirstOnboardingDraft _draft = ChatFirstOnboardingDraft(
    now: widget.now,
  );
  final _pageScroll = ScrollController();
  final _ageScroll = ScrollController(initialScrollOffset: 9 * 65);
  final _weeksScroll = ScrollController(initialScrollOffset: 13 * 65);
  int _step = 0;
  String _error = '';

  @override
  void dispose() {
    _pageScroll.dispose();
    _ageScroll.dispose();
    _weeksScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final gate = widget.controller;
      final ready =
          gate.phase == OnboardingGatePhase.ready &&
          gate.state != null &&
          !gate.state!.canEnterApp;
      return Scaffold(
        backgroundColor: MomCozyColors.chatFirstCanvas,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: switch (gate.phase) {
                OnboardingGatePhase.idle || OnboardingGatePhase.loading =>
                  const Center(child: CircularProgressIndicator()),
                OnboardingGatePhase.failure => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('暂时无法加载资料，请检查网络后重试。'),
                      const SizedBox(height: 12),
                      TextButton(onPressed: gate.load, child: const Text('重试')),
                    ],
                  ),
                ),
                OnboardingGatePhase.ready =>
                  ready
                      ? _flow(context)
                      : const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
        ),
      );
    },
  );

  Widget _flow(BuildContext context) => Column(
    children: [
      if (_step > 0) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 22, 0),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 44,
                child: IconButton(
                  key: const ValueKey('setup-back'),
                  tooltip: '返回上一步',
                  onPressed: widget.controller.busy
                      ? null
                      : () => _goTo(_step - 1),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
                ),
              ),
              const Spacer(),
              Text(
                '$_step/5',
                style: const TextStyle(
                  color: _accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Padding(
          key: const ValueKey('setup-progress'),
          padding: const EdgeInsets.fromLTRB(22, 5, 22, 0),
          child: Row(
            children: [
              for (var index = 0; index < 5; index++) ...[
                if (index > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: index < _step ? _accent : const Color(0xFFE9E3E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      Expanded(
        child: SingleChildScrollView(
          controller: _pageScroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, _step == 0 ? 83 : 18, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                key: const ValueKey('setup-intro-card'),
                padding: const EdgeInsets.fromLTRB(18, 19, 18, 20),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFF2E2E4)),
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF7E6EA), Color(0xFFFBF1ED)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titles[_step],
                      style: const TextStyle(
                        color: Color(0xFF503441),
                        fontSize: 23,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _descriptions[_step],
                      style: TextStyle(
                        color: const Color(0xFF735F65),
                        fontSize: _step == 0 ? 12 : 13,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: _step == 0
                    ? 31
                    : _step == 5
                    ? 16
                    : 18,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _stepContent(),
              ),
              if (_error.isNotEmpty ||
                  widget.controller.errorMessage.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  _error.isNotEmpty ? _error : '资料保存失败，请检查网络后重试。',
                  key: const ValueKey('setup-error'),
                  style: const TextStyle(
                    color: Color(0xFFA33D5B),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      if (_step != 0 && _step != 1) _footer(),
    ],
  );

  Widget _stepContent() => switch (_step) {
    0 => _groupedChoices([
      for (final role in FamilyRole.values)
        (role.label, 'role-${role.wireValue}', () => _selectRole(role)),
    ]),
    1 => _groupedChoices([
      ('备孕', 'stage-preparing', () => _unavailableStage()),
      ('孕期', 'stage-unavailable-pregnant', () => _unavailableStage()),
      ('产后', 'stage-postpartum', () => _goTo(2)),
    ]),
    2 => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('你现在多大？'),
        const SizedBox(height: 13),
        _numberRail(
          'age',
          18,
          45,
          _draft.age,
          _ageScroll,
          (value) => setState(() {
            _draft.age = value;
            _error = '';
          }),
          '岁',
        ),
        const SizedBox(height: 31),
        _fieldLabel('这次是第几次生育？'),
        const SizedBox(height: 13),
        _numberChoices(
          'delivery-count',
          1,
          6,
          _draft.deliveryCount,
          (value) => setState(() {
            _draft.deliveryCount = value;
            _error = '';
          }),
          '次',
        ),
      ],
    ),
    3 => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('分娩日期'),
        const SizedBox(height: 12),
        Material(
          color: _paper,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            key: const ValueKey('delivery-date'),
            onTap: _chooseDate,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _draft.deliveryDate == null
                          ? '选择分娩日期'
                          : '${_draft.deliveryDate!.year}-${_draft.deliveryDate!.month.toString().padLeft(2, '0')}-${_draft.deliveryDate!.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: _ink, fontSize: 14),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: _muted,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 29),
        _fieldLabel('分娩时孕周'),
        const SizedBox(height: 12),
        _numberRail(
          'weeks',
          24,
          42,
          _draft.gestationWeeks,
          _weeksScroll,
          (value) => setState(() {
            _draft.gestationWeeks = value;
            _draft.gestationDays = value >= 37 ? 0 : null;
            _error = '';
          }),
          '周',
        ),
        if (_draft.gestationWeeks != null && _draft.gestationWeeks! < 37) ...[
          const SizedBox(height: 13),
          const Text('＋ 再加几天', style: TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 9),
          KeyedSubtree(
            key: const ValueKey('gestation-days'),
            child: _numberChoices(
              'days',
              0,
              6,
              _draft.gestationDays,
              (value) => setState(() {
                _draft.gestationDays = value;
                _error = '';
              }),
              '天',
            ),
          ),
        ],
        const SizedBox(height: 29),
        _fieldLabel('这次有几个宝宝？'),
        const SizedBox(height: 13),
        _numberChoices(
          'baby-count',
          1,
          4,
          _draft.babyCount,
          (value) => setState(() {
            _draft.babyCount = value;
            _error = '';
          }),
          '个宝宝',
        ),
      ],
    ),
    4 => Column(
      children: [
        for (var index = 0; index < chatFirstConcerns.length; index += 2)
          Padding(
            padding: EdgeInsets.only(
              bottom: index + 2 < chatFirstConcerns.length ? 9 : 0,
            ),
            child: Row(
              children: [
                for (var offset = 0; offset < 2; offset++) ...[
                  if (offset > 0) const SizedBox(width: 9),
                  Expanded(
                    child: index + offset < chatFirstConcerns.length
                        ? _concernChoice(
                            chatFirstConcerns.entries.elementAt(index + offset),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
      ],
    ),
    5 => Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEEE4E0)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          _RecommendedService(
            'recommend-record',
            Icons.trending_up_rounded,
            '记录与持续管理',
            '记录奶量与宝宝成长，依据记录持续跟进变化。',
          ),
          _RecommendedService(
            'recommend-cry',
            Icons.graphic_eq_rounded,
            '哭声识别',
            '从哭声中寻找线索，理解宝宝可能的需要。',
          ),
          _RecommendedService(
            'recommend-poop',
            Icons.child_care_rounded,
            '便便识别',
            '结合便便照片，了解相关线索和照护建议。',
          ),
        ],
      ),
    ),
    _ => const SizedBox.shrink(),
  };

  Widget _concernChoice(MapEntry<String, String> entry) {
    final selected = _draft.concerns.contains(entry.key);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? const Color(0xFFF5E5EA) : Colors.white,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          key: ValueKey('concern-${entry.key}'),
          borderRadius: BorderRadius.circular(17),
          onTap: () => setState(() {
            if (selected) {
              _draft.concerns.remove(entry.key);
            } else {
              _draft.concerns.add(entry.key);
            }
            _error = '';
          }),
          child: Container(
            alignment: Alignment.centerLeft,
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected
                    ? const Color(0xFFD4AAB9)
                    : const Color(0xFFEEE4E2),
              ),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Text(
              entry.value,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF873856)
                    : const Color(0xFF5E5053),
                fontSize: 15,
                height: 1.4,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupedChoices(List<(String, String, VoidCallback)> options) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              for (var index = 0; index < options.length; index++) ...[
                if (index != 0)
                  const Divider(height: 1, color: Color(0xFFF1ECEA)),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey(options[index].$2),
                    onTap: widget.controller.busy ? null : options[index].$3,
                    child: SizedBox(
                      height: 65,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 19),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                options[index].$1,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFFB2A7A4),
                              size: 19,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF5E5053),
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _numberRail(
    String name,
    int first,
    int last,
    int? value,
    ScrollController controller,
    ValueChanged<int> onChanged,
    String unit,
  ) => Container(
    height: 52,
    decoration: BoxDecoration(
      color: const Color(0xFFF7F3F2),
      borderRadius: BorderRadius.circular(17),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => ListView(
        key: ValueKey('$name-scroll'),
        controller: controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          for (var number = first; number <= last; number++)
            SizedBox(
              width: (constraints.maxWidth - 22) / 5,
              child: _numberButton(name, number, value, onChanged, unit),
            ),
        ],
      ),
    ),
  );

  Widget _numberChoices(
    String name,
    int first,
    int last,
    int? value,
    ValueChanged<int> onChanged,
    String unit,
  ) => Container(
    height: 51,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F3F2),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        for (var number = first; number <= last; number++) ...[
          if (number > first) const SizedBox(width: 3),
          Expanded(child: _numberButton(name, number, value, onChanged, unit)),
        ],
      ],
    ),
  );

  Widget _numberButton(
    String name,
    int number,
    int? selected,
    ValueChanged<int> onChanged,
    String unit,
  ) => Semantics(
    label: '$number$unit',
    selected: selected == number,
    button: true,
    child: Material(
      color: selected == number ? _selected : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('$name-$number'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(number),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              color: selected == number ? const Color(0xFF873856) : _muted,
              fontSize: selected == number ? 17 : 15,
              fontWeight: selected == number
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _footer() => Container(
    padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
    decoration: const BoxDecoration(
      color: MomCozyColors.chatFirstCanvas,
      border: Border(top: BorderSide(color: Color(0xFFEEE2DE))),
    ),
    child: Align(
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: _step == 5 ? 1 : .88,
        child: SizedBox(
          height: 45,
          child: FilledButton(
            key: ValueKey(_step == 5 ? 'enter-home' : 'setup-continue'),
            onPressed: widget.controller.busy ? null : _continue,
            style: FilledButton.styleFrom(
              backgroundColor: _step == 5 ? _paper : _accent,
              foregroundColor: _step == 5 ? _accent : Colors.white,
              side: _step == 5
                  ? const BorderSide(color: _accent)
                  : BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              widget.controller.busy
                  ? '正在保存…'
                  : _step == 5
                  ? '进入首页'
                  : '继续',
            ),
          ),
        ),
      ),
    ),
  );

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageScroll.hasClients) _pageScroll.jumpTo(0);
      if (!mounted) return;
      final railWidth =
          (MediaQuery.sizeOf(context).width.clamp(0, 430) - 66) / 5;
      if (step == 2 && _ageScroll.hasClients) _ageScroll.jumpTo(9 * railWidth);
      if (step == 3 && _weeksScroll.hasClients) {
        _weeksScroll.jumpTo(13 * railWidth);
      }
    });
  }

  void _selectRole(FamilyRole role) {
    _draft.role = role;
    _error = '';
    if (role == FamilyRole.mother) {
      _goTo(1);
    } else {
      _save();
    }
  }

  void _unavailableStage() => setState(() {
    _error = '暂未开放，当前仅支持产后阶段。';
  });

  Future<void> _chooseDate() async {
    final today = widget.now();
    final picker = widget.pickDate;
    final picked = picker != null
        ? await picker(context, _draft.deliveryDate ?? today)
        : await showDatePicker(
            context: context,
            initialDate: _draft.deliveryDate ?? today,
            firstDate: DateTime(today.year - 2, 1),
            lastDate: today,
          );
    if (mounted && picked != null) {
      setState(() {
        _draft.deliveryDate = picked;
        _error = '';
      });
    }
  }

  void _continue() {
    if (_step == 5) {
      _save();
      return;
    }
    if (_step == 2 && (_draft.age == null || _draft.deliveryCount == null)) {
      setState(() => _error = '请选择年龄与生育次数。');
      return;
    }
    if (_step == 3) {
      try {
        _draft.toMap();
      } on FormatException catch (error) {
        setState(() => _error = error.message);
        return;
      }
    }
    _goTo(_step + 1);
  }

  Future<void> _save() async {
    if (widget.controller.busy) return;
    final saved = await widget.controller.completeChatFirst(_draft);
    if (!mounted) return;
    if (saved) {
      // The home gate reads the saved account profile before creating the
      // welcome run; this avoids trusting a draft after server confirmation.
      context.go(widget.entryPath);
    } else {
      setState(() => _error = '资料保存失败，请检查网络后重试。');
    }
  }
}

const _titles = <String>[
  '你是宝宝的哪位家人？',
  '你现在处于哪个阶段？',
  '先了解一些基本信息',
  '关于这次分娩',
  '现在你最在意什么？',
  '为你推荐',
];
const _descriptions = <String>[
  '选择你的角色，有助于我们为你量身定制产品体验。',
  '了解你现在的阶段，为你准备更贴合的记录与照护服务。',
  '年龄和生育经历，帮助我们更好地了解你。',
  '了解分娩和宝宝情况，让后续服务更贴合你。',
  '可多选，帮助我们为你提供更贴合的服务。',
  '从记录到识别，陪你照顾自己和宝宝。',
];

class _RecommendedService extends StatelessWidget {
  const _RecommendedService(this.id, this.icon, this.title, this.description);
  final String id;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey(id),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    decoration: BoxDecoration(
      border: id == 'recommend-poop'
          ? null
          : const Border(bottom: BorderSide(color: Color(0xFFEEE4E0))),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF6E9EC),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: const Color(0xFF94536E), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
