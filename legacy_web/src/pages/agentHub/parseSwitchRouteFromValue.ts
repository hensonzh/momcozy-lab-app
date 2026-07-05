/** 解析 rich_text switch 按钮 value 中的应用内路由 */

export function parseSwitchRouteFromValue(value: string): string | null {
  const trimmed = value.trim();
  if (!trimmed) return null;
  if (trimmed.startsWith("/")) return trimmed;
  if (trimmed === "Immersive Lactation") return "/pump";
  try {
    const parsed = JSON.parse(trimmed) as { route?: unknown; path?: unknown };
    if (typeof parsed.route === "string" && parsed.route.trim()) return parsed.route.trim();
    if (typeof parsed.path === "string" && parsed.path.trim()) return parsed.path.trim();
  } catch {
    // 非 JSON 时按纯路径处理
  }
  return null;
}
