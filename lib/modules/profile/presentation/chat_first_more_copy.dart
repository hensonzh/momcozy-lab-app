/// Text for the conversation-first account surface. The legacy account
/// experience keeps its existing English copy while links are migrated.
abstract final class ChatFirstMoreCopy {
  static const title = '账号与设置';
  static const accountInfo = '账号信息';
  static const accountTitle = '我的账号';
  static const accountDetails = '账号详情';
  static const privacy = '隐私';
  static const privacyTitle = '你的隐私';
  static const privacyBody =
      '你的记录和对话仍可在 App 内查看。若要申请删除账号，请前往「账号与设置」并选择「申请删除账号」。';
  static const signOut = '退出登录';
  static const signOutFailed = '退出登录未完成，请检查网络后重试。';
  static const deleteAccount = '删除账号';
  static const deleteDescription =
      '退出后将立即失去此账号的访问权限。账号标识会被移除，并提交关联数据的删除请求；部分记录可能需要继续保留。';
  static const requestDeletion = '申请删除账号';
  static const deleting = '正在删除账号';
  static const deleteDialogTitle = '删除账号？';
  static const deleteDialogBody = '你将在所有设备退出，并失去此账号的访问权限。数据删除会单独处理，此操作无法撤销。';
  static const cancel = '取消';
  static const deleteSuccess = '账号访问权限已移除，数据删除请求仍在处理中。';
  static const deleteFailed = '账号删除请求未完成，请检查网络后重试。';
  static const accountLoading = '正在加载账号…';
  static const accountEmpty = '管理你的账号信息';
}
