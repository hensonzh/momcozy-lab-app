import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// These are exact legacy-wire matchers.
// Keep each exception exact so adding another Chinese UI string fails this gate.
const _legacyHanLiterals = <String, List<String>>{
  // The committed chat-first thread title is user-visible in conversation history.
  'lib/features/agent_hub/data/agent_conversation_api_repository.dart': [
    '宝宝哭声',
  ],
  'lib/core/agent_stream/agent_stream_event.dart': ['快捷回复', '推荐回复'],
  'lib/features/agent_hub/domain/agent_conversation.dart': [
    '[系统流程触发]',
    '用户刚完成体态动态评估',
    '用户刚完成头颈姿态动态评估',
  ],
  'lib/modules/mom/domain/me_experience.dart': [
    '有力气',
    '还撑得住',
    '很疲惫',
    '少于 3 小时',
    '3–4 小时',
    '4–5 小时',
    '5–6 小时',
    '6 小时以上',
    '不确定',
    '不太好',
    '一般',
    '不错',
    '含得稳',
    '容易松开',
    '含不住',
    '愿意吃一些',
    '不太愿意',
    '不愿意吃',
    '愿意吃',
  ],
};

// Exact conversation-first photo feedback embedded in the shared hub page.
// Keep the legacy English-only gate for every other line of that file.
const _chatFirstPoopFeedbackLiterals = <String>[
  '请选择不超过 10 MB 的 JPG、PNG 或 HEIC 原图。',
  '照片格式、大小或分辨率不符合要求，请重新选择。',
  '审核服务尚未开放，请稍后再试。',
  '删除这次分析及照片？',
  '删除后无法恢复。如果照片也用于其他分析，相关分析也会失效。',
  '取消',
  '确认删除',
  '删除失败，请稍后重试。',
  '照片暂不可用或已删除。',
  '提交暂不可用，请稍后重试。',
];

const _stoolPhotoPickerLiterals = <String>[
  '原图不能超过 10 MB。',
  '仅支持 JPG、JPEG、PNG、HEIC 原图。',
  '照片短边不能低于 720 像素。',
  '无法读取照片分辨率，请重新选择。',
];

const _legacyAssetIdentifiers = <String, List<String>>{
  'lib/modules/mom/presentation/mom_home_sections.dart': [
    'MomHomeAssets.cozymate',
  ],
  'lib/shared/design_system/mom_home_tokens.dart': [
    'cozymate_avatar.png',
    'cozymate =',
  ],
  'lib/features/agent_hub/agent_hub_page.dart': [
    'cozymate_attachment_camera.png',
    'cozymate_attachment_photo.svg',
    'cozymate_attachment_file.svg',
  ],
  'lib/features/agent_hub/presentation/chat_first_composer.dart': [
    'cozymate_attachment_camera.png',
    'cozymate_attachment_photo.svg',
    'cozymate_attachment_file.svg',
  ],
  'lib/modules/baby/presentation/baby_knowledge_sheet.dart': ['Cozymate.png'],
  'lib/app/mom_bottom_navigation.dart': ['AvatarCozymateNav.png'],
  'lib/modules/mom/presentation/me_home_page.dart': ['AssetCozymateAvatar.png'],
  'lib/modules/baby/presentation/baby_artwork.dart': [
    'OriginalCozymatePortrait.png',
  ],
};

final _han = RegExp(r'[\u3400-\u9fff\u{20000}-\u{323af}]', unicode: true);
final _retiredBrand = RegExp(r'cozy[\s-]*mate', caseSensitive: false);
// The confirmed chat-first product ships in Chinese. Preserve the legacy
// English-only guard everywhere else and keep retired-brand checks global.
const _approvedChatFirstChineseSources = <String>{
  'lib/app/baby_module_routes.dart',
  'lib/app/chat_first_navigation.dart',
  'lib/features/agent_hub/presentation/chat_first_workspace.dart',
  'lib/features/agent_hub/presentation/chat_first_actions.dart',
  'lib/features/agent_hub/presentation/chat_first_cry_task.dart',
  'lib/features/agent_hub/presentation/chat_first_poop_task.dart',
  'lib/features/agent_hub/domain/chat_first_poop_task.dart',
  'lib/features/agent_hub/domain/chat_first_daily_advice.dart',
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
  // Language exception only; clinical review is tracked separately in the catalog.
  'assets/content/baby_daily_advice_0_364.json',
};
const _textExtensions = <String>{
  '.dart',
  '.xml',
  '.plist',
  '.html',
  '.svg',
  '.strings',
  '.json',
  '.yaml',
  '.yml',
  '.kt',
  '.java',
  '.swift',
};

void main() {
  test(
    'shipped product-controlled source has no unapproved Chinese or old brand',
    () {
      final violations = <String>[];
      for (final root in [
        'lib',
        'android/app/src',
        'ios/Runner',
        'web',
        'assets',
      ]) {
        for (final file in Directory(
          root,
        ).listSync(recursive: true).whereType<File>()) {
          final relative = file.path;
          if (!_textExtensions.any(relative.endsWith)) continue;
          if (relative.startsWith('assets/fonts/')) continue;
          final lines = file.readAsLinesSync();
          for (var index = 0; index < lines.length; index++) {
            var line = lines[index];
            for (final legacy
                in _legacyHanLiterals[relative] ?? const <String>[]) {
              line = line.replaceAll(legacy, '');
            }
            if (relative == 'lib/features/agent_hub/agent_hub_page.dart') {
              for (final approved in _chatFirstPoopFeedbackLiterals) {
                line = line.replaceAll(approved, '');
              }
            }
            if (relative ==
                'lib/features/agent_hub/data/platform_image_input.dart') {
              for (final approved in _stoolPhotoPickerLiterals) {
                line = line.replaceAll(approved, '');
              }
            }
            for (final asset
                in _legacyAssetIdentifiers[relative] ?? const <String>[]) {
              line = line.replaceAll(asset, '');
            }
            if ((_han.hasMatch(line) &&
                    !_approvedChatFirstChineseSources.contains(relative)) ||
                _retiredBrand.hasMatch(line)) {
              violations.add('$relative:${index + 1}');
            }
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );
}
