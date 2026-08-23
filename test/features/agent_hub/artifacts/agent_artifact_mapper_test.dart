import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_mapper.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';

void main() {
  group('AgentArtifactMapper', () {
    test('filters retired prenatal artifacts and forms', () {
      final cards = AgentArtifactMapper.cardsFromEvents([
        _artifactEvent(
          id: 'retired-card',
          type: 'hospital_bag_card',
          payload: {'title': 'Retired card'},
        ),
        _formEvent(
          id: 'retired-form',
          form: const {
            'id': 'birthPlanCardIntake',
            'title': 'Retired form',
            'fields': [
              {'id': 'details', 'label': 'Details', 'type': 'text'},
            ],
          },
        ),
      ]);

      expect(cards, isEmpty);
    });

    test('retains the current IBCLC artifact payload', () {
      final cards = AgentArtifactMapper.cardsFromEvents([
        _artifactEvent(
          id: 'ibclc-1',
          type: 'ibclc_consult_card',
          payload: {
            'title': 'IBCLC 咨询入口',
            'consultId': 'consult-explicit',
            'reason': '含乳疼痛',
            'feeding_context': '左侧喂养后疼痛',
            'urgency': 'soon',
            'consultant': {
              'name': 'Lin Zhao',
              'credentials': 'IBCLC, RN',
              'experience': '12 年经验',
              'bio': 'IBCLC 国际认证哺乳顾问，擅长含乳与乳房疼痛支持。',
            },
            'chat': {'label': '开始咨询', 'note': '将同步本轮哺乳背景'},
          },
        ),
      ]);

      expect(cards, hasLength(1));
      expect(
        cards.single.presentationKind,
        AgentArtifactPresentationKind.ibclcConsultCard,
      );
      final consult = cards.single.specializedView as AgentIbclcConsultCardView;
      expect(consult.consultId, 'consult-explicit');
      expect(consult.consultantName, 'Lin Zhao');
      expect(consult.consultantCredentials, 'IBCLC, RN');
      expect(consult.chatLabel, '开始咨询');
    });

    test('maps the legacy IBCLC envelope and explicit consult id', () {
      final card = AgentArtifactMapper.cardFromEvent(
        AgentStreamEvent({
          'type': 'artifact.created',
          'artifact_id': 'ibclc-artifact-legacy',
          'payload': {
            'artifact_type': 'ibclc_consult',
            'card': {
              'title': 'IBCLC 在线咨询',
              'consult_id': 'ibclc-legacy',
              'consultant': {
                'name': 'Emily Chen',
                'credentials': 'IBCLC 国际认证哺乳顾问',
                'experience': '8 年产后哺乳支持经验',
                'bio': '擅长含乳评估、吸吮观察和排乳计划。',
              },
            },
          },
        }),
      );

      expect(card, isNotNull);
      final consult = card!.specializedView as AgentIbclcConsultCardView;
      expect(consult.consultId, 'ibclc-legacy');
      expect(consult.sourceArtifactId, 'ibclc-artifact-legacy');
      expect(consult.consultantName, 'Emily Chen');
    });

    test('marks unsupported schema versions instead of misrendering them', () {
      final card = AgentArtifactMapper.cardFromEvent(
        _artifactEvent(
          id: 'future-card',
          type: 'future_card',
          schemaVersion: '9.0',
          payload: {'title': 'Future card'},
        ),
      );

      expect(card, isNotNull);
      expect(card!.title, 'Future card');
      expect(card.presentationKind, AgentArtifactPresentationKind.unsupported);
    });

    test('merges repeated artifact updates by artifact id', () {
      final cards = AgentArtifactMapper.cardsFromEvents([
        _artifactEvent(
          id: 'note-1',
          type: 'rich_text',
          payload: {'title': '第一版'},
        ),
        AgentStreamEvent({
          ..._artifactEvent(
            id: 'note-1',
            type: 'rich_text',
            payload: {'title': '更新版'},
          ).raw,
          'type': 'artifact.updated',
        }),
      ]);

      expect(cards, hasLength(1));
      expect(cards.single.title, '更新版');
    });

    test('maps a direct support ticket artifact to a form', () {
      final card = AgentArtifactMapper.cardFromEvent(
        AgentStreamEvent({
          'type': 'artifact.created',
          'artifact_id': 'ticket-1',
          'artifact_type': 'support_ticket',
          'submit_label': '确认并提交',
          'artifact': {
            'draft_id': 'draft-1',
            'issue_type': 'malfunction',
            'issue_summary': '吸奶器无法启动',
            'product_model': 'Air1',
            'order_number': 'MC123',
            'purchase_channel': '官网',
            'urgency': 'normal',
          },
        }),
      );

      expect(card, isNotNull);
      expect(
        card!.presentationKind,
        AgentArtifactPresentationKind.supportTicketDraft,
      );
      expect(card.formId, 'support_ticket');
      expect(card.formSubmitLabel, '确认并提交');
      expect(card.formFields.map((field) => field.id), [
        'issue_type',
        'issue_summary',
        'product_model',
        'order_number',
        'purchase_channel',
        'urgency',
      ]);
      expect(card.formFields[1].defaultValue, '吸奶器无法启动');
      expect(card.formFields[2].defaultValue, 'Air1');
    });

    test('normalizes a nested camelCase support ticket draft', () {
      final card = AgentArtifactMapper.cardFromEvent(
        AgentStreamEvent({
          'type': 'artifact.created',
          'payload': {
            'artifact_type': 'support_ticket_draft',
            'ticket': {
              'id': 'ticket-camel',
              'issueType': '保修',
              'issueSummary': '电机有异响',
              'productModel': 'M5',
              'orderNumber': 'ORDER-2',
              'purchaseChannel': 'Amazon',
              'urgency': 'safety',
            },
          },
        }),
      );

      expect(card, isNotNull);
      expect(card!.id, 'ticket-camel');
      expect(card.formFields[3].defaultValue, 'ORDER-2');
      expect(card.formFields[4].defaultValue, 'Amazon');
      expect(card.formFields[5].defaultValue, '安全相关');
    });

    test('normalizes unrelated collection forms generically', () {
      final card = AgentArtifactMapper.cardFromEvent(
        _formEvent(
          id: 'generic-form',
          form: const {
            'id': 'feedbackIntake',
            'title': '体验反馈',
            'description': '请补充你的使用感受。',
            'defaultValues': {'topWorries': '续航'},
            'fields': [
              {'id': 'topWorries', 'label': '最关注的问题', 'type': 'textarea'},
              {'id': 'details', 'label': '详细说明', 'type': 'textarea'},
            ],
          },
        ),
      );

      expect(card, isNotNull);
      expect(card!.formId, 'feedback_intake');
      expect(card.title, '体验反馈');
      expect(card.formFields.map((field) => field.id), [
        'top_worries',
        'details',
      ]);
      expect(card.formFields.first.defaultValue, '续航');
    });

    test('normalizes restored camelCase submission value keys', () {
      final submission = AgentArtifactFormSubmission.tryFromMap({
        'phase': 'submitted',
        'values': {'feedingContext': '左侧含乳疼痛', 'topWorries': '吸吮效率'},
      });

      expect(submission?.values, {
        'feeding_context': '左侧含乳疼痛',
        'top_worries': '吸吮效率',
      });
    });
  });
}

AgentStreamEvent _formEvent({
  required String id,
  required Map<String, Object?> form,
}) {
  return AgentStreamEvent({
    'type': 'artifact.created',
    'artifact_id': id,
    'payload': {'artifact_type': 'form', 'form': form},
  });
}

AgentStreamEvent _artifactEvent({
  required String id,
  required String type,
  String schemaVersion = 'v1',
  required Map<String, Object?> payload,
}) {
  return AgentStreamEvent({
    'type': 'artifact.created',
    'artifact_id': id,
    'payload': {
      'artifact_id': id,
      'artifact_type': type,
      'schema_version': schemaVersion,
      'artifact': {
        'id': id,
        'artifact_type': type,
        'schema_version': schemaVersion,
        'payload': payload,
      },
    },
  });
}
