import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release identity is preserved and build number advances', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final versionMatch = RegExp(
      r'^version:\s*[^+\s]+\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(versionMatch, isNotNull);
    expect(int.parse(versionMatch!.group(1)!), greaterThanOrEqualTo(55));

    final androidBuild = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();
    expect(
      androidBuild,
      contains('applicationId = "com.momcozymai.app.flutterpoc"'),
    );
    expect(androidBuild, contains('applicationIdSuffix = ".local"'));
    expect(androidBuild, contains('applicationIdSuffix = ".staging"'));
    expect(
      androidBuild,
      contains(
        'create("play") {\n            dimension = "environment"\n            applicationId = "momcozy.com.mai"',
      ),
    );
    expect(androidBuild, isNot(contains('create("test")')));

    final xcodeProject = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    expect(
      xcodeProject,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.momcozymai.app.flutterpoc;'),
    );
  });

  test(
    'native capability merge keeps MotionPose and drops retired channels',
    () {
      final appDelegate = File(
        'ios/Runner/AppDelegate.swift',
      ).readAsStringSync();
      expect(appDelegate, contains('MotionPosePlugin.register'));
      expect(appDelegate, isNot(contains('AgentRunContextPlugin')));

      final androidSources = Directory('android/app/src/main/kotlin')
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.readAsStringSync())
          .join('\n');
      expect(androidSources, contains('MotionPosePlugin'));
      expect(androidSources, isNot(contains('AgentRunContextPlugin')));
      expect(androidSources, isNot(contains('ScheduleReminderReceiver')));

      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, isNot(contains('RECEIVE_BOOT_COMPLETED')));
      expect(manifest, isNot(contains('ScheduleReminder')));
    },
  );

  test('Xcode Flutter preparation runs from the app root', () {
    final runnerScheme = File(
      'ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme',
    ).readAsStringSync();

    expect(runnerScheme, contains(r'cd &quot;$SRCROOT/..&quot;'));
    expect(runnerScheme, contains('xcode_backend.sh&quot; prepare'));
  });

  test('optional camera and privacy prompts cover merged feature use', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      manifest,
      contains(
        'android:name="android.hardware.camera.any" '
        'android:required="false"',
      ),
    );

    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(infoPlist, contains('share with Momcozy AI'));
    expect(infoPlist, contains('voice messages'));
    expect(infoPlist, contains('parenting-related image'));
  });

  test('MotionPose model provisioning is pinned and works offline', () {
    final androidBuild = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();

    expect(
      androidBuild,
      contains(
        '59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a',
      ),
    );
    expect(androidBuild, contains('MOMCOZY_POSE_MODEL_FILE'));
    expect(androidBuild, contains('gradle.gradleUserHomeDir'));
    expect(androidBuild, contains('gradle.startParameter.isOffline'));
  });
}
