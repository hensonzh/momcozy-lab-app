import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/agent_stream/agent_stream_event.dart';
import 'package:app/features/agent_hub/artifacts/agent_artifact_mapper.dart';
import 'package:app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:app/features/agent_hub/domain/birth_prep_profile_defaults.dart';

import '../../../support/fixture_reader.dart';

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
      expect(card.description, '');
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
        _artifactEvent(
          id: 'milk-analysis-1',
          type: 'milk_analysis_card',
          payload: {
            'card_type': 'milk_analysis_card',
            'title': '奶量分析',
            'headline': '可继续当前节奏或制定稳奶计划',
            'sections': [
              {
                'id': 'milk',
                'title': '近 7 天记录',
                'metrics': [
                  {'label': '吸奶记录', 'value': '8'},
                ],
              },
              {
                'id': 'next',
                'title': '下一步',
                'items': ['可继续当前节奏或制定稳奶计划'],
              },
            ],
            'can_start_plan': true,
            'recommended_direction': 'maintain',
          },
        ),
      ]);

      expect(cards, hasLength(3));
      expect(
        cards[0].presentationKind,
        AgentArtifactPresentationKind.ibclcConsultCard,
      );
      expect(cards[0].title, 'IBCLC 咨询入口');
      expect(cards[0].payload['reason'], '含乳疼痛');
      final consult = cards[0].specializedView as AgentIbclcConsultCardView;
      expect(consult.consultId, 'consult-explicit');
      expect(consult.consultantName, 'Lin Zhao');
      expect(consult.consultantCredentials, 'IBCLC, RN');
      expect(consult.consultantExperience, '12 年经验');
      expect(consult.consultantBio, '擅长含乳与乳房疼痛支持。');
      expect(consult.chatLabel, '开始咨询');
      expect(consult.chatNote, '将同步本轮哺乳背景');
      expect(
        cards[1].presentationKind,
        AgentArtifactPresentationKind.milkPlanPreview,
      );
      expect(cards[1].payload['tasks'], isA<List<Object?>>());
      expect(cards[1].payload['reminders'], isA<List<Object?>>());
      expect(
        cards[2].presentationKind,
        AgentArtifactPresentationKind.milkAnalysisCard,
      );
      expect(cards[2].title, '奶量分析');
      expect(cards[2].cardJson['headline'], '可继续当前节奏或制定稳奶计划');
      expect(cards[2].cardJson['sections'], isA<List<Object?>>());
    });

    test('maps the legacy IBCLC card envelope and explicit consult id', () {
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
              'chat': {'label': '咨询 IBCLC', 'url': '/ibclc-chat.html'},
            },
          },
        }),
      );

      expect(card, isNotNull);
      expect(
        card!.presentationKind,
        AgentArtifactPresentationKind.ibclcConsultCard,
      );
      final consult = card.specializedView as AgentIbclcConsultCardView;
      expect(consult.consultId, 'ibclc-legacy');
      expect(consult.sourceArtifactId, 'ibclc-artifact-legacy');
      expect(consult.consultantName, 'Emily Chen');
      expect(consult.consultantExperience, '8 年产后哺乳支持经验');
      expect(consult.consultantBio, '擅长含乳评估、吸吮观察和排乳计划。');
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

    test('maps a direct legacy support ticket artifact to a form', () {
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
      expect(card.id, 'ticket-1');
      expect(card.title, '售后工单');
      expect(card.formId, 'support_ticket');
      expect(card.formSubmitLabel, '确认并提交');
      expect(card.formFields, hasLength(6));
      expect(
        card.formFields.map((field) => field.id),
        orderedEquals(const [
          'issue_type',
          'issue_summary',
          'product_model',
          'order_number',
          'purchase_channel',
          'urgency',
        ]),
      );
      expect(card.formFields[0].defaultValue, '设备故障');
      expect(card.formFields[1].defaultValue, '吸奶器无法启动');
      expect(card.formFields[2].defaultValue, 'Air1');
      expect(card.formFields[5].defaultValue, '普通');
      expect(
        card.formFields
            .where((field) => field.required)
            .map((field) => field.id),
        orderedEquals(const [
          'issue_type',
          'issue_summary',
          'product_model',
          'urgency',
        ]),
      );
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
      expect(card.formSubmitLabel, '确认并提交');
      expect(card.formFields[0].defaultValue, '保修');
      expect(card.formFields[1].defaultValue, '电机有异响');
      expect(card.formFields[2].defaultValue, 'M5');
      expect(card.formFields[3].defaultValue, 'ORDER-2');
      expect(card.formFields[4].defaultValue, 'Amazon');
      expect(card.formFields[5].defaultValue, '安全相关');
    });

    test('detects and normalizes legacy hospital bag intake forms', () {
      final card = AgentArtifactMapper.cardFromEvent(
        AgentStreamEvent({
          'type': 'artifact.created',
          'artifact_id': 'legacy-hospital-form',
          'payload': {
            'artifact_type': 'form',
            'form': {
              'id': 'legacy_intake',
              'title': '旧待产包表单',
              'description': '旧版描述',
              'fields': [
                {
                  'id': 'dueDateOrWeek',
                  'label': '',
                  'type': 'date',
                  'defaultValue': '待确认',
                },
                {
                  'id': 'birthPath',
                  'label': '生产信息｜计划分娩方式',
                  'type': 'select',
                  'defaultValue': 'planned_c_section',
                  'helpText': '旧版帮助文案',
                  'options': ['顺产', '剖宫产', '还不确定'],
                },
                {
                  'id': 'fetusCount',
                  'label': '基本信息｜这次是单胎、双胎，还是三胎及以上？',
                  'type': 'select',
                  'defaultValue': '未确定',
                  'options': ['单胎', '双胎', '三胎及以上'],
                },
                {
                  'id': 'hospitalRulesOrNotes',
                  'label': '医院要求',
                  'type': 'textarea',
                },
              ],
            },
          },
        }),
        profileDefaults: const BirthPrepProfileDefaults(
          dueDateOrWeek: '孕25周',
          fetusCount: '单胎',
        ),
      );

      expect(card, isNotNull);
      expect(card!.formId, 'hospital_bag_intake');
      expect(card.title, '信息采集');
      expect(card.description, '');
      expect(card.formFields.map((field) => field.id), [
        'due_date_or_week',
        'birth_path',
        'fetus_count',
      ]);
      expect(card.formFields[0].label, '基本信息｜预产期或当前孕周');
      expect(card.formFields[0].type, 'text');
      expect(card.formFields[0].defaultValue, '孕25周');
      expect(card.formFields[1].label, '生产信息｜分娩方式');
      expect(card.formFields[1].defaultValue, '剖宫产');
      expect(card.formFields[1].helpText, '');
      expect(card.formFields[2].defaultValue, '单胎');
    });

    test('leaves unrelated collection forms unchanged', () {
      final card = AgentArtifactMapper.cardFromEvent(
        _formEvent(
          id: 'generic-form',
          form: {
            'id': 'feedback_intake',
            'title': '体验反馈',
            'description': '请补充你的使用感受。',
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
      expect(card.description, '请补充你的使用感受。');
      expect(card.formFields.map((field) => field.id), [
        'top_worries',
        'details',
      ]);
    });

    test('normalizes basic-info form contracts', () {
      final cards = AgentArtifactMapper.cardsFromEvents(
        [
          _formEvent(
            id: 'basic-info-form',
            form: {
              'id': 'birthJourneyBasicInfoIntake',
              'title': '孕周与基本情况',
              'defaultValues': {'fetusCount': '双胎'},
              'fields': [
                for (final entry in const [
                  ('currentWeek', '当前孕周', 'text'),
                  ('ivf', '是否 IVF（体外受精）', 'select'),
                  ('fetusCount', '单胎/双胎', 'select'),
                  ('age', '年龄', 'number'),
                  ('firstBirth', '是否第一胎', 'select'),
                  ('birthPath', '计划分娩方式', 'select'),
                  ('birthHospital', '建档/生产医院', 'text'),
                ])
                  {
                    'id': entry.$1,
                    'label': entry.$2,
                    'type': entry.$3,
                    'required': false,
                  },
              ],
            },
          ),
        ],
        profileDefaults: const BirthPrepProfileDefaults(
          age: 31,
          fetusCount: '单胎',
          birthHospital: '深圳市妇幼',
        ),
      );

      final basic = cards.single;
      expect(basic.formId, 'birth_journey_basic_info_intake');
      expect(
        basic.formFields
            .where((field) => field.required)
            .map((field) => field.id),
        [
          'current_week',
          'ivf',
          'fetus_count',
          'age',
          'first_birth',
          'birth_path',
        ],
      );
      expect(
        basic.formFields.firstWhere((field) => field.id == 'age').defaultValue,
        31,
      );
      expect(
        basic.formFields
            .firstWhere((field) => field.id == 'fetus_count')
            .defaultValue,
        '双胎',
      );
      expect(
        basic.formFields
            .firstWhere((field) => field.id == 'birth_hospital')
            .defaultValue,
        '深圳市妇幼',
      );
    });

    test('normalizes restored camelCase submission value keys', () {
      final submission = AgentArtifactFormSubmission.tryFromMap({
        'phase': 'submitted',
        'values': {'dueDateOrWeek': '孕38周', 'birthPath': '顺产'},
      });

      expect(submission?.values, {
        'due_date_or_week': '孕38周',
        'birth_path': '顺产',
      });
    });

    test('normalizes legacy hospital-bag cards into stable view models', () {
      final fixture = readFixtureMap(
        'agent_artifacts/legacy_specialized_cards.json',
      );
      final events = (fixture['events'] as List<Object?>).whereType<Map>().map(
        (event) => AgentStreamEvent(Map<String, Object?>.from(event)),
      );

      final cards = AgentArtifactMapper.cardsFromEvents(events);

      final hospitalBag =
          cards.single.specializedView as AgentHospitalBagCardView;
      expect(cards.single.title, '待产包');
      expect(hospitalBag.groups.map((group) => group.id), [
        'documents',
        'mom_hospital_bag',
        'postpartum_home_first_week',
      ]);
      expect(hospitalBag.groups[1].items, hasLength(3));
      expect(hospitalBag.groups[0].items[0].label, '身份证');
      expect(hospitalBag.groups[0].items[0].meta, '原件+复印件');
      expect(hospitalBag.groups[0].items[1].priorityLabel, '和医院确认');
      expect(hospitalBag.groups[0].items[1].meta, isNull);
      expect(hospitalBag.groups[1].items[0].description, '根据住院天数准备，产后更换会更方便。');
      expect(
        hospitalBag.groups[1].items[1].personalization,
        '你是第一胎加上希望母乳喂养，数量已按这个情况调整',
      );
      expect(hospitalBag.groups[1].items[2].description, '按住院天数增减。');
    });

    test('keeps malformed hospital-bag card values renderable', () {
      final cards = AgentArtifactMapper.cardsFromEvents([
        _artifactEvent(
          id: 'sparse-hospital-bag',
          type: 'hospital_bag_card',
          payload: {
            'packing_groups': [
              null,
              'invalid',
              {
                'title': '自定义分组',
                'items': [null, 'invalid', <String, Object?>{}],
              },
            ],
          },
        ),
      ]);

      final hospitalBag =
          cards.single.specializedView as AgentHospitalBagCardView;
      expect(cards.single.title, '待产包');
      expect(hospitalBag.groups, hasLength(1));
      expect(hospitalBag.groups.single.title, '自定义分组');
      expect(hospitalBag.groups.single.items.single.label, '物品');
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
