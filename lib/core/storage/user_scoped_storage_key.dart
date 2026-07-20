const _userScopedStorageNamespace = 'momcozy.storageMigration.v1';

String userScopedStorageKey(String userId, String key) {
  return '$_userScopedStorageNamespace.user.${Uri.encodeComponent(userId)}.$key';
}
