import 'dart:convert';

import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/ibclc_consult.dart';

const _birthPlanDisclaimer = '这份沟通单只用于沟通。请优先遵循医生和医院建议，尤其是因安全原因需要调整计划时。';
const _hospitalBagSubtitle = '住院母婴必备用品 · 32～34周准备 · 36周完成';
const _birthPlanItemLimit = 20;

const _suppressedPersonalizationItemLabels = <String>{
  '检查报告/化验单',
  '医院预登记信息',
  '紧急联系人信息',
  '医生/医院联系电话',
  '手机充电线和充电器',
  '医院路线和停车信息',
  '夜间入口信息',
};
const _suppressedPersonalizationGroupIds = <String>{'support_person_bag'};

AgentSpecializedArtifactView? mapAgentSpecializedCard({
  required AgentArtifactPresentationKind presentationKind,
  required Map<String, Object?> cardJson,
  Map<String, Object?> payload = const <String, Object?>{},
  String artifactId = '',
  String consultIdFallbackArtifactId = '',
}) {
  return switch (presentationKind) {
    AgentArtifactPresentationKind.birthPlanCard => _birthPlanCard(cardJson),
    AgentArtifactPresentationKind.hospitalBagCard => _hospitalBagCard(cardJson),
    AgentArtifactPresentationKind.ibclcConsultCard => _ibclcConsultCard(
      cardJson.isNotEmpty ? cardJson : payload,
      artifactId,
      consultIdFallbackArtifactId,
    ),
    AgentArtifactPresentationKind.motionAssessmentCard => _motionAssessmentCard(
      cardJson.isNotEmpty ? cardJson : payload,
    ),
    _ => null,
  };
}

AgentMotionAssessmentCardView? _motionAssessmentCard(Map<String, Object?> raw) {
  final nestedPayload = _map(raw['payload']);
  final source = <String, Object?>{...nestedPayload, ...raw};
  final entry = _map(source['entry']);
  final privacy = _map(source['privacy']);
  final requestedTarget = _text(source['target']);
  if (requestedTarget != 'forward_head') return null;
  final target = requestedTarget;
  final routeLocation = '/motion-assessment?target=$target';
  return AgentMotionAssessmentCardView(
    title: _text(source['title']).isEmpty ? '人体姿态动态评估' : _text(source['title']),
    target: target,
    userGoal: _nonEmptyText(source['user_goal'] ?? source['userGoal']),
    description: _text(source['description']).isEmpty
        ? '按语音提示调整站位和动作，系统会实时检查取景质量。'
        : _text(source['description']),
    startLabel: _text(entry['label']).isEmpty
        ? '开始动态评估'
        : _text(entry['label']),
    routeLocation: routeLocation,
    videoUploadEnabled:
        privacy['video_upload_enabled'] == true ||
        privacy['videoUploadEnabled'] == true,
    landmarkUploadEnabled:
        privacy['landmark_upload_enabled'] == true ||
        privacy['landmarkUploadEnabled'] == true,
    disclaimer: _text(source['disclaimer']).isEmpty
        ? '结果只反映当前画面，不替代医疗诊断。'
        : _text(source['disclaimer']),
  );
}

AgentIbclcConsultCardView _ibclcConsultCard(
  Map<String, Object?> raw,
  String artifactId,
  String consultIdFallbackArtifactId,
) {
  final nestedPayload = _map(raw['payload']);
  final source = <String, Object?>{...nestedPayload, ...raw};
  final consultant = _map(source['consultant']);
  final chat = _map(source['chat']);
  final explicitConsultId = _firstText(source, const [
    'consult_id',
    'consultId',
  ]);
  final consultId = explicitConsultId.isNotEmpty
      ? explicitConsultId
      : consultIdFallbackArtifactId.trim().isNotEmpty
      ? consultIdFallbackArtifactId.trim()
      : stableIbclcConsultId(jsonEncode(source));
  final rawBio = _text(consultant['bio']);
  final consultantBio = rawBio
      .replaceFirst(RegExp(r'^(?:IBCLC\s*)?国际认证[哺泌]乳顾问[，,、。\s]*'), '')
      .trim();
  return AgentIbclcConsultCardView(
    title: _text(source['title']).isEmpty
        ? 'IBCLC 在线咨询'
        : _text(source['title']),
    consultId: consultId,
    sourceArtifactId: artifactId,
    consultantName: _text(consultant['name']).isEmpty
        ? 'IBCLC 顾问'
        : _text(consultant['name']),
    consultantCredentials: _text(consultant['credentials']).isEmpty
        ? 'IBCLC 国际认证哺乳顾问'
        : _text(consultant['credentials']),
    consultantExperience: _nonEmptyText(consultant['experience']),
    consultantBio: _nullIfEmpty(consultantBio),
    chatLabel: _text(chat['label']).isEmpty ? '咨询 IBCLC' : _text(chat['label']),
    chatNote: _text(chat['note']).isEmpty
        ? '启动咨询后，会自动将你的问题同步给顾问'
        : _text(chat['note']),
    reason: _nonEmptyText(source['reason']),
    feedingContext: _nonEmptyText(
      source['feeding_context'] ?? source['feedingContext'],
    ),
    urgency: _text(source['urgency']).isEmpty
        ? 'routine'
        : _text(source['urgency']),
    preferredLanguage: _nonEmptyText(
      source['preferred_language'] ?? source['preferredLanguage'],
    ),
  );
}

AgentBirthPlanCardView _birthPlanCard(Map<String, Object?> cardJson) {
  final sectionSpecs = <({String id, String title, Object? value})>[
    (
      id: 'communication',
      title: '沟通方式',
      value:
          cardJson['communication'] ??
          cardJson['communication_preferences'] ??
          cardJson['communicationPreferences'],
    ),
    (
      id: 'labor_preferences',
      title: '生产时偏好',
      value: cardJson['labor_preferences'] ?? cardJson['laborPreferences'],
    ),
    (
      id: 'intervention_preferences',
      title: '需要先沟通的操作',
      value:
          cardJson['intervention_preferences'] ??
          cardJson['interventionPreferences'],
    ),
    (
      id: 'pain_relief',
      title: '疼痛缓解',
      value:
          cardJson['pain_relief'] ??
          cardJson['painRelief'] ??
          cardJson['pain_relief_preferences'] ??
          cardJson['painReliefPreferences'],
    ),
    (
      id: 'baby_after_birth',
      title: '宝宝出生后',
      value:
          cardJson['baby_after_birth'] ??
          cardJson['babyAfterBirth'] ??
          cardJson['baby_after_birth_preferences'] ??
          cardJson['babyAfterBirthPreferences'],
    ),
    (
      id: 'if_plans_change',
      title: '计划变化时',
      value: cardJson['if_plans_change'] ?? cardJson['ifPlansChange'],
    ),
    (
      id: 'emergency_authorization',
      title: '紧急情况',
      value:
          cardJson['emergency_authorization'] ??
          cardJson['emergencyAuthorization'],
    ),
    (
      id: 'questions_for_hospital',
      title: '提前问医院',
      value:
          cardJson['questions_for_hospital'] ??
          cardJson['questionsForHospital'],
    ),
  ];
  final sections = <AgentBirthPlanSectionView>[];
  for (final spec in sectionSpecs) {
    final values = _compactBirthPlanList(spec.value);
    if (values.isEmpty) continue;
    sections.add(
      AgentBirthPlanSectionView(id: spec.id, title: spec.title, values: values),
    );
  }
  final title = _normalizeBirthPlanValue(cardJson['title']);
  final disclaimer = _normalizeBirthPlanValue(cardJson['disclaimer']);
  return AgentBirthPlanCardView(
    title: title.isEmpty ? '分娩沟通单' : title,
    sections: List<AgentBirthPlanSectionView>.unmodifiable(sections),
    medicalNotes: _compactBirthPlanList(
      cardJson['medical_notes'] ?? cardJson['medicalNotes'],
      maxItems: 3,
    ),
    disclaimer: disclaimer.isEmpty ? _birthPlanDisclaimer : disclaimer,
  );
}

List<String> _compactBirthPlanList(
  Object? value, {
  int maxItems = _birthPlanItemLimit,
}) {
  final flattened = <Object?>[];

  void flatten(Object? current) {
    if (current is List) {
      for (final item in current) {
        flatten(item);
      }
      return;
    }
    if (current is Map) {
      for (final item in current.values) {
        flatten(item);
      }
      return;
    }
    if (_hasDisplayValue(current)) flattened.add(current);
  }

  flatten(value);
  final seen = <String>{};
  final values = <String>[];
  for (final item in flattened) {
    final normalized = _normalizeBirthPlanValue(item);
    if (normalized.isEmpty ||
        _isConfirmPlaceholder(normalized) ||
        !seen.add(normalized)) {
      continue;
    }
    values.add(normalized);
    if (values.length >= maxItems) break;
  }
  return List<String>.unmodifiable(values);
}

String _normalizeBirthPlanValue(Object? value) {
  var text = _formatPlainValue(value)
      .trim()
      .replaceFirst(RegExp(r'^\s*\d+[.)、．]\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
  const labels = <String, String>{
    'birth plan card': '分娩沟通单',
    'labor room communication priority card': '产房沟通重点',
    'vaginal': '顺产',
    'planned_c_section': '剖宫产',
    'c_section': '剖宫产',
    'c-section': '剖宫产',
    'cesarean': '剖宫产',
    '计划剖宫产': '剖宫产',
    '剖腹产': '剖宫产',
    '刨腹产': '剖宫产',
    'skin-to-skin': '出生后尽早肌肤接触',
    'skin to skin': '出生后尽早肌肤接触',
    '我还没想好，请帮我整理成温和版本': '希望医护团队在关键步骤前先解释，并给我一点时间确认。',
  };
  final mapped = labels[text.toLowerCase()] ?? labels[text];
  if (mapped != null) return mapped;
  text = text.replaceAll(
    RegExp('skin-to-skin|skin to skin', caseSensitive: false),
    '出生后尽早肌肤接触',
  );
  return text;
}

AgentHospitalBagCardView _hospitalBagCard(Map<String, Object?> cardJson) {
  final rawGroups = _objectList(
    cardJson['packing_groups'] ?? cardJson['packingGroups'],
  );
  final merged = <String, _MutablePackingGroup>{};
  for (var index = 0; index < rawGroups.length; index++) {
    final group = rawGroups[index];
    final items = _objectList(group['items']);
    if (items.isEmpty) continue;
    final scene = _hospitalBagScene(group, index);
    final existing = merged[scene.id];
    if (existing != null) {
      existing.items.addAll(items);
      if (scene.order < existing.order) existing.order = scene.order;
      continue;
    }
    merged[scene.id] = _MutablePackingGroup(
      id: scene.id,
      title: scene.title,
      order: scene.order,
      items: List<Map<String, Object?>>.from(items),
    );
  }
  final sortedGroups = merged.values.toList(growable: false)
    ..sort((left, right) => left.order.compareTo(right.order));
  final groups = <AgentHospitalBagGroupView>[
    for (final group in sortedGroups)
      AgentHospitalBagGroupView(
        id: group.id,
        title: group.title,
        items: List<AgentHospitalBagItemView>.unmodifiable(
          group.items.map((item) => _hospitalBagItem(item, group)),
        ),
      ),
  ];
  final rawTitle = _text(cardJson['title']);
  final title =
      rawTitle.isEmpty ||
          rawTitle == 'Hospital Bag Card' ||
          (rawTitle.contains('待产包') && rawTitle.contains('卡片'))
      ? '待产包'
      : rawTitle;
  return AgentHospitalBagCardView(
    title: title,
    subtitle: _hospitalBagSubtitle,
    groups: List<AgentHospitalBagGroupView>.unmodifiable(groups),
    disclaimer: _nonEmptyText(cardJson['disclaimer']),
  );
}

AgentHospitalBagItemView _hospitalBagItem(
  Map<String, Object?> item,
  _MutablePackingGroup group,
) {
  final rawLabel = _firstText(item, const ['label', 'name', 'title']);
  final label = _normalizedPackingItemLabel(rawLabel, item, group);
  final priority = _nonEmptyText(item['priority']);
  final confirmFirst = priority == 'confirm_first' || priority == '先确认';
  final communicationItem = _isCommunicationPackingItem(item, group);
  final copyRequirement = _inferredCopyRequirement(item, group);
  final quantity = _firstText(item, const ['quantity', 'amount', 'count']);
  final meta = confirmFirst || communicationItem
      ? null
      : _nullIfEmpty(copyRequirement.isNotEmpty ? copyRequirement : quantity);
  final explanation = _nonEmptyText(item['explain']);
  final inferredExplanation = _inferredHospitalBagItemExplanation(rawLabel);
  final note = confirmFirst || rawLabel.contains('身份证件')
      ? null
      : _nonEmptyText(item['note']);
  final description =
      explanation ??
      inferredExplanation ??
      note ??
      _nonEmptyText(item['reason']) ??
      _nonEmptyText(item['description']);
  return AgentHospitalBagItemView(
    label: label.isEmpty ? '物品' : label,
    meta: meta,
    priority: priority,
    priorityLabel: priority == null ? null : _packingPriorityLabel(priority),
    description: description,
    personalization: _packingItemPersonalization(item, group),
  );
}

({String id, String title, int order}) _hospitalBagScene(
  Map<String, Object?> group,
  int fallbackOrder,
) {
  final groupId = _firstText(group, const ['group_id', 'groupId']);
  final title = _text(group['title']);
  final text = '$groupId $title'.toLowerCase();
  if (RegExp(r'documents|certificate|证件|资料|文件').hasMatch(text)) {
    return (id: 'documents', title: '证件文件包', order: 0);
  }
  if (RegExp(r'baby|宝宝|新生儿').hasMatch(text)) {
    return (id: 'baby_discharge_bag', title: '宝宝出院包', order: 2);
  }
  if (RegExp(r'support|partner|companion|陪产|支持人').hasMatch(text)) {
    return (id: 'support_person_bag', title: '陪产人包', order: 3);
  }
  if (RegExp(r'car|travel|traffic|transport|车上|交通|停车|路线').hasMatch(text)) {
    return (id: 'car_backup_bag', title: '车上备用包', order: 4);
  }
  if (RegExp(
    r'lactation|breastfeeding|feeding|postpartum|哺乳|喂养|产后回家|产后护理',
  ).hasMatch(text)) {
    return (id: 'postpartum_home_first_week', title: '产后回家第一周用品', order: 5);
  }
  if (RegExp(
    r'mom|mother|communication|food|妈妈|衣物|清洁|护理|通讯|饮食|住院',
  ).hasMatch(text)) {
    return (id: 'mom_hospital_bag', title: '妈妈住院包', order: 1);
  }
  final id = groupId.isEmpty ? 'custom_$fallbackOrder' : groupId;
  return (
    id: id,
    title: title.isEmpty ? _formatLabel(id.isEmpty ? 'Group' : id) : title,
    order: 20 + fallbackOrder,
  );
}

String _normalizedPackingItemLabel(
  String rawLabel,
  Map<String, Object?> item,
  _MutablePackingGroup group,
) {
  if (!_isDocumentPackingItem(item, group)) return rawLabel;
  return rawLabel
      .replaceAll('及复印件', '')
      .replaceAll('和复印件', '')
      .replaceAll('/复印件', '')
      .trim();
}

String _inferredCopyRequirement(
  Map<String, Object?> item,
  _MutablePackingGroup group,
) {
  if (!_isDocumentPackingItem(item, group)) return '';
  final explicit = _firstText(item, const [
    'copy_requirement',
    'copyRequirement',
  ]);
  if (explicit.isNotEmpty) return explicit;
  final label = _text(item['label']);
  final quantity = _text(item['quantity']);
  if (label.contains('复印件')) {
    return _text(item['priority']) == 'confirm_first' ||
            quantity.contains('按医院')
        ? '按医院要求确认'
        : '原件+复印件';
  }
  if (RegExp(r'身份证|医保|产检').hasMatch(label)) return '原件';
  return '';
}

bool _isDocumentPackingItem(
  Map<String, Object?> item,
  _MutablePackingGroup group,
) {
  return _itemBelongsToGroup(item, group, const [
    'documents',
    'certificate',
    '证件',
    '资料',
    '身份证',
    '医保',
    '产检',
    '准生证',
    '户口本',
  ]);
}

bool _isCommunicationPackingItem(
  Map<String, Object?> item,
  _MutablePackingGroup group,
) {
  final label = _text(item['label']);
  if (RegExp(r'吸管杯|水杯|餐具|纸杯').hasMatch(label)) return false;
  return _itemBelongsToGroup(item, group, const [
    'communication',
    '通讯',
    '随身',
    '手机',
    '充电',
    '耳机',
    'power bank',
  ]);
}

bool _itemBelongsToGroup(
  Map<String, Object?> item,
  _MutablePackingGroup group,
  List<String> tokens,
) {
  final text = '${group.id} ${group.title} ${_text(item['label'])}'
      .toLowerCase();
  return tokens.any(text.contains);
}

String? _packingItemPersonalization(
  Map<String, Object?> item,
  _MutablePackingGroup group,
) {
  final label = _text(item['label']);
  if (_suppressedPersonalizationGroupIds.contains(group.id) ||
      _suppressedPersonalizationItemLabels.contains(label)) {
    return null;
  }
  final sources = _objectList(
    item['personalized_by'] ?? item['personalizedBy'],
  );
  final clauses = <_PersonalizationClause>[];
  final seen = <String>{};
  for (final source in sources) {
    final clause = _personalizationClause(source);
    if (clause == null || !seen.add('${clause.external}:${clause.text}')) {
      continue;
    }
    clauses.add(clause);
    if (clauses.length >= 4) break;
  }
  if (clauses.isEmpty) return null;
  final userClauses = clauses
      .where((clause) => !clause.external)
      .map((clause) => clause.text)
      .toList(growable: false);
  final externalClauses = clauses
      .where((clause) => clause.external)
      .map((clause) => clause.text)
      .toList(growable: false);
  final reasonParts = <String>[
    if (userClauses.isNotEmpty) '你${userClauses.join('加上')}',
    if (externalClauses.isNotEmpty) externalClauses.join('，'),
  ];
  final reason = reasonParts.join('，且');
  if (reason.isEmpty) return null;
  final effects = sources.map((source) => _text(source['effect']));
  final priority = _text(item['priority']);
  if (priority == 'confirm_first') return '$reason，建议准备';
  if (effects.any((effect) => effect.contains('数量调整'))) {
    return '$reason，数量已按这个情况调整';
  }
  if (effects.any((effect) => effect.contains('降级') || effect.contains('暂缓'))) {
    return '$reason，可以按需准备';
  }
  return '$reason，${priority == 'must' ? '必须准备' : '建议准备'}';
}

_PersonalizationClause? _personalizationClause(Map<String, Object?> source) {
  final field = _text(source['field']);
  final fieldLabel = _firstText(source, const ['field_label', 'fieldLabel']);
  final effectiveLabel = fieldLabel.isEmpty ? _formatLabel(field) : fieldLabel;
  final condition = _text(source['condition']);
  if (condition.isEmpty || _isConfirmPlaceholder(condition)) return null;
  if (field == 'first_birth' || effectiveLabel == '是否第一胎') {
    if (condition == '是') return const _PersonalizationClause('是第一胎');
    if (condition == '否') return const _PersonalizationClause('不是第一胎');
  }
  if (field == 'birth_path' || effectiveLabel == '分娩方式') {
    if (condition.contains('剖')) return const _PersonalizationClause('是剖宫产');
    if (condition.contains('顺')) return const _PersonalizationClause('计划顺产');
    return _PersonalizationClause('分娩方式是$condition');
  }
  if (field == 'feeding_intention' || effectiveLabel == '喂养意向') {
    if (condition.contains('母乳')) {
      return const _PersonalizationClause('希望母乳喂养');
    }
    if (condition.contains('混合')) {
      return const _PersonalizationClause('计划混合喂养');
    }
    if (condition.contains('配方')) {
      return const _PersonalizationClause('计划配方喂养');
    }
    if (condition.contains('泵')) return const _PersonalizationClause('计划泵奶喂养');
    return const _PersonalizationClause('还没确定喂养方式');
  }
  if (field == 'fetus_count' || effectiveLabel == '胎数') {
    if (condition.contains('双胎')) return const _PersonalizationClause('是双胎');
    if (condition.contains('三胎')) return const _PersonalizationClause('是三胎及以上');
    if (condition.contains('单胎')) return const _PersonalizationClause('是单胎');
  }
  if (field == 'return_to_work_timing' || effectiveLabel == '返工时间') {
    return _PersonalizationClause(_returnToWorkClause(condition));
  }
  if (field == 'budget_preference' || effectiveLabel == '预算偏好') {
    return _PersonalizationClause('偏好$condition');
  }
  if (field == 'support_person' || effectiveLabel == '支持情况') {
    return _PersonalizationClause(
      condition.contains('支持少') ? '产后支持较少' : '产后支持情况是$condition',
    );
  }
  if (field == 'top_worries' || effectiveLabel == '焦虑点') {
    return _PersonalizationClause(_worryClause(condition));
  }
  if (field == 'pregnancy_history_or_notes' || effectiveLabel == '医生提示') {
    return _PersonalizationClause(
      condition == '已填写医生提示' ? '医生有特别提示' : '医生提示$condition',
      external: true,
    );
  }
  if (field == 'due_date_or_week' || effectiveLabel == '孕周/预产期') {
    return _PersonalizationClause(
      condition.endsWith('版') ? '处于$condition' : '当前是$condition',
    );
  }
  if (effectiveLabel.isEmpty) return null;
  return _PersonalizationClause('$effectiveLabel是$condition');
}

String _returnToWorkClause(String condition) {
  if (condition.contains('暂不') || condition.contains('不返工')) return '暂不返工';
  return condition.startsWith('产后') ? '$condition返工' : '产后$condition返工';
}

String _worryClause(String condition) {
  if (condition.startsWith('怕')) return '担心${condition.substring(1)}';
  return condition.startsWith('担心') ? condition : '担心$condition';
}

String? _inferredHospitalBagItemExplanation(String label) {
  const rules = <(String, String)>[
    ('产褥垫|产妇卫生巾', '产后恶露量较多，用来垫床或替代普通卫生巾。'),
    ('胎监带', '做胎心监护时固定探头用，有些医院要求自带。'),
    ('吸管杯', '产后或宫缩时不方便起身，躺着喝水更省力。'),
    ('哺乳文胸|哺乳背心', '方便产后喂奶，也比普通内衣更不勒。'),
    ('防溢乳垫', '放在内衣里吸收漏奶，避免衣服被打湿。'),
    ('便携式吸奶器|吸奶器', '涨奶、排奶或回家后储奶时备用。'),
    ('储奶袋|储奶瓶', '用来保存挤出的母乳，住院期少量准备即可。'),
    ('乳头霜', '哺乳初期乳头干痛时可用，先少量准备。'),
    ('乳盾', '套在乳头上的辅助亲喂用品，是否需要先听专业建议。'),
    ('哺乳枕', '喂奶时托住宝宝和手臂，不是必须。'),
    ('收腹带', '产后腹部支撑用品，剖宫产尤其要先问医生。'),
    ('安全提篮|安全座椅', '宝宝出院坐车时使用，提前确认交通方式。'),
    ('奶瓶清洁用品', '用来清洗奶瓶、奶嘴或吸奶配件，住院只需少量。'),
    ('消毒设备', '回家后消毒奶瓶或吸奶配件用，住院不一定带大件。'),
    ('喂养记录工具', '记录吃奶、排尿排便和睡眠，方便家人同步。'),
    ('分娩沟通[单卡]', '记录生产偏好和需要提前沟通的事，入院时方便给医护看。'),
  ];
  for (final rule in rules) {
    if (RegExp(rule.$1).hasMatch(label)) return rule.$2;
  }
  return null;
}

String _packingPriorityLabel(String priority) {
  return const <String, String>{
        'must': '必带',
        'recommended': '建议',
        'nice_to_have': '建议',
        'confirm_first': '和医院确认',
        '先确认': '和医院确认',
      }[priority] ??
      _formatLabel(priority);
}

List<Map<String, Object?>> _objectList(Object? value) {
  if (value is! List) return const <Map<String, Object?>>[];
  return [
    for (final item in value)
      if (item is Map) Map<String, Object?>.from(item),
  ];
}

Map<String, Object?> _map(Object? value) {
  return value is Map
      ? Map<String, Object?>.from(value)
      : const <String, Object?>{};
}

String _firstText(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _text(map[key]);
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _formatPlainValue(Object? value) {
  if (value is List) return value.map(_formatPlainValue).join(', ');
  if (value is Map) return jsonEncode(value);
  return value?.toString() ?? '';
}

String _formatLabel(String value) {
  return value
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => part.isEmpty
            ? part
            : '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

bool _hasDisplayValue(Object? value) {
  if (value == null || value == '') return false;
  if (value is List) return value.isNotEmpty;
  if (value is Map) return value.isNotEmpty;
  return true;
}

bool _isConfirmPlaceholder(Object? value) {
  final normalized = _text(value).toLowerCase();
  return const <String>{
    '',
    'to confirm',
    '待确认',
    '未确定',
    '不确定',
    '还不确定',
    '还没确定',
    '还没想好',
    'none',
    'n/a',
  }.contains(normalized);
}

String _text(Object? value) => value is String ? value.trim() : '';

String? _nonEmptyText(Object? value) => _nullIfEmpty(_text(value));

String? _nullIfEmpty(String value) => value.isEmpty ? null : value;

class _MutablePackingGroup {
  _MutablePackingGroup({
    required this.id,
    required this.title,
    required this.order,
    required this.items,
  });

  final String id;
  final String title;
  int order;
  final List<Map<String, Object?>> items;
}

class _PersonalizationClause {
  const _PersonalizationClause(this.text, {this.external = false});

  final String text;
  final bool external;
}
