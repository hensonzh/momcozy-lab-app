import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
    };
    final han = RegExp(r'[\u3400-\u9fff]');
    final errors = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (!han.hasMatch(lines[index])) continue;
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
          'Only protocol and legacy-data compatibility keys may remain in Chinese.',
    );
  });

  test('shipped web entry points and download artwork are English', () {
    final han = RegExp(r'[\u3400-\u9fff]');
    for (final path in [
      'web/index.html',
      'dist/android-apk/index.html',
      'dist/android-apk/assets/momcozy-lab-download-qr.svg',
    ]) {
      final text = File(path).readAsStringSync();
      expect(han.hasMatch(text), isFalse, reason: path);
      expect(text, isNot(contains('Momcozy Lab')), reason: path);
    }
    expect(File('web/index.html').readAsStringSync(), contains('lang="en"'));
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
