import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/update/app_release_lifecycle.dart';

void main() {
  test(
    'disabled release reset does not resolve a release or touch account data',
    () async {
      final storage = _MemoryReleaseStorage({
        'momcozy.session.v1.payload': 'atomic-session',
      });
      var releaseLoads = 0;
      var fileCacheClears = 0;

      final policy = await prepareAppReleaseLifecycle(
        enabled: false,
        loadReleaseId: () async {
          releaseLoads += 1;
          return '1.0.0+27';
        },
        storage: storage,
        clearFileCache: () async => fileCacheClears += 1,
      );

      expect(policy, isA<NoopOnboardingReleasePolicy>());
      expect(releaseLoads, 0);
      expect(fileCacheClears, 0);
      expect(storage.values['momcozy.session.v1.payload'], 'atomic-session');
    },
  );

  test('enabled release reset prepares the destructive lifecycle', () async {
    final storage = _MemoryReleaseStorage({
      'momcozy.releaseLifecycle.v1.installedRelease': '1.0.0+26',
      'momcozy.session.v1.payload': 'atomic-session',
    });

    final policy = await prepareAppReleaseLifecycle(
      enabled: true,
      loadReleaseId: () async => '1.0.0+27',
      storage: storage,
      clearFileCache: () async {},
    );

    expect(policy, isA<AppReleaseLifecycle>());
    expect(storage.values, isNot(contains('momcozy.session.v1.payload')));
    expect(policy.releaseId, '1.0.0+27');
  });

  test('new release purges account data and requires a cloud reset', () async {
    final storage = _MemoryReleaseStorage({
      'momcozy.releaseLifecycle.v1.installedRelease': '1.0.0+26',
      'momcozy.session.v1.payload': 'atomic-session',
      'momcozy.agentHub.v1.user.test-user.snapshot': 'draft',
      'momcozy.storageMigration.v1.user.test-user.preferences.volumeUnit': 'mL',
      'momcozy.releaseLifecycle.v1.onboardingComplete.old': '1.0.0+26',
      'momcozy.auth.device_id.v1': 'device-id',
      'momcozy.auth.last_invite_code.v1': 'invite-code',
    });
    var fileCacheClears = 0;
    final lifecycle = AppReleaseLifecycle(
      releaseId: '1.0.0+27',
      storage: storage,
      clearFileCache: () async => fileCacheClears += 1,
    );

    await lifecycle.prepareForLaunch();

    expect(storage.values, isNot(contains('momcozy.session.v1.payload')));
    expect(
      storage.values,
      isNot(contains('momcozy.agentHub.v1.user.test-user.snapshot')),
    );
    expect(
      storage.values,
      isNot(
        contains(
          'momcozy.storageMigration.v1.user.test-user.preferences.volumeUnit',
        ),
      ),
    );
    expect(
      storage.values,
      isNot(contains('momcozy.releaseLifecycle.v1.onboardingComplete.old')),
    );
    expect(storage.values['momcozy.auth.device_id.v1'], 'device-id');
    expect(storage.values['momcozy.auth.last_invite_code.v1'], 'invite-code');
    expect(
      storage.values['momcozy.releaseLifecycle.v1.installedRelease'],
      '1.0.0+27',
    );
    expect(
      storage.values['momcozy.releaseLifecycle.v1.pendingCloudReset'],
      '1.0.0+27',
    );
    expect(fileCacheClears, 1);
    expect(await lifecycle.requiresResetFor('test-user'), isTrue);
  });

  test('same release is idempotent and completion is user scoped', () async {
    final storage = _MemoryReleaseStorage({
      'momcozy.releaseLifecycle.v1.installedRelease': '1.0.0+27',
      'momcozy.releaseLifecycle.v1.pendingCloudReset': '1.0.0+27',
      'momcozy.session.v1.payload': 'new-session',
    });
    var fileCacheClears = 0;
    final lifecycle = AppReleaseLifecycle(
      releaseId: '1.0.0+27',
      storage: storage,
      clearFileCache: () async => fileCacheClears += 1,
    );

    await lifecycle.prepareForLaunch();
    await lifecycle.markCompletedFor('user-a');

    expect(storage.values['momcozy.session.v1.payload'], 'new-session');
    expect(fileCacheClears, 0);
    expect(await lifecycle.requiresResetFor('user-a'), isFalse);
    expect(await lifecycle.requiresResetFor('user-b'), isTrue);
  });

  test('first install also establishes a clean onboarding release', () async {
    final storage = _MemoryReleaseStorage();
    final lifecycle = AppReleaseLifecycle(
      releaseId: '1.0.0+27',
      storage: storage,
      clearFileCache: () async {},
    );

    await lifecycle.prepareForLaunch();

    expect(await lifecycle.requiresResetFor('new-user'), isTrue);
  });
}

class _MemoryReleaseStorage implements AppReleaseLifecycleStorage {
  _MemoryReleaseStorage([Map<String, String>? values])
    : values = Map<String, String>.from(values ?? const {});

  final Map<String, String> values;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll() async => Map.from(values);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
