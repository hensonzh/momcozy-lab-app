import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_mapper.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';

void main() {
  group('AgentArtifactMapper', () {
    test('preserves the production collection-form contract', () {
      final cards = AgentArtifactMapper.cardsFromEvents([
        AgentStreamEvent({
          'type': 'artifact.created',
          'artifact_id': 'hospital-bag-intake-1',
          'payload': {
            'artifact_type': 'form',
            'schema_version': '1.0',
            'artifact': {
              'id': 'hospital-bag-intake-1',
              'artifact_type': 'form',
              'schema_version': '1.0',
              'payload': {
                'form': {
                  'id': 'hospital_bag_intake',
                  'title': '信息采集',
                  'description': '这些信息将用于生成个性化待产包。',
                  'submit_label': '提交',
                  'fields': [
                    {
                      'id': 'due_date_or_week',
                      'label': '基本信息｜预产期或当前孕周',
                      'type': 'text',
                      'required': true,
                    },
                    {
                      'id': 'first_birth',
                      'label': '基本信息｜是否第一胎',
                      'type': 'select',
                      'required': true,
                      'options': ['是', '否'],
                    },
                    {
                      'id': 'top_worries',
                      'label': '偏好信息｜最担心的问题',
                      'type': 'multi_select',
                      'options': ['漏带东西', '预算超支'],
                    },
                  ],
                },
              },
            },
          },
        }),
      ]);

      expect(cards, hasLength(1));
      final card = cards.single;
      expect(card.presentationKind, AgentArtifactPresentationKind.form);
      expect(card.schemaVersion, '1.0');
      expect(card.formId, 'hospital_bag_intake');
      expect(card.title, '信息采集');
      expect(card.description, '这些信息将用于生成个性化待产包。');
      expect(card.formFields, hasLength(3));
      expect(card.formFields[1].type, 'select');
      expect(card.formFields[2].isMultiSelect, isTrue);
    });

    test('retains current IBCLC and milk preview artifact payloads', () {
      final cards = AgentArtifactMapper.cardsFromEvents([
        _artifactEvent(
          id: 'ibclc-1',
          type: 'ibclc_consult_card',
          payload: {
            'title': 'IBCLC 咨询入口',
            'reason': '含乳疼痛',
            'feeding_context': '左侧喂养后疼痛',
            'urgency': 'soon',
          },
        ),
        _artifactEvent(
          id: 'milk-preview-1',
          type: 'milk_plan_preview',
          payload: {
            'title': '三天泵奶计划',
            'summary': '将晚间泵奶提前。',
            'direction': 'maintain',
            'tasks': [
              {'title': '20:00 泵奶'},
            ],
            'reminders': [
              {'title': '及时补水'},
            ],
          },
        ),
      ]);

      expect(cards, hasLength(2));
      expect(
        cards[0].presentationKind,
        AgentArtifactPresentationKind.ibclcConsultCard,
      );
      expect(cards[0].title, 'IBCLC 咨询入口');
      expect(cards[0].payload['reason'], '含乳疼痛');
      expect(
        cards[1].presentationKind,
        AgentArtifactPresentationKind.milkPlanPreview,
      );
      expect(cards[1].payload['tasks'], isA<List<Object?>>());
      expect(cards[1].payload['reminders'], isA<List<Object?>>());
    });

    test('marks unsupported schema versions instead of misrendering them', () {
      final cards = AgentArtifactMapper.cardsFromEvents([
        AgentStreamEvent({
          'type': 'artifact.created',
          'artifact_id': 'future-card',
          'payload': {
            'artifact_type': 'hospital_bag_card',
            'schema_version': '9.0',
            'artifact': {
              'id': 'future-card',
              'artifact_type': 'hospital_bag_card',
              'schema_version': '9.0',
              'payload': {
                'card_json': {'title': '未来版本待产包'},
              },
            },
          },
        }),
      ]);

      expect(cards.single.title, '未来版本待产包');
      expect(
        cards.single.presentationKind,
        AgentArtifactPresentationKind.unsupported,
      );
    });

    test('merges repeated artifact updates by artifact id', () {
      final cards = AgentArtifactMapper.cardsFromEvents([
        _artifactEvent(
          id: 'preview-1',
          type: 'milk_plan_preview',
          payload: {'title': '第一版'},
        ),
        AgentStreamEvent({
          ..._artifactEvent(
            id: 'preview-1',
            type: 'milk_plan_preview',
            payload: {'title': '更新版'},
          ).raw,
          'type': 'artifact.updated',
        }),
      ]);

      expect(cards, hasLength(1));
      expect(cards.single.title, '更新版');
    });
  });
}

AgentStreamEvent _artifactEvent({
  required String id,
  required String type,
  required Map<String, Object?> payload,
}) {
  return AgentStreamEvent({
    'type': 'artifact.created',
    'artifact_id': id,
    'payload': {
      'artifact_id': id,
      'artifact_type': type,
      'schema_version': 'v1',
      'artifact': {
        'id': id,
        'artifact_type': type,
        'schema_version': 'v1',
        'payload': payload,
      },
    },
  });
}
