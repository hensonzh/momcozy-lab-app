import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';

void main() {
  test(
    'app display name is Momcozy Lab across Flutter and Android flavors',
    () {
      final appSource = File('lib/app/momcozy_app.dart').readAsStringSync();
      expect(appSource, contains("title: 'Momcozy Lab'"));

      for (final path in [
        'android/app/src/main/res/values/strings.xml',
        'android/app/src/local/res/values/strings.xml',
        'android/app/src/staging/res/values/strings.xml',
        'android/app/src/production/res/values/strings.xml',
      ]) {
        final strings = File(path).readAsStringSync();
        expect(
          strings,
          contains('<string name="app_name">Momcozy Lab</string>'),
          reason: path,
        );
      }
    },
  );

  test('Android main activity uses a neutral starting window', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:theme="@style/NormalTheme"'));
    expect(manifest, isNot(contains('@style/LaunchTheme')));

    for (final path in [
      'android/app/src/main/res/values/styles.xml',
      'android/app/src/main/res/values-night/styles.xml',
    ]) {
      final styles = File(path).readAsStringSync();
      expect(styles, isNot(contains('LaunchTheme')), reason: path);
      expect(styles, isNot(contains('launch_background')), reason: path);
      expect(styles, isNot(contains('Theme.SplashScreen')), reason: path);
    }

    expect(
      File(
        'android/app/src/main/res/drawable/launch_background.xml',
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        'android/app/src/main/res/drawable-v21/launch_background.xml',
      ).existsSync(),
      isFalse,
    );

    final android12Styles = File(
      'android/app/src/main/res/values-v31/styles.xml',
    ).readAsStringSync();
    expect(android12Styles, isNot(contains('LaunchTheme')));
    expect(android12Styles, isNot(contains('Theme.SplashScreen')));
    expect(android12Styles, contains('android:windowSplashScreenBackground'));
    expect(
      android12Styles,
      contains(
        'android:windowSplashScreenAnimatedIcon">@drawable/transparent_splash_icon',
      ),
    );
    expect(
      File(
        'android/app/src/main/res/drawable/transparent_splash_icon.xml',
      ).existsSync(),
      isTrue,
    );
  });

  test('app logo assets match the approved release checksums', () {
    const expectedSha256ByPath = <String, String>{
      MomCozyAssets.momcozyLogo:
          'b0d608b6fb358e1de04e0c58a579c1b3c7ebd74915e30443ec9ad36dd48f16aa',
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png':
          '1cc325cf8ee0514dd03f9994f02d499c6b9753f4e669d40ce8b289096ca62282',
      'android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png':
          'db711f254c348c91d041a54ae41113129ce75ecdb56eac71ac738a2f52520d6f',
      'android/app/src/main/res/mipmap-mdpi/ic_launcher_round.png':
          '1cc325cf8ee0514dd03f9994f02d499c6b9753f4e669d40ce8b289096ca62282',
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png':
          '2e93be7f0576791b3f8cfff0c6f2e50158a92a82a4fd993195173d6706c3b2b1',
      'android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png':
          'aa9e4625e3fb2a4f8517cc65c80c73e826125e321a61918fb75f982ed8e145cd',
      'android/app/src/main/res/mipmap-hdpi/ic_launcher_round.png':
          '2e93be7f0576791b3f8cfff0c6f2e50158a92a82a4fd993195173d6706c3b2b1',
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png':
          'bfefbcc938daf5a64149bfcac26738bcb35c53e84cb764d466bebc0566e03e77',
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png':
          '657bfeeaad629f1e7e3e0443adf1ead1c63fe7a7bf2f77cdbfefc74f236f2733',
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher_round.png':
          'bfefbcc938daf5a64149bfcac26738bcb35c53e84cb764d466bebc0566e03e77',
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png':
          '3b0e3e1fc41b61c8deeca5b5932c5b0cf1199372e3a28a63f51e7f60c3a38972',
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png':
          'b54add859a75415587e04993b52d0fb958bf12f406267f4dbeec5a1f0beda200',
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher_round.png':
          '3b0e3e1fc41b61c8deeca5b5932c5b0cf1199372e3a28a63f51e7f60c3a38972',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png':
          'd28129627ec5e8b71573a1c222e4be7a341033d3e9cf35d06a0dfa7558fca5dd',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png':
          '9d840a65b48376c844fb113da8e1f9ede7577c5832e37ae979ea84558e913a3b',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png':
          'd28129627ec5e8b71573a1c222e4be7a341033d3e9cf35d06a0dfa7558fca5dd',
    };

    for (final entry in expectedSha256ByPath.entries) {
      final actual = sha256.convert(File(entry.key).readAsBytesSync());
      expect(actual.toString(), entry.value, reason: entry.key);
    }
  });
}
