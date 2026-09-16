import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'action preview controls and authoritative results $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          Future<void> reveal(Finder finder) async {
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }

          Future<void> capture(String state) async => expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/agent-action-$state-${width.toInt()}-${scale.toInt()}x.png',
            ),
          );
          for (final reject in [false, true]) {
            for (final fails in [false, true]) {
              final operation = reject ? 'reject' : 'confirm';
              final connector = _ActionConnector();
              final event = AgentStreamEvent({
                'type': 'action.confirmation_required',
                'action_id': 'schedule-delete',
                'payload': {
                  'action_type': 'schedule_task_delete',
                  'summary': '删除测试日程',
                  'preview_payload': {
                    'title': '删除测试日程',
                    'target': '测试日程',
                    'before': '2026-09-13 14:00',
                    'after': '删除',
                    'date': '2026-09-13',
                    'timezone': 'Asia/Shanghai',
                    'impact_scope': '仅此任务',
                  },
                },
              });
              await tester.pumpWidget(
                MaterialApp(
                  key: ValueKey('$operation-$fails'),
                  debugShowCheckedModeBanner: false,
                  theme: momCozyTheme(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true,
                    ),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: AgentHubPage(
                      state: AgentStreamRunState(
                        phase: AgentStreamRunPhase.finished,
                        textContent: '请确认是否执行上述变更。',
                        events: [event],
                      ),
                      actionClient: AgentStreamActionClient(
                        endpoint: AgentStreamEndpoint(
                          uri: Uri.parse(
                            'https://fixture.invalid/v1/agent/actions',
                          ),
                        ),
                        connector: connector,
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              await tester.runAsync(
                () => precacheImage(
                  const AssetImage(MomCozyAssets.agentAvatar),
                  tester.element(find.byType(AgentHubPage)),
                ),
              );
              await tester.pumpAndSettle();
              final panel = find.byKey(const ValueKey('agent-action-panel'));
              expect(panel, findsOneWidget);
              for (final label in [
                '对象：测试日程',
                '原值：2026-09-13 14:00',
                '变更后：删除',
                '日期：2026-09-13',
                '时区：Asia/Shanghai',
                '影响范围：仅此任务',
              ]) {
                expect(find.text(label), findsOneWidget);
              }
              if (!reject && !fails) {
                await reveal(find.text('待确认'));
                await capture('preview');
              }
              final button = find.byKey(
                ValueKey('agent-action-$operation-schedule-delete'),
              );
              await reveal(button);
              expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
              if (!reject && !fails) await capture('controls');
              // Two clicks before a new frame must still produce one request.
              await tester.tap(button);
              await tester.tap(button);
              await tester.pumpAndSettle();
              expect(connector.calls, 1);
              expect(
                connector.uri!.path,
                '/v1/agent/actions/schedule-delete/$operation',
              );
              expect(
                jsonDecode(connector.body!),
                reject ? {'reason': 'user_rejected'} : <String, Object?>{},
              );
              if (!reject) {
                expect(
                  connector.headers!['Idempotency-Key'],
                  'agent-action-schedule-delete',
                );
              }
              expect(
                find.byKey(
                  const ValueKey('agent-action-confirm-schedule-delete'),
                ),
                findsNothing,
              );
              expect(
                find.byKey(
                  const ValueKey('agent-action-reject-schedule-delete'),
                ),
                findsNothing,
              );
              final pending = find.text(reject ? '拒绝中' : '确认中');
              await reveal(pending);
              expect(
                find.ancestor(
                  of: pending,
                  matching: find.byWidgetPredicate(
                    (w) => w is Semantics && w.properties.liveRegion == true,
                  ),
                ),
                findsOneWidget,
              );
              if (!fails) await capture('$operation-pending');
              connector.gate.complete(
                AgentStreamControlHttpResponse(
                  statusCode: fails ? 503 : 200,
                  body: jsonEncode({'status': reject ? 'rejected' : 'applied'}),
                ),
              );
              await tester.pumpAndSettle();
              final result = find.text(
                fails
                    ? '失败'
                    : reject
                    ? '已拒绝'
                    : '已应用',
              );
              await reveal(result);
              await capture('$operation-${fails ? "failed" : "success"}');
              expect(
                find.byKey(
                  const ValueKey('agent-action-confirm-schedule-delete'),
                ),
                findsNothing,
              );
              expect(
                find.byKey(
                  const ValueKey('agent-action-reject-schedule-delete'),
                ),
                findsNothing,
              );
              expect(connector.calls, 1);
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
            }
          }
        },
      );
    }
  }
}

class _ActionConnector implements AgentStreamControlHttpConnector {
  final gate = Completer<AgentStreamControlHttpResponse>();
  int calls = 0;
  Uri? uri;
  String? body;
  Map<String, String>? headers;
  @override
  Future<AgentStreamControlHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    Duration? timeout,
  }) {
    calls++;
    this.uri = uri;
    this.body = body;
    this.headers = headers;
    return gate.future;
  }
}
