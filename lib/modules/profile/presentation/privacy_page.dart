import 'dart:async';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../../../domain/care/care_episode.dart';
import '../../../domain/care/care_order.dart';
import '../../../domain/care/intake.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
import '../../services/application/care_overview_controller.dart';
import '../application/privacy_controller.dart';

const privacyScopeCopy =
    <CareConsentScope, ({String title, String description, String impact})>{
      CareConsentScope.ibclcCase: (
        title: '提供给本次服务的 IBCLC',
        description: '仅允许被分配的 IBCLC 查看本次信息采集表和授权记录。',
        impact: '关闭后，无法继续查看本次表单或进入本次咨询；已查看或依法保留的记录不会删除。',
      ),
      CareConsentScope.video: (
        title: '进入视频咨询',
        description: '用于进入已预约的视频房间；默认不录音、不录像。',
        impact: '关闭后，无法再次进入本次视频咨询。',
      ),
      CareConsentScope.aiContext: (
        title: '让 Cozymate 使用已选记录',
        description: '在本次服务授权的范围内衔接对话上下文。',
        impact: '关闭后仍可使用通用对话，已有记录不会删除。',
      ),
      CareConsentScope.notifications: (
        title: '接收服务提醒',
        description: '用于本次服务的预约、任务与跟进提醒。',
        impact: '关闭后不再发送这类主动提醒，仍可在 App 内查看安排。',
      ),
    };

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({
    super.key,
    required this.care,
    required this.consents,
    required this.onBack,
    required this.onNotifications,
    this.initialEpisodeId,
  });
  final CareRepository care;
  final IntakeRepository consents;
  final VoidCallback onBack;
  final VoidCallback onNotifications;
  final String? initialEpisodeId;
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  late final overview = CareOverviewController(widget.care);
  PrivacyController? _consent;
  String? _selected;
  int _pickerRevision = 0;
  bool _allowPop = false, _requestedMissing = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await overview.load();
    if (!mounted || overview.overview == null) return;
    final episodes = overview.overview!.episodes;
    if (_selected == null &&
        widget.initialEpisodeId != null &&
        !episodes.any((e) => e.id == widget.initialEpisodeId)) {
      setState(() => _requestedMissing = true);
      return;
    }

    if (_requestedMissing) setState(() => _requestedMissing = false);
    final id =
        episodes
            .where((e) => e.id == (_selected ?? widget.initialEpisodeId))
            .firstOrNull
            ?.id ??
        episodes.firstOrNull?.id;
    if (id != null && _consent == null) await _select(id);
  }

  Future<void> _select(String id) async {
    if (_consent?.busy == true) return;
    if ((_consent?.dirty == true || _consent?.uncertain == true) &&
        !await _discard()) {
      if (mounted) setState(() => _pickerRevision++);
      return;
    }
    if (!mounted) return;
    _consent?.dispose();
    final c = PrivacyController(repository: widget.consents, episodeId: id);
    setState(() {
      _selected = id;
      _consent = c;
    });
    await c.load();
  }

  Future<bool> _discard() async =>
      await showDialog<bool>(
        context: context,
        animationStyle: MomCozyMotion.animationStyle(context),
        builder: (context) => MomSettingsDialog(
          closeLabel: '关闭',
          title: '离开授权设置？',
          onCancel: () => Navigator.pop(context, false),
          cancelLabel: '继续查看',
          content: Text(
            _consent?.uncertain == true
                ? '保存结果还未确认。再次进入时请重新读取授权状态。'
                : '尚未保存的授权更改会被放弃。',
          ),
          primaryAction: FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('放弃并离开'),
          ),
        ),
      ) ??
      false;
  Future<void> _back() async {
    if (_consent?.busy == true) return;
    if ((_consent?.dirty == true || _consent?.uncertain == true) &&
        !await _discard()) {
      return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onBack();
    });
  }

  Future<void> _save() async {
    final c = _consent!;
    if (c.revokedRequired.isNotEmpty && !c.uncertain) {
      final confirmed = await showDialog<bool>(
        context: context,
        animationStyle: MomCozyMotion.animationStyle(context),
        builder: (context) => MomSettingsDialog(
          closeLabel: '关闭',
          title: '确认关闭服务授权？',
          onCancel: () => Navigator.pop(context, false),
          cancelLabel: '继续保留',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              const Text(
                '关闭后，将停止后续表单查看或视频入场。正在进行的本次视频连接也可能结束。已经查看或依法需要保留的服务记录不会被删除。',
              ),
              for (final s in c.revokedRequired)
                Text('• ${privacyScopeCopy[s]!.title}'),
            ],
          ),
          primaryAction: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MomCozyColors.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认关闭'),
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await c.save();
  }

  @override
  void dispose() {
    _consent?.dispose();
    overview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: momSettingsTheme(Theme.of(context)),
    child: AnimatedBuilder(
      animation: Listenable.merge([overview, ?_consent]),
      builder: (context, _) {
        final c = _consent;
        return PopScope(
          canPop:
              _allowPop ||
              (c?.busy != true && c?.dirty != true && c?.uncertain != true),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_back());
          },
          child: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: MomHomeTokens.gap,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: c?.busy == true ? null : _back,
                        child: const Text('返回'),
                      ),
                    ),
                    Text(
                      '隐私与数据',
                      style: MomHomeTokens.text(22, weight: FontWeight.w700),
                    ),
                    const _Paragraph('按用途决定谁可以使用哪些信息。'),
                    MomSettingsCard(
                      gradient: MomHomeTokens.milk,
                      children: [
                        Text(
                          '账号记录',
                          style: MomHomeTokens.text(
                            16,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const _Paragraph('你主动填写的档案与妈妈、宝宝记录保存在当前账号下。'),
                        Text(
                          '保存我的记录',
                          style: MomHomeTokens.text(
                            13,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const _Paragraph('这里的服务授权不会删除账号记录。账号资料可在账号设置中管理。'),
                      ],
                    ),
                    if (overview.failure case final failure?)
                      ProductErrorView(failure: failure, onRetry: _load)
                    else if (overview.overview == null)
                      const _Loading()
                    else if (_requestedMissing)
                      const _Empty('未找到这个服务的授权', '请返回原服务页面重新进入。')
                    else if (overview.overview!.episodes.isEmpty)
                      const _Empty('暂无需要管理授权的服务', '购买服务后，可以在这里按服务查看与调整授权。')
                    else ...[
                      DropdownButtonFormField<String>(
                        initialValue: _selected,
                        key: ValueKey('$_selected:$_pickerRevision'),
                        isExpanded: true,
                        itemHeight: null,
                        dropdownColor: MomHomeTokens.surface,
                        borderRadius: BorderRadius.circular(16),
                        decoration: const InputDecoration(labelText: '选择服务'),
                        items: [
                          for (final e in overview.overview!.episodes)
                            DropdownMenuItem(
                              value: e.id,
                              child: Text(
                                _episodeLabel(e),
                                style: MomHomeTokens.text(13),
                              ),
                            ),
                        ],
                        onChanged: c?.busy == true || c?.uncertain == true
                            ? null
                            : (id) {
                                if (id != null) unawaited(_select(id));
                              },
                      ),
                      const _Paragraph('以下更改只作用于所选服务。各项授权单独保存，不会自动更改其他服务。'),
                      if (c == null || c.loading)
                        const _Loading()
                      else if (c.draft.isEmpty && c.failure != null)
                        ProductErrorView(failure: c.failure!, onRetry: c.load)
                      else ...[
                        const _Heading('服务所需', '提供专家支持和视频入场所需的授权。关闭不会删除历史记录。'),
                        ..._scopes(c, [
                          CareConsentScope.ibclcCase,
                          CareConsentScope.video,
                        ]),
                        const _Heading('按需开启', '不影响 App 的基础记录，可以随时调整。'),
                        ..._scopes(c, [
                          CareConsentScope.aiContext,
                          CareConsentScope.notifications,
                        ]),
                        if (c.failure != null) ...[
                          ProductErrorView(
                            failure: c.failure!,
                            onRetry: c.uncertain ? _save : c.load,
                          ),
                          if (c.uncertain)
                            const _Paragraph(
                              '保存结果尚未确认。重试会继续同一次更改；重新读取会放弃未确认的草稿，以服务器状态为准。',
                            ),
                          TextButton(
                            onPressed: c.busy ? null : c.load,
                            child: const Text('重新读取授权'),
                          ),
                        ],
                        if (c.saved)
                          Semantics(
                            liveRegion: true,
                            child: MomSettingsCard(
                              color: MomHomeTokens.mint,
                              children: [
                                Text(
                                  '隐私设置已保存',
                                  style: MomHomeTokens.text(
                                    13,
                                    color: MomHomeTokens.teal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (c.dirty || c.uncertain)
                          FilledButton(
                            onPressed: c.busy || c.needsReload ? null : _save,
                            child: Text(
                              c.busy
                                  ? '正在保存…'
                                  : c.uncertain
                                  ? '重试保存'
                                  : '保存更改',
                            ),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
  String _episodeLabel(CareEpisode e) {
    final name =
        overview.catalog?.packages
            .where((p) => p.id == e.packageId)
            .firstOrNull
            ?.name ??
        '专家支持服务';
    final date = e.startsAt?.toLocal();
    return '$name${date == null ? '' : ' · ${date.year}/${date.month}/${date.day}'}';
  }

  List<Widget> _scopes(PrivacyController c, List<CareConsentScope> scopes) => [
    for (final scope in scopes)
      if (scope == CareConsentScope.notifications)
        MomSettingsCard(
          children: [
            Text(
              '接收服务提醒',
              style: MomHomeTokens.text(16, weight: FontWeight.w700),
            ),
            const _Paragraph('预约、任务与跟进提醒在通知设置中统一管理。'),
            TextButton(
              onPressed: c.busy ? null : widget.onNotifications,
              child: const Text('管理通知与提醒'),
            ),
          ],
        )
      else
        _ScopeRow(
          scope: scope,
          value: c.draft[scope] ?? false,
          enabled: c.canEdit,
          onChanged: (v) => c.toggle(scope, v),
        ),
  ];
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: MomHomeTokens.text(12, color: MomHomeTokens.secondary, height: 1.55),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.description);
  final String title, description;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 6,
    children: [
      Text(title, style: MomHomeTokens.text(18, weight: FontWeight.w700)),
      _Paragraph(description),
    ],
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.title, this.description);
  final String title, description;
  @override
  Widget build(BuildContext context) => MomSettingsCard(
    children: [
      Text(title, style: MomHomeTokens.text(16, weight: FontWeight.w700)),
      _Paragraph(description),
    ],
  );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => MomSettingsCard(
    children: [
      Text('正在加载…', style: MomHomeTokens.text(16, weight: FontWeight.w700)),
      const LinearProgressIndicator(),
    ],
  );
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({
    required this.scope,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final CareConsentScope scope;
  final bool value, enabled;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final copy = privacyScopeCopy[scope]!;
    final title = Text(
      copy.title,
      style: MomHomeTokens.text(16, weight: FontWeight.w700),
    );
    final control = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: copy.title,
          child: Switch(
            key: ValueKey(scope),
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ),
        Text(
          enabled ? (value ? '已开启' : '已关闭') : '暂不可更改',
          style: MomHomeTokens.text(10, color: MomHomeTokens.secondary),
        ),
      ],
    );
    return MomSettingsCard(
      children: [
        MediaQuery.textScalerOf(context).scale(1) > 1.4
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 14,
                children: [
                  title,
                  Align(alignment: Alignment.centerRight, child: control),
                ],
              )
            : Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 14),
                  control,
                ],
              ),
        _Paragraph(copy.description),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MomHomeTokens.neutralSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            copy.impact,
            style: MomHomeTokens.text(
              11,
              color: MomHomeTokens.secondary,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}
