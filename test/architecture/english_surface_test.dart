import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Approved Chinese UI for the conversation-first product. Other UI remains
// protected by the historical English-only gate.
const _approvedChatFirstChineseSources = <String>{
  'lib/app/baby_module_routes.dart',
  'lib/app/chat_first_navigation.dart',
  'lib/features/agent_hub/presentation/chat_first_workspace.dart',
  'lib/features/agent_hub/presentation/chat_first_actions.dart',
  'lib/features/agent_hub/presentation/chat_first_cry_task.dart',
  'lib/features/agent_hub/presentation/chat_first_poop_task.dart',
  'lib/features/agent_hub/domain/chat_first_poop_task.dart',
  'lib/features/agent_hub/domain/stool_photo_review.dart',
  'lib/features/agent_hub/presentation/chat_first_composer.dart',
  'lib/features/agent_hub/presentation/chat_first_run_copy.dart',
  'lib/features/agent_hub/domain/chat_first_welcome.dart',
  'lib/features/agent_hub/presentation/chat_first_welcome_gate.dart',
  'lib/features/app_pages/devices_page.dart',
  'lib/features/app_pages/chat_first_baby_page.dart',
  'lib/features/app_pages/chat_first_baby_details_page.dart',
  'lib/features/app_pages/chat_first_baby_knowledge.dart',
  'lib/features/app_pages/chat_first_mother_page.dart',
  'lib/features/app_pages/chat_first_status_sheet.dart',
  'lib/features/app_pages/data/chat_first_mother_repository.dart',
  'lib/features/onboarding/domain/chat_first_onboarding.dart',
  'lib/features/onboarding/presentation/chat_first_onboarding_page.dart',
  'lib/features/records/domain/chat_first_record.dart',
  'lib/features/records/data/chat_first_record_repository.dart',
  'lib/features/records/presentation/chat_first_record_sheet.dart',
  // The shared baby controls only display Chinese with chatFirstExperience;
  // their legacy English behavior remains covered by the baby widget/goldens.
  'lib/modules/baby/presentation/baby_design.dart',
  'lib/modules/baby/presentation/baby_growth_curve.dart',
  'lib/modules/baby/presentation/baby_labels.dart',
  'lib/modules/baby/presentation/baby_profile_editor.dart',
  'lib/modules/baby/presentation/baby_record_editor.dart',
  'lib/modules/baby/presentation/baby_record_fields.dart',
  'lib/modules/profile/presentation/chat_first_more_copy.dart',
};

void main() {
  test('App source and native prompts contain no unreviewed Chinese UI copy', () {
    final allowedLegacySource = <String, RegExp>{
      'lib/modules/mom/domain/me_experience.dart': RegExp(
        r"^\s*'[^']+': '[^']+',?\s*$",
      ),
      'lib/core/agent_stream/agent_stream_event.dart': RegExp(
        r'quick replies|quick_replies',
      ),
      'lib/features/agent_hub/domain/agent_conversation.dart': RegExp(
        r'\[系统流程触发\]|用户刚完成',
      ),
      // Only the conversation-first task's scoped feedback; this file also
      // serves legacy English surfaces, so do not allow it wholesale.
      'lib/features/agent_hub/agent_hub_page.dart': RegExp(
        r'_poopFeedback =|请选择不超过 10 MB|照片格式、大小或分辨率不符合要求|审核服务尚未开放|删除这次分析及照片|删除后无法恢复|确认删除|删除失败|照片暂不可用|请结合这次看便便分析结果|提交暂不可用|const Text\(\x27取消\x27',
      ),
      'lib/features/agent_hub/data/platform_image_input.dart': RegExp(
        r'原图不能超过 10 MB|仅支持 JPG、JPEG、PNG、HEIC 原图|照片短边不能低于 720 像素|无法读取照片分辨率',
      ),
    };
    final han = RegExp(r'[\u3400-\u9fff]');
    final errors = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (!han.hasMatch(lines[index]) ||
            _approvedChatFirstChineseSources.contains(file.path)) {
          continue;
        }
        if (allowedLegacySource[file.path]?.hasMatch(lines[index]) == true) {
          continue;
        }
        errors.add('${file.path}:${index + 1}: ${lines[index].trim()}');
      }
    }
    for (final file in [
      File('ios/Runner/Info.plist'),
      ...Directory('android/app/src')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('strings.xml')),
      ...Directory('assets/images')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.svg')),
    ]) {
      if (han.hasMatch(file.readAsStringSync())) errors.add(file.path);
    }
    expect(
      errors,
      isEmpty,
      reason:
          'Only reviewed chat-first UI and legacy protocol keys may contain Chinese.',
    );
  });

  test('shipped web entry points and download artwork are English', () {
    final temporary = Directory.systemTemp.createTempSync('momcozy-web-copy-');
    try {
      final apk = File('${temporary.path}/fixture.apk')..writeAsBytesSync([1]);
      final dist = '${temporary.path}/dist';
      final generated = Process.runSync(
        'node',
        ['scripts/build-flutter-apk-download-site.mjs'],
        environment: {
          ...Platform.environment,
          'MOMCOZY_APK_FLAVOR': 'local',
          'MOMCOZY_APK_MODE': 'debug',
          'MOMCOZY_APK_INPUT': apk.path,
          'MOMCOZY_DOWNLOAD_DIST': dist,
          'MOMCOZY_DOWNLOAD_BASE_URL': 'https://example.org/app',
          'MOMCOZY_API_BASE_URL': 'http://127.0.0.1:8769',
          'MOMCOZY_AGENT_API_BASE_URL': 'http://127.0.0.1:8010',
        },
      );
      expect(
        generated.exitCode,
        0,
        reason: '${generated.stdout}\n${generated.stderr}',
      );
      final han = RegExp(r'[\u3400-\u9fff]');
      for (final path in [
        'web/index.html',
        '$dist/index.html',
        '$dist/assets/momcozy-lab-download-qr.svg',
      ]) {
        final text = File(path).readAsStringSync();
        expect(han.hasMatch(text), isFalse, reason: path);
        expect(text, isNot(contains('Momcozy Lab')), reason: path);
      }
      expect(File('web/index.html').readAsStringSync(), contains('lang="en"'));
    } finally {
      temporary.deleteSync(recursive: true);
    }
  });

  test('visible App copy uses the Momcozy AI brand, not CozyMate', () {
    final oldBrand = RegExp(r'cozymate', caseSensitive: false);
    final errors = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (!oldBrand.hasMatch(line)) continue;
        // Legacy image filenames and internal asset references are not visible text.
        if (line.contains('.png') ||
            line.contains('.svg') ||
            line.contains('MomHomeAssets.cozymate')) {
          continue;
        }
        errors.add('${file.path}:${index + 1}: ${line.trim()}');
      }
    }
    expect(errors, isEmpty);
    expect(
      File('lib/app/momcozy_app.dart').readAsStringSync(),
      contains("title: 'Momcozy AI'"),
    );
    expect(
      File('lib/app/mom_bottom_navigation.dart').readAsStringSync(),
      contains("label: 'Momcozy AI'"),
    );
  });
}
