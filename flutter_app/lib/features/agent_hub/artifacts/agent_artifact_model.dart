import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';

typedef AgentArtifactFormSubmitHandler =
    Future<bool> Function(AgentArtifactActionView action);

enum AgentArtifactPresentationKind {
  form,
  milkAnalysisCard,
  milkPlanCard,
  milkPlanPreview,
  birthJourneyPlanCard,
  birthPlanCard,
  hospitalBagCard,
  hospitalBagCart,
  ibclcConsultCard,
  richText,
  generic,
  unsupported,
}

class AgentArtifactCardView {
  const AgentArtifactCardView({
    required this.id,
    required this.title,
    this.artifactType,
    this.schemaVersion = 'v1',
    this.presentationKind = AgentArtifactPresentationKind.generic,
    this.cardType,
    this.payload = const <String, Object?>{},
    this.cardJson = const <String, Object?>{},
    this.rawCard = const <String, Object?>{},
    this.content,
    this.description,
    this.statusLabel,
    this.rows = const <String>[],
    this.formId,
    this.formSubmitLabel,
    this.formFields = const <AgentArtifactFormFieldView>[],
    this.actions = const <AgentArtifactActionView>[],
  });

  final String id;
  final String title;
  final String? artifactType;
  final String schemaVersion;
  final AgentArtifactPresentationKind presentationKind;
  final String? cardType;
  final Map<String, Object?> payload;
  final Map<String, Object?> cardJson;
  final Map<String, Object?> rawCard;
  final String? content;
  final String? description;
  final String? statusLabel;
  final List<String> rows;
  final String? formId;
  final String? formSubmitLabel;
  final List<AgentArtifactFormFieldView> formFields;
  final List<AgentArtifactActionView> actions;

  bool get isForm =>
      presentationKind == AgentArtifactPresentationKind.form ||
      formFields.isNotEmpty;

  bool get isUnsupported =>
      presentationKind == AgentArtifactPresentationKind.unsupported;
}

class AgentArtifactFormFieldView {
  const AgentArtifactFormFieldView({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const <String>[],
    this.placeholder,
    this.defaultValue,
    this.allowOtherInput = false,
    this.otherPlaceholder,
    this.helpText,
  });

  final String id;
  final String label;
  final String type;
  final bool required;
  final List<String> options;
  final String? placeholder;
  final Object? defaultValue;
  final bool allowOtherInput;
  final String? otherPlaceholder;
  final String? helpText;

  String get groupTitle => _splitFormFieldLabel(label).groupTitle;

  String get fieldLabel => _splitFormFieldLabel(label).fieldLabel;

  bool get isMultiSelect {
    return type == 'multi_select' ||
        type == 'checkboxes' ||
        type == 'checkbox_group';
  }

  bool get isChoice => isMultiSelect || type == 'select' || type == 'radio';
}

class AgentArtifactActionView {
  const AgentArtifactActionView({
    required this.label,
    required this.icon,
    required this.kind,
    this.value,
    this.routePath,
    this.routeExtra,
    this.hospitalBagCartSeed,
  });

  final String label;
  final IconData icon;
  final String kind;
  final String? value;
  final String? routePath;
  final Object? routeExtra;
  final HospitalBagCartArtifactSeed? hospitalBagCartSeed;
}

abstract final class AgentArtifactActions {
  static const hospitalBagCart = AgentArtifactActionView(
    label: '打开待产包购物车',
    icon: Icons.shopping_cart_outlined,
    kind: 'artifact',
    value: '/hospital-bag-cart',
    routePath: '/hospital-bag-cart',
  );
}

({String groupTitle, String fieldLabel}) _splitFormFieldLabel(String label) {
  final normalized = label.trim();
  final separatorIndex = normalized.indexOf('｜');
  if (separatorIndex <= 0) {
    return (groupTitle: '', fieldLabel: normalized);
  }
  final groupTitle = normalized.substring(0, separatorIndex).trim();
  final fieldLabel = normalized.substring(separatorIndex + 1).trim();
  if (groupTitle.isEmpty || fieldLabel.isEmpty) {
    return (groupTitle: '', fieldLabel: normalized);
  }
  return (groupTitle: groupTitle, fieldLabel: fieldLabel);
}
