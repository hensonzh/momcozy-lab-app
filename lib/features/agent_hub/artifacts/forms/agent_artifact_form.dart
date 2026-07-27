import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:app/app/momcozy_design_system.dart';
import 'package:app/features/agent_hub/artifacts/agent_artifact_model.dart';

class AgentArtifactForm extends StatefulWidget {
  const AgentArtifactForm({
    super.key,
    required this.card,
    this.onAction,
    this.onSubmit,
    this.submission,
    this.initialDraftValues = const <String, Object?>{},
    this.onDraftChanged,
    this.onSubmitted,
    this.dialogMode = false,
  });

  final AgentArtifactCardView card;
  final ValueChanged<AgentArtifactActionView>? onAction;
  final AgentArtifactFormSubmitHandler? onSubmit;
  final AgentArtifactFormSubmission? submission;
  final Map<String, Object?> initialDraftValues;
  final ValueChanged<Map<String, Object?>>? onDraftChanged;
  final VoidCallback? onSubmitted;
  final bool dialogMode;

  @override
  AgentArtifactFormState createState() => AgentArtifactFormState();
}

enum _AgentArtifactFormPhase { editing, submitting, submitted }

class AgentArtifactFormState extends State<AgentArtifactForm> {
  late Map<String, Object?> _values;
  late Map<String, String> _otherValues;
  final Set<String> _dirtyFieldIds = <String>{};
  int _defaultRevision = 0;
  String? _submitError;
  _AgentArtifactFormPhase _phase = _AgentArtifactFormPhase.editing;

  _AgentArtifactFormPhase get _effectivePhase {
    return switch (widget.submission?.phase) {
      AgentArtifactFormSubmissionPhase.submitting =>
        _AgentArtifactFormPhase.submitting,
      AgentArtifactFormSubmissionPhase.submitted =>
        _AgentArtifactFormPhase.submitted,
      null => _phase,
    };
  }

  bool get _isLocked => _effectivePhase != _AgentArtifactFormPhase.editing;

  bool get _canSubmit => widget.onSubmit != null || widget.onAction != null;

  @override
  void initState() {
    super.initState();
    _resetValues();
  }

  @override
  void didUpdateWidget(covariant AgentArtifactForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id ||
        oldWidget.card.formFields.length != widget.card.formFields.length) {
      _resetValues();
    } else {
      _mergeUpdatedDefaults();
      if (!identical(oldWidget.submission, widget.submission)) {
        _applySubmission(widget.submission);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isCollection = _isCollectionForm(widget.card.formId);
    final groups = _formFieldGroups(widget.card);
    final content = Padding(
      padding: widget.dialogMode
          ? EdgeInsets.zero
          : EdgeInsets.all(isCollection ? 16 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.dialogMode) ...[
            Text(
              widget.card.title,
              style:
                  (isCollection ? textTheme.titleLarge : textTheme.titleMedium)
                      ?.copyWith(
                        color: const Color(0xff171717),
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
            ),
            if (widget.card.description case final description?
                when description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(0xff525252),
                  height: 1.55,
                ),
              ),
            ],
            SizedBox(height: isCollection ? 16 : 12),
          ],
          for (var index = 0; index < groups.length; index++) ...[
            if (groups[index].title.isNotEmpty)
              _ArtifactFormGroup(
                title: groups[index].title,
                tone: _groupTone(
                  formId: widget.card.formId,
                  title: groups[index].title,
                  index: index,
                ),
                compact: widget.dialogMode,
                children: [
                  for (
                    var fieldIndex = 0;
                    fieldIndex < groups[index].fields.length;
                    fieldIndex++
                  ) ...[
                    _buildField(context, groups[index].fields[fieldIndex]),
                    if (fieldIndex < groups[index].fields.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              )
            else
              for (
                var fieldIndex = 0;
                fieldIndex < groups[index].fields.length;
                fieldIndex++
              ) ...[
                _buildField(context, groups[index].fields[fieldIndex]),
                if (fieldIndex < groups[index].fields.length - 1)
                  const SizedBox(height: 12),
              ],
            if (index < groups.length - 1)
              SizedBox(
                height: widget.dialogMode ? 18 : (isCollection ? 16 : 12),
              ),
          ],
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            Text(
              _submitError!,
              key: ValueKey('agent-artifact-form-error-${widget.card.id}'),
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (!widget.dialogMode) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                key: ValueKey('agent-artifact-form-submit-${widget.card.id}'),
                onPressed: !_canSubmit || _isLocked ? null : submit,
                icon: _submitIcon(),
                label: Text(_submitLabel()),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff207d93),
                  disabledBackgroundColor:
                      _effectivePhase == _AgentArtifactFormPhase.submitted
                      ? Colors.white
                      : const Color(0xffd4d4d4),
                  disabledForegroundColor:
                      _effectivePhase == _AgentArtifactFormPhase.submitted
                      ? const Color(0xff55727a)
                      : const Color(0xff737373),
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: _effectivePhase == _AgentArtifactFormPhase.submitted
                        ? const Color(0xff9db7bd)
                        : const Color(0xff207d93),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return KeyedSubtree(
      key: ValueKey('agent-artifact-form-${widget.card.id}'),
      child: widget.dialogMode
          ? content
          : DecoratedBox(
              decoration: BoxDecoration(
                color: isCollection
                    ? const Color(0xfffffdfc)
                    : MomCozyColors.raised,
                borderRadius: BorderRadius.circular(isCollection ? 24 : 12),
                border: Border.all(
                  color: isCollection
                      ? const Color(0xffeadfe5)
                      : MomCozyColors.border,
                ),
                boxShadow: isCollection
                    ? const [
                        BoxShadow(
                          color: Color(0x0f412a34),
                          blurRadius: 30,
                          offset: Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
              child: content,
            ),
    );
  }

  Widget _buildField(BuildContext context, AgentArtifactFormFieldView field) {
    if (field.isMultiSelect) return _buildMultiSelect(context, field);
    if (field.type == 'select') return _buildSelect(context, field);
    if (field.type == 'radio') return _buildRadio(context, field);
    return _buildTextField(context, field);
  }

  Widget _buildTextField(
    BuildContext context,
    AgentArtifactFormFieldView field,
  ) {
    final isTextarea = field.type == 'textarea';
    final isDate = field.type == 'date';
    final isNumber = field.type == 'number';
    return Column(
      key: ValueKey('agent-artifact-form-field-${widget.card.id}-${field.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ArtifactFormFieldLabel(field: field),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey(
            'agent-artifact-form-input-${widget.card.id}-${field.id}-${isDate ? _textValue(field) : ''}-$_defaultRevision',
          ),
          initialValue: _textValue(field),
          readOnly: _isLocked || isDate,
          minLines: isTextarea ? 3 : 1,
          maxLines: isTextarea ? 5 : 1,
          keyboardType: isDate
              ? TextInputType.datetime
              : isNumber
              ? TextInputType.number
              : TextInputType.text,
          decoration: _inputDecoration(
            hintText: field.placeholder ?? (isDate ? '请选择日期' : '请填写'),
            suffixIcon: isDate
                ? const Icon(Icons.calendar_today_outlined, size: 18)
                : null,
          ),
          onTap: isDate && !_isLocked ? () => _pickDate(field) : null,
          onChanged: (value) => _setFieldValue(field.id, value.trim()),
        ),
        _fieldHelpText(context, field),
      ],
    );
  }

  Widget _buildSelect(BuildContext context, AgentArtifactFormFieldView field) {
    final currentValue = _textValue(field);
    final selectedValue = field.options.contains(currentValue)
        ? currentValue
        : null;
    return Column(
      key: ValueKey('agent-artifact-form-field-${widget.card.id}-${field.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ArtifactFormFieldLabel(field: field),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'agent-artifact-form-select-${widget.card.id}-${field.id}-$_defaultRevision',
          ),
          initialValue: selectedValue,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          hint: Text(field.placeholder ?? '请选择'),
          decoration: _inputDecoration(),
          items: [
            for (final option in field.options)
              DropdownMenuItem<String>(value: option, child: Text(option)),
          ],
          onChanged: _isLocked
              ? null
              : (value) => _setFieldValue(field.id, value),
        ),
        _fieldHelpText(context, field),
      ],
    );
  }

  Widget _buildRadio(BuildContext context, AgentArtifactFormFieldView field) {
    return Column(
      key: ValueKey('agent-artifact-form-field-${widget.card.id}-${field.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ArtifactFormFieldLabel(field: field),
        const SizedBox(height: 8),
        for (var index = 0; index < field.options.length; index++) ...[
          _ArtifactFormOptionRow(
            label: field.options[index],
            selected: _values[field.id] == field.options[index],
            enabled: !_isLocked,
            radio: true,
            onTap: () => _setFieldValue(field.id, field.options[index]),
          ),
          if (index < field.options.length - 1) const SizedBox(height: 8),
        ],
        _fieldHelpText(context, field),
      ],
    );
  }

  Widget _buildMultiSelect(
    BuildContext context,
    AgentArtifactFormFieldView field,
  ) {
    return DecoratedBox(
      key: ValueKey('agent-artifact-form-field-${widget.card.id}-${field.id}'),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffe5e5e5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ArtifactFormFieldLabel(field: field),
            const SizedBox(height: 10),
            for (var index = 0; index < field.options.length; index++) ...[
              _ArtifactFormOptionRow(
                label: field.options[index],
                selected: _isOptionSelected(field, field.options[index]),
                enabled: !_isLocked,
                onTap: () => _toggleOption(field, field.options[index]),
              ),
              if (field.allowOtherInput &&
                  _isOtherOption(field.options[index]) &&
                  _isOptionSelected(field, field.options[index])) ...[
                const SizedBox(height: 8),
                TextFormField(
                  key: ValueKey(
                    'agent-artifact-form-other-${widget.card.id}-${field.id}',
                  ),
                  initialValue: _otherValues[field.id] ?? '',
                  readOnly: _isLocked,
                  decoration: _inputDecoration(
                    hintText: field.otherPlaceholder ?? '请补充说明',
                  ),
                  onChanged: (value) =>
                      _setOtherFieldValue(field.id, value.trim()),
                ),
              ],
              if (index < field.options.length - 1) const SizedBox(height: 8),
            ],
            _fieldHelpText(context, field),
          ],
        ),
      ),
    );
  }

  Widget _fieldHelpText(
    BuildContext context,
    AgentArtifactFormFieldView field,
  ) {
    final helpText = field.helpText?.trim();
    if (helpText == null || helpText.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        helpText,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xff525252),
          height: 1.4,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText, Widget? suffixIcon}) {
    const borderColor = Color(0xffe5e5e5);
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xff8a737c), fontSize: 14),
      suffixIcon: suffixIcon,
      isDense: true,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.95),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      constraints: const BoxConstraints(minHeight: 44),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xff207d93)),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
    );
  }

  Future<void> _pickDate(AgentArtifactFormFieldView field) async {
    final current = DateTime.tryParse(_textValue(field));
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    final value =
        '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    _setFieldValue(field.id, value);
  }

  Future<bool> submit() async {
    for (final field in widget.card.formFields) {
      if (!field.allowOtherInput || !_isOtherSelected(field)) continue;
      if ((_otherValues[field.id]?.trim() ?? '').isEmpty) {
        setState(() {
          _submitError = '请填写：${field.fieldLabel}的其它内容';
        });
        return false;
      }
    }

    final values = _submittedValues();
    final missingFields = widget.card.formFields
        .where((field) => field.required && !_hasFieldValue(values[field.id]))
        .map((field) => field.fieldLabel)
        .toList(growable: false);
    if (missingFields.isNotEmpty) {
      setState(() {
        _submitError = '请补充：${missingFields.join('、')}';
      });
      return false;
    }
    widget.onDraftChanged?.call(
      Map<String, Object?>.unmodifiable(_draftValues()),
    );

    final action = AgentArtifactActionView(
      label: widget.card.formSubmitLabel ?? '提交',
      icon: Icons.check_rounded,
      kind: 'form.submit',
      value: jsonEncode(values),
      routeExtra: {
        'artifactId': widget.card.id,
        if (widget.card.formId != null) 'formId': widget.card.formId,
        'values': values,
      },
    );
    setState(() {
      _phase = _AgentArtifactFormPhase.submitting;
      _submitError = null;
    });

    var accepted = false;
    try {
      final onSubmit = widget.onSubmit;
      if (onSubmit != null) {
        accepted = await onSubmit(action);
      } else if (widget.onAction != null) {
        widget.onAction!(action);
        accepted = true;
      }
    } catch (_) {
      accepted = false;
    }
    if (!mounted) return accepted;
    setState(() {
      _phase = accepted
          ? _AgentArtifactFormPhase.submitted
          : _AgentArtifactFormPhase.editing;
      _submitError = accepted ? null : '提交失败，请重试';
    });
    if (accepted) widget.onSubmitted?.call();
    return accepted;
  }

  Widget _submitIcon() {
    return switch (_effectivePhase) {
      _AgentArtifactFormPhase.submitting => const SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      _AgentArtifactFormPhase.submitted => const Icon(
        Icons.check_circle_outline_rounded,
        size: 18,
      ),
      _ => const Icon(Icons.check_rounded, size: 18),
    };
  }

  String _submitLabel() {
    return switch (_effectivePhase) {
      _AgentArtifactFormPhase.submitting => '提交中',
      _AgentArtifactFormPhase.submitted => '已提交',
      _ => widget.card.formSubmitLabel ?? '提交',
    };
  }

  bool _isOptionSelected(AgentArtifactFormFieldView field, String option) {
    final value = _values[field.id];
    return value is List && value.contains(option);
  }

  String _textValue(AgentArtifactFormFieldView field) {
    final value = _values[field.id];
    return value == null ? '' : value.toString();
  }

  bool _isOtherSelected(AgentArtifactFormFieldView field) {
    final value = _values[field.id];
    if (field.isMultiSelect) {
      return value is List && value.whereType<String>().any(_isOtherOption);
    }
    return value is String && _isOtherOption(value);
  }

  void _toggleOption(AgentArtifactFormFieldView field, String option) {
    if (_isLocked) return;
    setState(() {
      final current = List<String>.from(
        (_values[field.id] as List?)?.whereType<String>() ?? const <String>[],
      );
      current.contains(option) ? current.remove(option) : current.add(option);
      _values = {..._values, field.id: current};
      _dirtyFieldIds.add(field.id);
      _submitError = null;
    });
    _notifyDraftChanged();
  }

  void _setFieldValue(String id, Object? value) {
    if (_isLocked) return;
    setState(() {
      _values = {..._values, id: value};
      _dirtyFieldIds.add(id);
      _submitError = null;
    });
    _notifyDraftChanged();
  }

  void _setOtherFieldValue(String id, String value) {
    if (_isLocked) return;
    setState(() {
      _otherValues = {..._otherValues, id: value};
      _dirtyFieldIds.add(id);
      _submitError = null;
    });
    _notifyDraftChanged();
  }

  void _resetValues() {
    _values = {
      for (final field in widget.card.formFields)
        if (field.defaultValue != null)
          field.id: field.isMultiSelect
              ? _defaultMultiSelectValues(field.defaultValue)
              : field.defaultValue,
    };
    _otherValues = const <String, String>{};
    _dirtyFieldIds.clear();
    _applyExternalValues(widget.initialDraftValues, markDirty: true);
    _defaultRevision += 1;
    _submitError = null;
    _phase = _AgentArtifactFormPhase.editing;
    _applySubmission(widget.submission);
  }

  void _applySubmission(AgentArtifactFormSubmission? submission) {
    if (submission == null) {
      _phase = _AgentArtifactFormPhase.editing;
      return;
    }

    _applyExternalValues(submission.values);
    _defaultRevision += 1;
    _phase = submission.isSubmitted
        ? _AgentArtifactFormPhase.submitted
        : _AgentArtifactFormPhase.submitting;
    _submitError = null;
  }

  void _applyExternalValues(
    Map<String, Object?> externalValues, {
    bool markDirty = false,
  }) {
    if (externalValues.isEmpty) return;
    final values = Map<String, Object?>.from(_values);
    final otherValues = Map<String, String>.from(_otherValues);
    for (final field in widget.card.formFields) {
      if (!externalValues.containsKey(field.id)) continue;
      final rawValue = externalValues[field.id];
      if (markDirty) _dirtyFieldIds.add(field.id);
      if (!field.allowOtherInput) {
        values[field.id] = rawValue;
        continue;
      }

      if (field.isMultiSelect && rawValue is List) {
        final selected = <String>[];
        for (final item in rawValue.whereType<String>()) {
          final detail = _otherDetail(item);
          if (detail == null) {
            selected.add(item);
            continue;
          }
          final otherOption = _otherOption(field);
          if (otherOption != null) selected.add(otherOption);
          otherValues[field.id] = detail;
        }
        values[field.id] = selected;
        continue;
      }

      if (rawValue is String) {
        final detail = _otherDetail(rawValue);
        final otherOption = _otherOption(field);
        if (detail != null && otherOption != null) {
          values[field.id] = otherOption;
          otherValues[field.id] = detail;
          continue;
        }
      }
      values[field.id] = rawValue;
    }
    _values = values;
    _otherValues = otherValues;
  }

  void _mergeUpdatedDefaults() {
    final values = Map<String, Object?>.from(_values);
    var changed = false;
    for (final field in widget.card.formFields) {
      if (_dirtyFieldIds.contains(field.id) ||
          _hasFieldValue(values[field.id]) ||
          !_hasFieldValue(field.defaultValue)) {
        continue;
      }
      values[field.id] = field.isMultiSelect
          ? _defaultMultiSelectValues(field.defaultValue)
          : field.defaultValue;
      changed = true;
    }
    if (!changed) return;
    _values = values;
    _defaultRevision += 1;
  }

  Map<String, Object?> _submittedValues() {
    final values = <String, Object?>{};
    for (final field in widget.card.formFields) {
      final rawValue = _values[field.id];
      Object? value = rawValue;
      if (field.isMultiSelect && rawValue is List) {
        final otherValue = _otherValues[field.id]?.trim();
        value = rawValue
            .whereType<String>()
            .map((item) {
              if (field.allowOtherInput &&
                  otherValue != null &&
                  otherValue.isNotEmpty &&
                  _isOtherOption(item)) {
                return '其它：$otherValue';
              }
              return item.trim();
            })
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      } else if (rawValue is String) {
        final otherValue = _otherValues[field.id]?.trim();
        value =
            field.allowOtherInput &&
                otherValue != null &&
                otherValue.isNotEmpty &&
                _isOtherOption(rawValue)
            ? '其它：$otherValue'
            : rawValue.trim();
      }
      if (_hasFieldValue(value)) values[field.id] = value;
    }
    return values;
  }

  Map<String, Object?> _draftValues() {
    final values = <String, Object?>{};
    for (final field in widget.card.formFields) {
      if (!_values.containsKey(field.id)) continue;
      final rawValue = _values[field.id];
      Object? value = rawValue;
      final otherValue = _otherValues[field.id]?.trim();
      if (field.isMultiSelect && rawValue is List) {
        value = rawValue
            .whereType<String>()
            .map((item) {
              if (field.allowOtherInput &&
                  otherValue != null &&
                  otherValue.isNotEmpty &&
                  _isOtherOption(item)) {
                return '其它：$otherValue';
              }
              return item;
            })
            .toList(growable: false);
      } else if (rawValue is String &&
          field.allowOtherInput &&
          otherValue != null &&
          otherValue.isNotEmpty &&
          _isOtherOption(rawValue)) {
        value = '其它：$otherValue';
      }
      values[field.id] = value;
    }
    return values;
  }

  void _notifyDraftChanged() {
    widget.onDraftChanged?.call(
      Map<String, Object?>.unmodifiable(_draftValues()),
    );
  }

  bool _hasFieldValue(Object? value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    return true;
  }
}

String? _otherOption(AgentArtifactFormFieldView field) {
  for (final option in field.options) {
    if (_isOtherOption(option)) return option;
  }
  return null;
}

String? _otherDetail(String value) {
  final normalized = value.trim();
  for (final prefix in const ['其它：', '其他：']) {
    if (!normalized.startsWith(prefix)) continue;
    final detail = normalized.substring(prefix.length).trim();
    return detail.isEmpty ? null : detail;
  }
  return null;
}

class _ArtifactFormFieldLabel extends StatelessWidget {
  const _ArtifactFormFieldLabel({required this.field});

  final AgentArtifactFormFieldView field;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: const Color(0xff171717),
      fontWeight: FontWeight.w600,
      height: 1.35,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (field.required) ...[
          Text(
            '*',
            style: style?.copyWith(
              color: const Color(0xffd84c5f),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(child: Text(field.fieldLabel, style: style)),
      ],
    );
  }
}

class _ArtifactFormOptionRow extends StatelessWidget {
  const _ArtifactFormOptionRow({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.radio = false,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool radio;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xfffbfaf9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? const Color(0xff207d93) : const Color(0xffe5e5e5),
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              if (radio)
                SizedBox.square(
                  dimension: 40,
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected
                        ? const Color(0xff207d93)
                        : const Color(0xff737373),
                    size: 22,
                  ),
                )
              else
                Checkbox(
                  value: selected,
                  onChanged: enabled ? (_) => onTap() : null,
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xff171717),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtifactFormGroup extends StatelessWidget {
  const _ArtifactFormGroup({
    required this.title,
    required this.tone,
    required this.children,
    this.compact = false,
  });

  final String title;
  final _ArtifactFormGroupTone tone;
  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tone.title,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Divider(height: 1, color: tone.divider),
          const SizedBox(height: 12),
          ...children,
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: tone.divider)),
              ),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: tone.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ArtifactFormFieldGroup {
  const _ArtifactFormFieldGroup({required this.title, required this.fields});

  final String title;
  final List<AgentArtifactFormFieldView> fields;
}

class _ArtifactFormGroupTone {
  const _ArtifactFormGroupTone({
    required this.background,
    required this.border,
    required this.divider,
    required this.title,
  });

  final Color background;
  final Color border;
  final Color divider;
  final Color title;
}

const _hospitalBagTones = [
  _ArtifactFormGroupTone(
    background: Color(0xfffff6f8),
    border: Color(0xffefd6de),
    divider: Color(0xffecced8),
    title: Color(0xff743149),
  ),
  _ArtifactFormGroupTone(
    background: Color(0xfff4fbf6),
    border: Color(0xffd8e8de),
    divider: Color(0xffcfe5d7),
    title: Color(0xff27634d),
  ),
  _ArtifactFormGroupTone(
    background: Color(0xfff3f8ff),
    border: Color(0xffd7e2f3),
    divider: Color(0xffcbdcf2),
    title: Color(0xff2c5c92),
  ),
  _ArtifactFormGroupTone(
    background: Color(0xfffff8ee),
    border: Color(0xffeadcc8),
    divider: Color(0xffead7bb),
    title: Color(0xff7a5425),
  ),
];

bool _isCollectionForm(String? formId) {
  return formId == 'hospital_bag_intake' ||
      formId == 'birth_journey_basic_info_intake';
}

_ArtifactFormGroupTone _groupTone({
  required String? formId,
  required String title,
  required int index,
}) {
  const tones = _hospitalBagTones;
  const titleIndexes = {'基本信息': 0, '生产信息': 1, '医院信息': 2, '偏好信息': 3};
  final toneIndex = titleIndexes[title] ?? index;
  return tones[toneIndex % tones.length];
}

List<_ArtifactFormFieldGroup> _formFieldGroups(AgentArtifactCardView card) {
  if (card.formFields.isEmpty) return const <_ArtifactFormFieldGroup>[];
  final forceBasicInfoGroup = card.formId == 'birth_journey_basic_info_intake';
  final groups = <_ArtifactFormFieldGroup>[];
  final groupIndexes = <String, int>{};

  for (final field in card.formFields) {
    final title = forceBasicInfoGroup ? '基本信息' : field.groupTitle;
    final key = title.isEmpty ? '__ungrouped' : title;
    final existingIndex = groupIndexes[key];
    if (existingIndex == null) {
      groupIndexes[key] = groups.length;
      groups.add(_ArtifactFormFieldGroup(title: title, fields: [field]));
      continue;
    }
    final existing = groups[existingIndex];
    groups[existingIndex] = _ArtifactFormFieldGroup(
      title: existing.title,
      fields: [...existing.fields, field],
    );
  }
  return groups;
}

List<String> _defaultMultiSelectValues(Object? value) {
  if (value is List) {
    return value
        .map((item) => item?.toString().trim())
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final displayValue = value?.toString().trim();
  return displayValue == null || displayValue.isEmpty
      ? const <String>[]
      : <String>[displayValue];
}

bool _isOtherOption(String option) {
  final normalized = option.trim();
  return normalized == '其它' || normalized == '其他';
}
