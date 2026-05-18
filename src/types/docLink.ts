/** doc-links 卡片中单条资料的类型 */
export type DocLinkKind = "pdf" | "video" | "other";

/**
 * 对话/流程中「资料链接」单条数据结构。
 * @property title 展示标题
 * @property icon 展示用 emoji 或符号
 * @property desc 短描述
 * @property url 可选远程 GET 地址（相对路径时由 http 层拼 BASE_URL）
 * @property kind 可选显式类型；缺省可按扩展名推断
 */
export interface DocLinkItem {
  title: string;
  icon: string;
  desc: string;
  url?: string;
  kind?: DocLinkKind;
}
