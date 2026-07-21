import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_image_previews.dart';

void main() {
  testWidgets('history image loads original bytes only after user opens it', (
    tester,
  ) async {
    var loadCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentSentImages(
            images: const [
              AgentStreamImageInput(
                dataUrl: '',
                fileId: '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
                mimeType: 'image/png',
                name: '历史图片.png',
              ),
            ],
            loadImageContent: (fileId) async {
              loadCount += 1;
              expect(fileId, '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518');
              return base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
              );
            },
          ),
        ),
      ),
    );

    expect(loadCount, 0);
    expect(find.text('点击查看'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-sent-image-0')));
    await tester.pump();
    await tester.pump();

    expect(loadCount, 1);
    expect(
      find.byKey(const ValueKey('agent-sent-image-close')),
      findsOneWidget,
    );
  });
}
