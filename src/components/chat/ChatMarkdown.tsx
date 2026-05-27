import { cloneElement, isValidElement, type FC, type MouseEvent, type ReactNode } from "react";
import ReactMarkdown from "react-markdown";
import remarkBreaks from "remark-breaks";
import remarkGfm from "remark-gfm";
import { ChevronRight, ShoppingBag } from "lucide-react";
import { ChatMarkdownImg } from "@/components/chat/ChatMarkdownImage";
import { resolveChatAssetUrl } from "@/lib/chatAssetUrl";
import { resolveHttpRequestUrl } from "@/lib/http";
import { cn } from "@/lib/utils";

export type ChatMarkdownVariant = "user" | "assistant" | "muted";

/**
 * 将 `![alt](url)` 中的图片地址转为可在浏览器加载的绝对 URL。
 * 已是 http(s)/data/blob/协议相对 URL 时不修改；否则拼到聊天资源服务前缀后。
 * @param src Markdown 解析出的 img src，可能为相对路径
 * @returns 可直接用于 `<img src>` 的地址；入参为空时原样返回
 */
function resolveChatMarkdownImageSrc(src: string | undefined): string | undefined {
  if (!src?.trim()) return src;
  return resolveChatAssetUrl(src);
}

function resolveChatMarkdownHref(href: string | undefined): string | undefined {
  if (!href?.trim()) return href;
  const raw = href.trim();
  if (raw.startsWith("/skill-assets/")) return resolveHttpRequestUrl(raw);
  return resolveChatAssetUrl(raw, { preservePageRelative: true });
}

function skillAssetLinkLabel(url: string): string {
  const path = url.split(/[?#]/)[0]?.toLowerCase() ?? "";
  if (path.endsWith(".pdf")) return "打开 PDF";
  if (/\.(mp4|mov|m4v|webm)$/.test(path)) return "打开视频";
  if (/\.(png|jpe?g|gif|webp|svg)$/.test(path)) return "查看图片";
  return "打开资源";
}

const BARE_SKILL_ASSET_URL_PATTERN =
  /(^|[\s:：])((?:\/skill-assets\/)[^\s<>)\]}，。；;、]+(?:\.(?:pdf|mp4|mov|m4v|webm|png|jpe?g|gif|webp|svg))(?:[?#][^\s<>)\]}，。；;、]*)?)/gi;

export function linkifyBareSkillAssetUrlsForMarkdown(markdown: string): string {
  let inFence = false;
  return markdown
    .split("\n")
    .map((line) => {
      if (/^\s*```/.test(line)) {
        inFence = !inFence;
        return line;
      }
      if (inFence) return line;
      return line.replace(BARE_SKILL_ASSET_URL_PATTERN, (_match, prefix: string, url: string) => {
        return `${prefix}[${skillAssetLinkLabel(url)}](${url})`;
      });
    })
    .join("\n");
}

/**
 * 将 React 子节点递归为纯文本，用于从 `[文案](图链)` 取有意义的 alt。
 * @param node Markdown 渲染出的子节点
 * @returns 拼接后的纯文本
 */
function reactChildrenToPlainText(node: ReactNode): string {
  if (node == null || typeof node === "boolean") return "";
  if (typeof node === "string" || typeof node === "number") return String(node);
  if (Array.isArray(node)) return node.map(reactChildrenToPlainText).join("");
  if (typeof node === "object" && node !== null && "props" in node) {
    const p = (node as { props?: { children?: ReactNode } }).props;
    if (p?.children !== undefined) return reactChildrenToPlainText(p.children);
  }
  return "";
}

const MARKDOWN_LINE_BREAK_TOKEN = "\uE000CHAT_BR\uE000";

function normalizeMarkdownLineBreaks(markdown: string): string {
  return markdown.replace(/<br\s*\/?>/gi, MARKDOWN_LINE_BREAK_TOKEN);
}

function renderMarkdownLineBreakTokens(node: ReactNode, variant: ChatMarkdownVariant, keyPrefix = "br"): ReactNode {
  if (typeof node === "string") {
    const parts = node.split(MARKDOWN_LINE_BREAK_TOKEN);
    if (parts.length === 1) return node;
    return parts.flatMap((part, index) => {
      if (index === 0) return part ? [part] : [];
      return [
        <ChatMarkdownLineBreak key={`${keyPrefix}-${index}`} variant={variant} />,
        ...(part ? [part] : []),
      ];
    });
  }
  if (Array.isArray(node)) {
    return node.map((child, index) => renderMarkdownLineBreakTokens(child, variant, `${keyPrefix}-${index}`));
  }
  if (isValidElement<{ children?: ReactNode }>(node)) {
    return cloneElement(node, {
      children: renderMarkdownLineBreakTokens(node.props.children, variant, `${keyPrefix}-child`),
    });
  }
  return node;
}

function hasBlankTableHeader(children: ReactNode): boolean {
  const nodes = Array.isArray(children) ? children : [children];
  const header = nodes.find((node) => isValidElement(node) && node.type === "thead");
  if (!header) return false;
  return !reactChildrenToPlainText(header).trim();
}

/**
 * 链接指向图片时：若可见文案与 URL 重复或是裸链，则 alt 置空，避免气泡里再出现一长串地址。
 * @param children 链接子节点
 * @param href 链接地址
 * @returns 适合作为 img alt 的字符串，可能为空
 */
function linkLabelForImageAlt(children: ReactNode, href: string): string {
  const text = reactChildrenToPlainText(children).trim();
  if (!text) return "";
  const h = href.trim();
  if (text === h) return "";
  try {
    const u = new URL(h, "http://dummy.local");
    if (text === u.pathname || text === `${u.pathname}${u.search}`) return "";
  } catch {
    /* 相对路径等 */
  }
  if (/^https?:\/\//i.test(text) && (text === h || h.endsWith(text) || text.endsWith(h))) return "";
  return text;
}

/**
 * 判断 Markdown 超链接是否应以内联图片展示（裸链、扩展名、data:image）。
 * @param href 解析前的 href
 * @returns 为 true 时不渲染 `<a>` 文案而渲染 `ChatMarkdownImg`
 */
function isProbablyImageHref(href: string | undefined): boolean {
  if (!href?.trim()) return false;
  const raw = href.trim();
  if (/^data:image\//i.test(raw)) return true;
  const resolved = resolveChatMarkdownImageSrc(raw) ?? raw;
  try {
    const base = typeof window !== "undefined" ? window.location.href : "http://localhost/";
    const u = new URL(resolved, base);
    const path = u.pathname.toLowerCase();
    const search = u.search.toLowerCase();
    return (
      /\.(png|jpe?g|gif|webp|svg|bmp|ico|avif)$/.test(path) ||
      /\.(png|jpe?g|gif|webp|svg|bmp|ico|avif)(\?|#|$)/i.test(path + search)
    );
  } catch {
    return /\.(png|jpe?g|gif|webp|svg|bmp|ico|avif)(\?|#|$)/i.test(raw);
  }
}

/**
 * 根据气泡场景生成 Tailwind Typography（prose）与配色类名，使 Markdown 在对话气泡内紧凑、可读。
 * @param variant user=主色气泡；assistant=默认卡片；muted=次要说明（如富文本卡片内文）
 * @returns 合并后的 className 字符串
 */
function markdownBubbleProseClass(variant: ChatMarkdownVariant): string {
  const compact =
    "prose prose-sm max-w-none [&_p]:my-1 [&_li]:my-0.5 [&_ul]:my-1 [&_ol]:my-1 [&_blockquote]:my-2 [&_*:first-child]:mt-0 [&_*:last-child]:mb-0";
  if (variant === "user") {
    return cn(
      compact,
      "text-primary-foreground",
      "[&_a]:text-primary-foreground/90 [&_strong]:text-primary-foreground",
      "[&_code]:bg-primary-foreground/15 [&_code]:px-1 [&_code]:py-0.5 [&_code]:rounded [&_code]:text-[0.9em]",
      "[&_pre]:bg-primary-foreground/10 [&_pre]:p-2 [&_pre]:rounded-lg [&_pre]:overflow-x-auto [&_pre]:text-[12px]",
      "[&_blockquote]:border-primary-foreground/40",
      "[&_th]:border-primary-foreground/30 [&_td]:border-primary-foreground/20",
    );
  }
  if (variant === "muted") {
    return cn(
      compact,
      "text-muted-foreground",
      "[&_a]:text-primary [&_strong]:text-foreground",
      "[&_code]:bg-muted/80 [&_code]:px-1 [&_code]:py-0.5 [&_code]:rounded",
      "[&_pre]:bg-muted/50 [&_pre]:p-2 [&_pre]:rounded-lg [&_pre]:overflow-x-auto",
    );
  }
  return cn(
    compact,
    "text-foreground",
    "[&_p+p]:mt-3",
    "[&_a]:text-primary [&_strong]:text-foreground",
    "[&_code]:bg-muted/70 [&_code]:px-1 [&_code]:py-0.5 [&_code]:rounded",
    "[&_pre]:bg-muted/50 [&_pre]:p-2 [&_pre]:rounded-lg [&_pre]:overflow-x-auto",
    "[&_blockquote]:border-border",
  );
}

function ChatMarkdownLineBreak({ variant }: { variant: ChatMarkdownVariant }) {
  if (variant === "user") return <br />;
  return (
    <>
      <br />
      <span aria-hidden="true" className="block h-1.5" />
    </>
  );
}

export interface ChatMarkdownProps {
  /** Markdown 源字符串（含 GFM：表格、删除线、任务列表等） */
  markdown: string;
  /** 视觉变体，对应用户/助手/次要说明 */
  variant?: ChatMarkdownVariant;
  /** 外层容器额外类名（如字号覆盖） */
  className?: string;
}

const HOSPITAL_BAG_CART_PATHS = new Set(["/hospital-bag-cart"]);
const OPEN_HOSPITAL_BAG_CART_EVENT = "momcozy-open-hospital-bag-cart";

function isHospitalBagCartHref(href: string): boolean {
  const raw = href.trim();
  if (!raw) return false;
  try {
    const base = typeof window !== "undefined" ? window.location.origin : "https://momcozy.local";
    const url = new URL(raw, base);
    return HOSPITAL_BAG_CART_PATHS.has(url.pathname);
  } catch {
    return HOSPITAL_BAG_CART_PATHS.has(raw.split(/[?#]/, 1)[0] ?? raw);
  }
}

function extractHospitalBagCartPreviewHrefs(markdown: string): string[] {
  const hrefs = new Set<string>();
  const markdownLinkPattern = /\[[^\]]+\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g;
  for (const match of markdown.matchAll(markdownLinkPattern)) {
    const href = match[1]?.trim();
    if (href && isHospitalBagCartHref(href)) hrefs.add(href);
  }

  const bareLinkPattern = /(?:https?:\/\/[^\s)]+|\/hospital-bag-cart(?:[?#][^\s)]*)?)/g;
  for (const match of markdown.matchAll(bareLinkPattern)) {
    const href = match[0]?.trim();
    if (href && isHospitalBagCartHref(href)) hrefs.add(href);
  }
  return Array.from(hrefs).slice(0, 1);
}

function requestOpenHospitalBagCart(event: MouseEvent<HTMLAnchorElement>, href: string): void {
  if (!isHospitalBagCartHref(href) || typeof window === "undefined") return;
  const openEvent = new CustomEvent(OPEN_HOSPITAL_BAG_CART_EVENT, {
    cancelable: true,
    detail: { href },
  });
  window.dispatchEvent(openEvent);
  if (openEvent.defaultPrevented) event.preventDefault();
}

function HospitalBagCartLinkPreview({ href }: { href: string }) {
  return (
    <a
      href={resolveChatMarkdownHref(href)}
      target="_blank"
      rel="noopener noreferrer"
      onClick={(event) => requestOpenHospitalBagCart(event, href)}
      className="not-prose mt-2 block overflow-hidden rounded-2xl border border-[#e8d7df] bg-[#fff9fb] shadow-[0_8px_22px_rgba(83,47,64,0.08)] no-underline transition-colors hover:bg-[#fff4f8]"
    >
      <div className="flex items-stretch">
        <div className="flex w-20 shrink-0 items-center justify-center bg-gradient-to-br from-[#24889a] to-[#d86b91] text-white">
          <ShoppingBag className="h-8 w-8" />
        </div>
        <div className="min-w-0 flex-1 px-3 py-3">
          <p className="text-[10px] font-semibold uppercase tracking-[0.12em] text-[#8a6d7a]">Momcozy Cart</p>
          <p className="mt-0.5 text-[13px] font-bold leading-snug text-[#372330]">待产包母婴用品一键打包</p>
          <p className="mt-1 line-clamp-2 text-[11px] leading-snug text-[#725b67]">
            已把妈妈护理、宝宝出院和母乳喂养用品整理成购物车，方便一起核对下单。
          </p>
        </div>
        <div className="flex items-center pr-3 text-[#24889a]">
          <ChevronRight className="h-4 w-4" />
        </div>
      </div>
    </a>
  );
}

/**
 * 将对话正文解析为 Markdown 并安全渲染（默认不执行 HTML）。
 * @param props.markdown Markdown 文本
 * @param props.variant 气泡配色场景
 * @param props.className 可选样式扩展
 * @returns React 元素；markdown 为空字符串时返回 null
 */
export const ChatMarkdown: FC<ChatMarkdownProps> = ({
  markdown,
  variant = "assistant",
  className,
}) => {
  if (!markdown.trim()) return null;
  const markdownForRender = normalizeMarkdownLineBreaks(linkifyBareSkillAssetUrlsForMarkdown(markdown));
  const hospitalBagCartPreviewHrefs = extractHospitalBagCartPreviewHrefs(markdown);

  return (
    <div className={cn("overflow-x-auto text-[13px] leading-relaxed", markdownBubbleProseClass(variant), className)}>
      <ReactMarkdown
        remarkPlugins={[remarkGfm, remarkBreaks]}
        components={{
          a: ({ children, href, ...props }) => {
            if (isProbablyImageHref(href)) {
              return (
                <ChatMarkdownImg
                  resolvedSrc={resolveChatMarkdownImageSrc(href)}
                  alt={linkLabelForImageAlt(children, href ?? "")}
                  className="block my-1"
                />
              );
            }
            return (
              <a
                href={resolveChatMarkdownHref(href)}
                {...props}
                target="_blank"
                rel="noopener noreferrer"
                onClick={(event) => requestOpenHospitalBagCart(event, href ?? "")}
              >
                {children}
              </a>
            );
          },
          img: ({ alt, className: imgClass, src }) => (
            <ChatMarkdownImg resolvedSrc={resolveChatMarkdownImageSrc(src)} alt={alt} className={imgClass} />
          ),
          br: () => <ChatMarkdownLineBreak variant={variant} />,
          table: ({ children, ...props }) => {
            const phaseCardTable = hasBlankTableHeader(children);
            return (
            <div
              className={cn(
                "not-prose my-3 -mx-0.5 max-w-full overflow-x-auto rounded-xl border border-[#ead6dc] bg-[#fff8fa] shadow-[0_8px_20px_rgba(137,72,98,0.06)]",
                phaseCardTable && "birth-journey-card-table-wrap border-0 bg-transparent shadow-none",
              )}
            >
              <table
                {...props}
                className={cn(
                  "min-w-full w-full table-fixed border-collapse text-left text-[13px] leading-relaxed text-[#3f2732]",
                  phaseCardTable && "birth-journey-card-table",
                )}
              >
                {children}
              </table>
            </div>
            );
          },
          thead: ({ children, ...props }) => {
            const headerText = reactChildrenToPlainText(children).trim();
            if (!headerText) {
              return (
                <thead {...props} className="birth-journey-empty-head">
                  {children}
                </thead>
              );
            }
            return <thead {...props}>{children}</thead>;
          },
          th: ({ children, ...props }) => (
            <th
              {...props}
              className="border-b border-[#e5cfd6] bg-[#fff0f4] px-3 py-2.5 align-bottom font-bold leading-snug text-[#4a2635]"
            >
              {renderMarkdownLineBreakTokens(children, variant)}
            </th>
          ),
          td: ({ children, ...props }) => (
            <td
              {...props}
              className="border-t border-[#efdde3] bg-[#fff8fa] px-3 py-3 align-top leading-relaxed text-[#3f2732] first:bg-[#fff0f4]"
            >
              {renderMarkdownLineBreakTokens(children, variant)}
            </td>
          ),
        }}
      >
        {markdownForRender}
      </ReactMarkdown>
      {hospitalBagCartPreviewHrefs.map((href) => (
        <HospitalBagCartLinkPreview key={href} href={href} />
      ))}
    </div>
  );
};
