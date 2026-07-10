import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';

class AgentArtifactMapper {
  const AgentArtifactMapper._();

  static List<AgentArtifactCardView> cardsFromEvents(
    Iterable<AgentStreamEvent> events,
  ) {
    final cards = <String, AgentArtifactCardView>{};
    for (final event in events) {
      final card = cardFromEvent(event);
      if (card != null) cards[card.id] = card;
    }
    return List<AgentArtifactCardView>.unmodifiable(cards.values);
  }

  static AgentArtifactCardView? cardFromEvent(AgentStreamEvent event) {
    if (event.type != 'artifact.created' && event.type != 'artifact.updated') {
      return null;
    }

    final payload = event.payload;
    final artifact = _firstMap([
      _mapField(event.raw, 'artifact'),
      _mapField(payload, 'artifact'),
    ]);
    final artifactPayload = _mapField(artifact, 'payload');
    final effectivePayload = artifactPayload.isNotEmpty
        ? artifactPayload
        : payload;
    final richText = _firstMap([
      _mapField(event.raw, 'rich_text', 'richText'),
      _mapField(payload, 'rich_text', 'richText'),
      _mapField(artifactPayload, 'rich_text', 'richText'),
    ]);
    final cardEnvelope = _firstMap([
      _mapField(artifactPayload, 'card'),
      _mapField(payload, 'card'),
      _mapField(artifact, 'card'),
    ]);
    final form = _firstMap([
      _mapField(artifactPayload, 'form'),
      _mapField(payload, 'form'),
      _mapField(artifact, 'form'),
    ]);
    final cartUpdate = _firstMap([
      _mapField(artifactPayload, 'cart_update', 'cartUpdate'),
      _mapField(payload, 'cart_update', 'cartUpdate'),
    ]);
    final assistantFollowup = _firstMap([
      _mapField(artifactPayload, 'assistant_followup', 'assistantFollowup'),
      _mapField(payload, 'assistant_followup', 'assistantFollowup'),
    ]);
    final artifactId = _firstNonEmpty([
      _stringField(event.raw, 'artifact_id', 'artifactId'),
      _stringField(payload, 'artifact_id', 'artifactId'),
      _stringField(artifact, 'id'),
      event.artifactId,
      event.mergeKey,
    ])!;
    final artifactType = _firstNonEmpty([
      _stringField(event.raw, 'artifact_type', 'artifactType'),
      _stringField(payload, 'artifact_type', 'artifactType'),
      _stringField(artifact, 'artifact_type', 'artifactType'),
    ]);
    final schemaVersion =
        _firstNonEmpty([
          _stringField(event.raw, 'schema_version', 'schemaVersion'),
          _stringField(payload, 'schema_version', 'schemaVersion'),
          _stringField(artifact, 'schema_version', 'schemaVersion'),
          _stringField(cardEnvelope, 'schema_version', 'schemaVersion'),
          _stringField(form, 'schema_version', 'schemaVersion'),
        ]) ??
        'v1';
    final rawCardJson = _firstMap([
      _mapField(artifact, 'card_json', 'cardJson'),
      _mapField(artifactPayload, 'card_json', 'cardJson'),
      _mapField(payload, 'card_json', 'cardJson'),
      _mapField(cardEnvelope, 'card_json', 'cardJson'),
    ]);
    final cardJson = rawCardJson.isNotEmpty
        ? rawCardJson
        : _directCardPayload(artifactType, effectivePayload);
    final cardType = _firstNonEmpty([
      _stringField(cardEnvelope, 'card_type', 'cardType'),
      _stringField(cardJson, 'card_type', 'cardType'),
    ]);
    final presentationKind = _presentationKind(
      artifactType: artifactType,
      cardType: cardType,
      schemaVersion: schemaVersion,
      cardJson: cardJson,
      hasForm: form.isNotEmpty,
      hasCartUpdate: cartUpdate.isNotEmpty,
    );
    final explicitTitle = _firstNonEmpty([
      _stringField(richText, 'title'),
      _stringField(form, 'title'),
      _stringField(cardJson, 'title'),
      _stringField(effectivePayload, 'title'),
      _stringField(payload, 'title'),
    ]);
    final content = _firstNonEmpty([
      _stringField(richText, 'content'),
      _stringField(effectivePayload, 'content'),
      _stringField(effectivePayload, 'summary'),
      _stringField(payload, 'content'),
      _stringField(payload, 'summary'),
      _stringField(assistantFollowup, 'message'),
    ]);
    final status = _firstNonEmpty([
      _stringField(cardJson, 'status_label', 'statusLabel'),
      _stringField(effectivePayload, 'status_label', 'statusLabel'),
      _stringField(payload, 'status_label', 'statusLabel'),
    ]);
    final formFields = _formFields(form);
    final rows = <String>[
      ..._cardJsonRows(cardJson),
      ..._cartUpdateRows(cartUpdate),
      ..._stringList(cardJson['steps']),
      ..._stringList(effectivePayload['steps']),
      ..._richTextCardRows(richText['card']),
    ];
    final actions = <AgentArtifactActionView>[
      ..._buttonActions(richText['button']),
      ..._referenceActionsFromRichText(richText),
      ..._semanticActions(richText['action'], event),
      ..._semanticActions(payload['actions'], event),
      ..._assistantFollowupActions(assistantFollowup),
    ];

    if (explicitTitle == null &&
        formFields.isEmpty &&
        (content == null || content.trim().isEmpty) &&
        rows.isEmpty &&
        actions.isEmpty) {
      return null;
    }

    return AgentArtifactCardView(
      id: artifactId,
      title: explicitTitle ?? _artifactSubject(artifactType),
      artifactType: artifactType,
      schemaVersion: schemaVersion,
      presentationKind: presentationKind,
      cardType: cardType,
      payload: Map<String, Object?>.unmodifiable(effectivePayload),
      cardJson: Map<String, Object?>.unmodifiable(cardJson),
      rawCard: Map<String, Object?>.unmodifiable(cardEnvelope),
      content: content,
      description: _stringField(form, 'description'),
      statusLabel: status,
      rows: List<String>.unmodifiable(rows),
      formId: _stringField(form, 'id'),
      formSubmitLabel: _stringField(form, 'submit_label', 'submitLabel'),
      formFields: formFields,
      actions: List<AgentArtifactActionView>.unmodifiable(actions),
    );
  }
}

AgentArtifactPresentationKind _presentationKind({
  required String? artifactType,
  required String? cardType,
  required String schemaVersion,
  required Map<String, Object?> cardJson,
  required bool hasForm,
  required bool hasCartUpdate,
}) {
  if (!_isSupportedSchemaVersion(schemaVersion)) {
    return AgentArtifactPresentationKind.unsupported;
  }
  if (hasForm || artifactType == 'form') {
    return AgentArtifactPresentationKind.form;
  }
  if (hasCartUpdate || artifactType == 'hospital_bag_cart') {
    return AgentArtifactPresentationKind.hospitalBagCart;
  }
  return switch (cardType ?? artifactType) {
    'milk_analysis_card'
        when cardJson.containsKey('sections') ||
            cardJson.containsKey('headline') =>
      AgentArtifactPresentationKind.milkAnalysisCard,
    'milk_plan_card'
        when cardJson.containsKey('sections') ||
            cardJson.containsKey('headline') =>
      AgentArtifactPresentationKind.milkPlanCard,
    'milk_plan_preview' => AgentArtifactPresentationKind.milkPlanPreview,
    'birth_journey_plan_card'
        when cardJson.containsKey('todo_plan') ||
            cardJson.containsKey('todoPlan') ||
            cardJson.containsKey('owner') =>
      AgentArtifactPresentationKind.birthJourneyPlanCard,
    'birth_plan_card'
        when cardJson.containsKey('communication') ||
            cardJson.containsKey('pain_relief') ||
            cardJson.containsKey('painRelief') ||
            cardJson.containsKey('medical_notes') ||
            cardJson.containsKey('medicalNotes') =>
      AgentArtifactPresentationKind.birthPlanCard,
    'hospital_bag_card'
        when cardJson.containsKey('packing_groups') ||
            cardJson.containsKey('packingGroups') =>
      AgentArtifactPresentationKind.hospitalBagCard,
    'ibclc_consult_card' => AgentArtifactPresentationKind.ibclcConsultCard,
    'rich_text' => AgentArtifactPresentationKind.richText,
    _ => AgentArtifactPresentationKind.generic,
  };
}

bool _isSupportedSchemaVersion(String version) {
  final normalized = version.trim().toLowerCase();
  return normalized == '1' ||
      normalized == '1.0' ||
      normalized == 'v1' ||
      normalized == 'v1.0';
}

Map<String, Object?> _directCardPayload(
  String? artifactType,
  Map<String, Object?> payload,
) {
  return switch (artifactType) {
    'milk_analysis_card' ||
    'milk_plan_card' ||
    'birth_journey_plan_card' ||
    'birth_plan_card' ||
    'hospital_bag_card' => payload,
    _ => const <String, Object?>{},
  };
}

List<AgentArtifactFormFieldView> _formFields(Map<String, Object?> form) {
  final fields = form['fields'];
  if (fields is! List) return const <AgentArtifactFormFieldView>[];
  final defaultValues = _mapField(form, 'default_values', 'defaultValues');
  final views = <AgentArtifactFormFieldView>[];
  for (final rawField in fields.take(48)) {
    if (rawField is! Map) continue;
    final field = Map<String, Object?>.from(rawField);
    final id = _stringField(field, 'id')?.trim();
    final label = _stringField(field, 'label')?.trim();
    if (id == null || id.isEmpty || label == null || label.isEmpty) continue;
    views.add(
      AgentArtifactFormFieldView(
        id: id,
        label: label,
        type: (_stringField(field, 'type') ?? 'text').trim().toLowerCase(),
        required: field['required'] == true,
        options: _stringList(field['options']),
        placeholder: _stringField(field, 'placeholder'),
        defaultValue:
            field['default_value'] ??
            field['defaultValue'] ??
            defaultValues[id],
        allowOtherInput:
            field['allow_other_input'] == true ||
            field['allowOtherInput'] == true,
        otherPlaceholder: _stringField(
          field,
          'other_placeholder',
          'otherPlaceholder',
        ),
        helpText: _stringField(field, 'help_text', 'helpText'),
      ),
    );
  }
  return List<AgentArtifactFormFieldView>.unmodifiable(views);
}

List<String> _cardJsonRows(Map<String, Object?> cardJson) {
  if (cardJson.isEmpty) return const <String>[];
  final rows = <String>[];
  final owner = _mapField(cardJson, 'owner');
  if (owner.isNotEmpty) {
    final values = owner.entries
        .where((entry) => _displayString(entry.value) != null)
        .take(5)
        .map((entry) => '${entry.key}: ${_displayString(entry.value)}')
        .join('｜');
    if (values.isNotEmpty) rows.add(values);
  }
  rows.addAll(
    _packingGroupRows(cardJson['packing_groups'] ?? cardJson['packingGroups']),
  );
  rows.addAll(_todoPlanRows(cardJson['todo_plan'] ?? cardJson['todoPlan']));
  rows.addAll(_stringList(cardJson['timeline']).take(4));
  rows.addAll(
    _stringList(
      cardJson['personalized_notes'] ?? cardJson['personalizedNotes'],
    ).take(4),
  );
  return rows;
}

List<String> _packingGroupRows(Object? rawGroups) {
  if (rawGroups is! List) return const <String>[];
  final rows = <String>[];
  for (final rawGroup in rawGroups.take(6)) {
    if (rawGroup is! Map) continue;
    final group = Map<String, Object?>.from(rawGroup);
    final title = _stringField(group, 'title');
    final items = group['items'];
    if (title == null || items is! List) continue;
    final labels = items
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .map(
          (item) => _stringField(item, 'label') ?? _stringField(item, 'name'),
        )
        .whereType<String>()
        .take(5)
        .join('、');
    rows.add(labels.isEmpty ? title : '$title：$labels');
  }
  return rows;
}

List<String> _todoPlanRows(Object? rawTodoPlan) {
  if (rawTodoPlan is! Map) return const <String>[];
  final periods = rawTodoPlan['periods'];
  if (periods is! List) return const <String>[];
  final rows = <String>[];
  for (final rawPeriod in periods.take(4)) {
    if (rawPeriod is! Map) continue;
    final period = Map<String, Object?>.from(rawPeriod);
    final title = _stringField(period, 'title') ?? '阶段';
    final items = period['items'];
    if (items is! List) {
      rows.add(title);
      continue;
    }
    final itemTitles = items
        .whereType<Map>()
        .map((item) => _stringField(Map<String, Object?>.from(item), 'title'))
        .whereType<String>()
        .take(4)
        .join('、');
    rows.add(itemTitles.isEmpty ? title : '$title：$itemTitles');
  }
  return rows;
}

List<String> _cartUpdateRows(Map<String, Object?> cartUpdate) {
  if (cartUpdate.isEmpty) return const <String>[];
  final rows = <String>[];
  final message = _stringField(cartUpdate, 'message');
  if (message != null) rows.add(message);
  rows.addAll(_packingGroupRows(cartUpdate['groups']));
  final totals = _mapField(cartUpdate, 'totals');
  if (totals.isNotEmpty) {
    final itemCount = totals['item_count'] ?? totals['itemCount'];
    final total = totals['total'] ?? totals['subtotal'];
    if (itemCount != null || total != null) {
      rows.add('购物车合计：${itemCount ?? '-'} 件｜${total ?? '-'}');
    }
  }
  return rows;
}

List<String> _richTextCardRows(Object? rawCards) {
  if (rawCards is! List) return const <String>[];
  final rows = <String>[];
  for (final rawCard in rawCards) {
    if (rawCard is! Map) continue;
    final card = Map<String, Object?>.from(rawCard);
    final title = _firstNonEmpty([
      _stringField(card, 'title'),
      _stringField(card, 'label'),
    ]);
    if (title != null) rows.add(title);
    final content = card['content'];
    if (content is! List) continue;
    for (final rawRow in content) {
      if (rawRow is! Map) continue;
      final row = Map<String, Object?>.from(rawRow);
      final label = _stringField(row, 'title');
      final value = _stringField(row, 'content', 'value');
      final combined = _combineLabelValue(label, value);
      if (combined != null) rows.add(combined);
    }
  }
  return rows;
}

List<AgentArtifactActionView> _buttonActions(Object? rawButtons) {
  if (rawButtons is! List) return const <AgentArtifactActionView>[];
  return rawButtons
      .whereType<Map>()
      .map((rawButton) {
        final button = Map<String, Object?>.from(rawButton);
        final kind = _firstNonEmpty([
          _stringField(button, 'type', 'kind'),
          _stringField(button, 'action'),
        ]);
        final value = _firstNonEmpty([
          _stringField(button, 'value'),
          _stringField(button, 'url'),
          _stringField(button, 'href'),
          _stringField(button, 'route'),
          _stringField(button, 'path'),
        ]);
        final label =
            _firstNonEmpty([
              _stringField(button, 'text'),
              _stringField(button, 'label'),
              _stringField(button, 'title'),
            ]) ??
            '打开';
        return AgentArtifactActionView(
          label: label,
          icon: _actionIcon(kind),
          kind: kind ?? 'button',
          value: value,
          routePath: _actionRoutePath(kind: kind, value: value),
          routeExtra: _actionRouteExtra(kind: kind, value: value, title: label),
        );
      })
      .toList(growable: false);
}

List<AgentArtifactActionView> _referenceActionsFromRichText(
  Map<String, Object?> richText,
) {
  return [
    ..._referenceActions(richText['citation']),
    ..._referenceActions(richText['citations']),
    ..._referenceActions(richText['reference']),
    ..._referenceActions(richText['references']),
  ];
}

List<AgentArtifactActionView> _referenceActions(Object? rawReferences) {
  final references = switch (rawReferences) {
    List value => value,
    Map value => [value],
    _ => const <Object?>[],
  };
  return references
      .whereType<Map>()
      .map((rawReference) {
        final reference = Map<String, Object?>.from(rawReference);
        final value = _firstNonEmpty([
          _stringField(reference, 'url'),
          _stringField(reference, 'href'),
          _stringField(reference, 'value'),
        ]);
        final title =
            _firstNonEmpty([
              _stringField(reference, 'title'),
              _stringField(reference, 'label'),
              _stringField(reference, 'displayText'),
              _hostFromUrl(value),
            ]) ??
            '参考来源';
        return AgentArtifactActionView(
          label: _citationLabel(reference['index'], title),
          icon: _actionIcon('citation'),
          kind: 'citation',
          value: value,
        );
      })
      .toList(growable: false);
}

List<AgentArtifactActionView> _semanticActions(
  Object? rawActions,
  AgentStreamEvent event,
) {
  if (rawActions is! List) return const <AgentArtifactActionView>[];
  return rawActions
      .whereType<Map>()
      .map((rawAction) => Map<String, Object?>.from(rawAction))
      .where((action) => _stringField(action, 'kind') != 'ag_ui_artifact')
      .map((action) {
        final kind = _stringField(action, 'kind', 'type');
        final value = _firstNonEmpty([
          _stringField(action, 'value'),
          _stringField(action, 'url'),
          _stringField(action, 'href'),
          _stringField(action, 'route'),
          _stringField(action, 'path'),
        ]);
        final label =
            _firstNonEmpty([
              _stringField(action, 'label'),
              _stringField(action, 'text'),
              kind == 'artifact'
                  ? '打开${_artifactSubject(_stringField(event.payload, 'artifact_type', 'artifactType'))}'
                  : null,
            ]) ??
            '打开';
        return AgentArtifactActionView(
          label: label,
          icon: _actionIcon(kind),
          kind: kind ?? 'action',
          value: value,
          routePath: _actionRoutePath(kind: kind, value: value),
          routeExtra: _actionRouteExtra(kind: kind, value: value, title: label),
        );
      })
      .toList(growable: false);
}

List<AgentArtifactActionView> _assistantFollowupActions(
  Map<String, Object?> assistantFollowup,
) {
  final kind = _stringField(assistantFollowup, 'kind');
  final route = _markdownLinkPath(_stringField(assistantFollowup, 'message'));
  if (kind != 'hospital_bag_cart' && route != '/hospital-bag-cart') {
    return const <AgentArtifactActionView>[];
  }
  return [
    AgentArtifactActionView(
      label: '打开待产包购物车',
      icon: _actionIcon('artifact'),
      kind: 'artifact',
      value: route ?? '/hospital-bag-cart',
      routePath: route ?? '/hospital-bag-cart',
    ),
  ];
}

IconData _actionIcon(String? kind) {
  return switch (kind) {
    'doc' || 'document' || 'pdf' => Icons.description_outlined,
    'media' || 'image' || 'video' || 'open' => Icons.open_in_new_rounded,
    'citation' || 'reference' => Icons.link_rounded,
    'artifact' => Icons.fact_check_outlined,
    _ => Icons.touch_app_outlined,
  };
}

String? _actionRoutePath({required String? kind, required String? value}) {
  if (_isMediaActionKind(kind)) return '/media-viewer';
  return _safeSameOriginPath(value);
}

Map<String, Object?>? _actionRouteExtra({
  required String? kind,
  required String? value,
  required String? title,
}) {
  if (!_isMediaActionKind(kind)) return null;
  final url = value?.trim();
  if (url == null || url.isEmpty) return null;
  final mediaKind = _mediaViewerKind(kind: kind, url: url);
  if (mediaKind == null) return null;
  return {
    'kind': mediaKind,
    'url': url,
    if (title?.trim().isNotEmpty ?? false) 'title': title!.trim(),
  };
}

bool _isMediaActionKind(String? kind) {
  return const {
    'doc',
    'document',
    'pdf',
    'media',
    'image',
    'photo',
    'picture',
    'video',
  }.contains(kind);
}

String? _mediaViewerKind({required String? kind, required String url}) {
  final normalizedKind = kind?.trim().toLowerCase();
  if (const {'pdf', 'doc', 'document'}.contains(normalizedKind)) return 'pdf';
  if (const {'image', 'photo', 'picture'}.contains(normalizedKind)) {
    return 'image';
  }
  if (normalizedKind == 'video') return 'video';
  final normalizedUrl = url.toLowerCase().split('?').first;
  if (normalizedUrl.endsWith('.pdf')) return 'pdf';
  if (RegExp(r'\.(png|jpe?g|webp|gif)$').hasMatch(normalizedUrl)) {
    return 'image';
  }
  if (RegExp(r'\.(mp4|mov|webm)$').hasMatch(normalizedUrl)) return 'video';
  return null;
}

String? _safeSameOriginPath(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  final path = uri.path.isEmpty ? normalized : uri.path;
  return path.startsWith('/') ? path : null;
}

String? _markdownLinkPath(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  final match = RegExp(r'\[[^\]]+\]\(([^)]+)\)').firstMatch(normalized);
  return match == null ? null : _safeSameOriginPath(match.group(1));
}

String _citationLabel(Object? rawIndex, String title) {
  final index = switch (rawIndex) {
    int value => value.toString(),
    String value => value.trim(),
    _ => '',
  };
  return index.isEmpty ? title : '[$index] $title';
}

String? _hostFromUrl(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  final host = uri?.host.replaceFirst(RegExp(r'^www\.'), '');
  return host == null || host.isEmpty ? null : host;
}

String _artifactSubject(String? type) {
  return switch (type) {
    'form' => '信息采集',
    'milk_analysis_card' => '奶量分析',
    'milk_plan_card' || 'milk_plan_preview' => '奶量计划',
    'birth_journey_plan_card' => '孕期计划',
    'birth_plan_card' => '分娩计划',
    'hospital_bag_card' || 'hospital_bag_cart' => '待产包',
    'ibclc_consult_card' => 'IBCLC 咨询入口',
    _ => '结果',
  };
}

Map<String, Object?> _firstMap(List<Map<String, Object?>> values) {
  for (final value in values) {
    if (value.isNotEmpty) return value;
  }
  return const <String, Object?>{};
}

Map<String, Object?> _mapField(
  Map<String, Object?> map,
  String key, [
  String? alias,
]) {
  final value = map[key] ?? (alias == null ? null : map[alias]);
  return value is Map
      ? Map<String, Object?>.from(value)
      : const <String, Object?>{};
}

String? _stringField(Map<String, Object?> map, String key, [String? alias]) {
  final value = map[key] ?? (alias == null ? null : map[alias]);
  return value is String ? value : null;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _displayString(Object? value) {
  if (value == null) return null;
  if (value is String) return value.trim().isEmpty ? null : value.trim();
  if (value is num || value is bool) return value.toString();
  return null;
}

String? _combineLabelValue(String? label, String? value) {
  final normalizedLabel = label?.trim();
  final normalizedValue = value?.trim();
  if (normalizedLabel?.isNotEmpty ?? false) {
    return normalizedValue?.isNotEmpty ?? false
        ? '$normalizedLabel: $normalizedValue'
        : normalizedLabel;
  }
  return normalizedValue?.isNotEmpty ?? false ? normalizedValue : null;
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) return normalized;
  }
  return null;
}
