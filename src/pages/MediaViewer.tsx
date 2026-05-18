import { ArrowLeft } from "lucide-react";
import { useLocation, useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { ImageViewer } from "@/components/media/ImageViewer";
import { InlineVideoPlayer } from "@/components/media/InlineVideoPlayer";
import { PdfJsViewer } from "@/components/media/PdfJsViewer";
import type { MediaViewerNavigateState } from "@/lib/openMediaViewer";

/**
 * 全屏查看远程 PDF、视频或图片；依赖路由 `location.state`（url / kind / title）。
 * @returns 媒体查看页
 */
const MediaViewer: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const state = location.state as MediaViewerNavigateState | null;

  const goBack = () => {
    navigate(-1);
  };

  // 与 PumpSession 一致：整层从 var(--top-safe) 起算，避免 fixed 顶到视口最顶端与系统状态栏重叠导致返回无法点击
  const shellClass =
    "fixed left-0 right-0 bottom-0 z-[100] flex flex-col bg-background w-full max-w-lg mx-auto min-h-0";

  if (!state?.url || !state.kind) {
    return (
      <div className={shellClass} style={{ top: "var(--top-safe)" }}>
        <header className="flex items-center gap-2 px-3 py-2.5 border-b border-border shrink-0">
          <Button type="button" variant="ghost" size="icon" onClick={goBack} aria-label="返回">
            <ArrowLeft className="h-5 w-5" />
          </Button>
          <span className="text-sm font-medium">媒体</span>
        </header>
        <p className="flex-1 flex items-center justify-center text-sm text-muted-foreground px-4">缺少资源参数，请从资料卡片进入。</p>
      </div>
    );
  }

  const title = state.title?.trim() || (state.kind === "pdf" ? "PDF" : state.kind === "image" ? "图片" : "视频");

  return (
    <div className={shellClass} style={{ top: "var(--top-safe)" }}>
      <header className="flex items-center gap-2 px-3 py-2.5 border-b border-border shrink-0">
        <Button type="button" variant="ghost" size="icon" onClick={goBack} aria-label="返回">
          <ArrowLeft className="h-5 w-5" />
        </Button>
        <span className="text-sm font-medium truncate flex-1">{title}</span>
      </header>
      <div className="flex-1 min-h-0 overflow-hidden flex flex-col">
        {state.kind === "pdf" ? (
          <PdfJsViewer sourceUrl={state.url} />
        ) : state.kind === "image" ? (
          <ImageViewer sourceUrl={state.url} title={title} />
        ) : (
          <InlineVideoPlayer sourceUrl={state.url} viewerLayout />
        )}
      </div>
    </div>
  );
};

export default MediaViewer;
