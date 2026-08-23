import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Removes durable data left by prenatal features that are no longer shipped.
///
/// This migration is intentionally deletion-only and may be removed after all
/// supported upgrade paths have crossed this release.
class LegacyPrenatalDataCleaner {
  const LegacyPrenatalDataCleaner({
    this.storage = const FlutterSecureStorage(),
  });

  static const _hospitalBagKeyPrefix = 'momcozy.hospital-bag-cart.v1.user.';

  final FlutterSecureStorage storage;

  Future<int> clean() async {
    final values = await storage.readAll();
    final obsoleteKeys = values.keys
        .where((key) => key.startsWith(_hospitalBagKeyPrefix))
        .toList(growable: false);
    await Future.wait([
      for (final key in obsoleteKeys) storage.delete(key: key),
    ]);
    return obsoleteKeys.length;
  }

  Future<int> cleanBestEffort() async {
    try {
      return await clean();
    } catch (_) {
      // A storage plugin failure must not block startup. The cleanup is
      // idempotent and will be retried on the next launch.
      return 0;
    }
  }
}
