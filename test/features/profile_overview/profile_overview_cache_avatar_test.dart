import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/profile_overview/presentation/profile_overview_cache.dart';

void main() {
  const selected = '3d359f49-d269-48db-bef8-1f3fe6d8d09a';
  const stale = '03b5fbd4-0742-4d97-a746-d914f104665c';

  test('fresh avatar activation wins over a stale profile response', () {
    final cache = ProfileOverviewCache(ownerUserId: 'mom', babyId: 'baby');

    cache.activateAvatar(selected);

    expect(cache.resolveAvatarFileId(null), selected);
    cache.reconcileAvatarFileId(null);
    expect(cache.resolveAvatarFileId(null), selected);
    cache.reconcileAvatarFileId(selected);
    expect(cache.resolveAvatarFileId(selected), selected);
  });

  test('choosing the default avatar hides a stale custom avatar', () {
    final cache = ProfileOverviewCache(ownerUserId: 'mom', babyId: 'baby');

    cache.activateAvatar(null);

    expect(cache.resolveAvatarFileId(stale), isNull);
    cache.reconcileAvatarFileId(stale);
    expect(cache.resolveAvatarFileId(stale), isNull);
  });
}
