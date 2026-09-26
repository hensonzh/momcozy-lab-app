import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// These are exact legacy-wire matchers.
// Keep each exception exact so adding another Chinese UI string fails this gate.
const _legacyHanLiterals = <String, List<String>>{
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
  'lib/modules/baby/presentation/baby_knowledge_sheet.dart': ['Cozymate.png'],
  'lib/app/mom_bottom_navigation.dart': ['AvatarCozymateNav.png'],
  'lib/modules/mom/presentation/me_home_page.dart': ['AssetCozymateAvatar.png'],
  'lib/modules/baby/presentation/baby_artwork.dart': [
    'OriginalCozymatePortrait.png',
  ],
};

final _han = RegExp(r'[\u3400-\u9fff\u{20000}-\u{323af}]', unicode: true);
final _retiredBrand = RegExp(r'cozy[\s-]*mate', caseSensitive: false);
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
            for (final asset
                in _legacyAssetIdentifiers[relative] ?? const <String>[]) {
              line = line.replaceAll(asset, '');
            }
            if (_han.hasMatch(line) || _retiredBrand.hasMatch(line)) {
              violations.add('$relative:${index + 1}');
            }
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );
}
