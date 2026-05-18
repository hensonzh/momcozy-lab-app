/** 使用「顶栏预留 + 中间滚动 + 嵌入底栏」整页 shell 的路由（与 AppLayout 全局顶栏/底栏互斥） */
export const TAB_SHELL_PATHS = ["/status", "/schedule", "/community", "/device", "/device/manage", "/w1"] as const;

export type TabShellPath = (typeof TAB_SHELL_PATHS)[number];

export function isTabShellPath(pathname: string): pathname is TabShellPath {
  return (TAB_SHELL_PATHS as readonly string[]).includes(pathname);
}
