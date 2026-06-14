import type { ChatMessageCitation } from "@/types/chat";

function citationHost(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, "").toLowerCase();
  } catch {
    return "";
  }
}

function normalizeUrl(url: string): string {
  try {
    const parsed = new URL(url.trim());
    parsed.hash = "";
    return parsed.toString().replace(/\/$/, "");
  } catch {
    return url.trim().replace(/\/$/, "");
  }
}

function citationIndexForUrl(url: string, citations: ChatMessageCitation[]): number | null {
  const normalized = normalizeUrl(url);
  const exact = citations.find((citation) => normalizeUrl(citation.url) === normalized);
  if (exact) return exact.index;

  const host = citationHost(url);
  if (!host) return null;
  const sameHost = citations.filter((citation) => citationHost(citation.url) === host);
  return sameHost.length > 0 ? sameHost[0].index : null;
}

export function replaceCitationLinksWithIndexes(
  markdown: string,
  citations: ChatMessageCitation[] | undefined,
): string {
  if (!markdown || !citations?.length) return markdown;
  const replacedLinks = markdown.replace(
    /\[([^\]]+)\]\((https?:\/\/[^)\s]+)(?:\s+"[^"]*")?\)/g,
    (match, _label: string, url: string) => {
      const index = citationIndexForUrl(url, citations);
      return index == null ? match : `[${index}]`;
    },
  );
  return stripRawWebSearchCitationMarkers(replacedLinks).replace(/[（(]\[(\d+)\][）)]/g, "[$1]");
}

function stripRawWebSearchCitationMarkers(markdown: string): string {
  return markdown
    .replace(/(?:^|\n)[ \t]*(?:cite[ \t]+)?turn\d+search\d+(?:[ \t,]+turn\d+search\d+)*[ \t]*(?=\n|$)/gi, "")
    .replace(/[ \t]*(?:cite[ \t]+)?turn\d+search\d+(?:[ \t,]+turn\d+search\d+)*/gi, "")
    .replace(/(?:\n[ \t]*){3,}/g, "\n\n")
    .replace(/^\n+|\n+$/g, "");
}
