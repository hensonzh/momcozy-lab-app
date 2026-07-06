import { type RefObject, useCallback, useEffect, useRef, useState } from "react";
import { Capacitor } from "@capacitor/core";
import { Maximize2, X } from "lucide-react";
import { resolveVideoElementSrc } from "@/lib/mediaUrlResolve";
import { requestBinary } from "@/lib/http";
import { deleteMediaCacheFile, writeArrayBufferToMediaCache } from "@/lib/mediaCache";
import { readVisualViewportSize, shouldSuggestRotationForImmersive } from "@/lib/videoImmersiveLayout";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { cn } from "@/lib/utils";

interface InlineVideoPlayerProps {
  /** 远程视频绝对或相对 URL */
  sourceUrl: string;
  /**
   * 查看器模式：显示「全屏播放」；并劫持控件栏自带全屏键（Fullscreen API）切换应用内沉浸式。
   * @default false
   */
  viewerLayout?: boolean;
}

interface ImmersiveStageProps {
  /** 是否对视频外包一层旋转 90° 的容器 */
  rotate: boolean;
  /** 当前视口宽高（与旋转容器尺寸一致） */
  viewport: { width: number; height: number };
  /** 透传给 `<video>` 的共有属性 */
  videoProps: React.VideoHTMLAttributes<HTMLVideoElement>;
  /** 绑定到 `<video>`，用于与系统全屏 API 对齐（劫持自带全屏键） */
  videoRef: RefObject<HTMLVideoElement | null>;
}

/**
 * 沉浸式视频舞台：无旋转时 `object-contain` 铺满可用区域；旋转时用 `width=视口高、height=视口宽` 再 `rotate(90deg)` 使片源长边对齐设备长边。
 * 中间层结构固定，仅在样式上切换旋转，避免 metadata 到达后改结构导致 `<video>` 重挂载、播放中断。
 * @param props.rotate 是否启用旋转布局
 * @param props.viewport 视口尺寸
 * @param props.videoProps video 标签属性
 * @returns 舞台区域 JSX
 */
function ImmersiveVideoStage({ rotate, viewport, videoProps, videoRef }: ImmersiveStageProps) {
  const rotatorStyle: React.CSSProperties =
    rotate && viewport.width > 0 && viewport.height > 0
      ? { width: viewport.height, height: viewport.width, transform: "rotate(90deg)" }
      : { width: "100%", height: "100%", transform: "none" };

  return (
    <div className="flex h-full w-full items-center justify-center overflow-hidden bg-black">
      <div className="flex shrink-0 items-center justify-center" style={rotatorStyle}>
        <video ref={videoRef} {...videoProps} className="h-full w-full max-h-full max-w-full bg-black object-contain" />
      </div>
    </div>
  );
}

/**
 * 应用内视频：优先使用与图片相同的 `_capacitor_http_interceptor_` 同源 URL（原生 HTTP 混合内容场景），
 * 以便由 WebView/本地桥尝试流式/Range；若 `<video>` 触发 `error` 则降级为整包 GET 后写入 Cache（原生）或 Blob URL（Web）。
 * @param props.sourceUrl 媒体地址
 * @param props.viewerLayout 是否启用查看器全屏适配（媒体页建议 true）
 */
export const InlineVideoPlayer: React.FC<InlineVideoPlayerProps> = ({ sourceUrl, viewerLayout = false }) => {
  const trimmed = sourceUrl.trim();
  const [src, setSrc] = useState<string>(() => resolveVideoElementSrc(trimmed));
  const [hint, setHint] = useState<string | null>(null);
  const [fatal, setFatal] = useState<string | null>(null);
  const [buffering, setBuffering] = useState(false);
  /** 整包下载降级时的进度（Web 常有 total；原生整包请求多为 null 总长度） */
  const [downloadProgress, setDownloadProgress] = useState<{ loaded: number; total: number | null } | null>(null);
  const [immersive, setImmersive] = useState(false);
  /** 片源像素尺寸，来自 `loadedmetadata` */
  const [naturalSize, setNaturalSize] = useState<{ w: number; h: number } | null>(null);
  const [viewport, setViewport] = useState(readVisualViewportSize);

  const blobUrlRef = useRef<string | null>(null);
  const cachePathRef = useRef<string | null>(null);
  const fallbackDoneRef = useRef(false); // 仅允许一次直连失败后的整包降级，避免 error 循环
  /** 整包下载尚未结束时为 true；此期间再次点播放仍会触发同一失败 URL 的 error，需忽略以免误判致命失败 */
  const fallbackDownloadingRef = useRef(false);
  const progressRafRef = useRef<number | null>(null);
  const progressPendingRef = useRef<{ loaded: number; total: number | null } | null>(null);
  /** 当前挂载的 `<video>`，用于识别系统全屏是否作用在本播放器上 */
  const videoRef = useRef<HTMLVideoElement | null>(null);
  /** 防止 `fullscreenchange` 与 `webkitfullscreenchange` 同一次点击触发两次切换 */
  const fullscreenHijackRef = useRef(false);

  /** 将 onProgress 合并到下一帧刷新，避免小块流式回调打爆 React 渲染 */
  const scheduleProgressUpdate = useCallback((loaded: number, total: number | null) => {
    progressPendingRef.current = { loaded, total };
    if (progressRafRef.current != null) return;
    progressRafRef.current = requestAnimationFrame(() => {
      progressRafRef.current = null;
      const p = progressPendingRef.current;
      if (p) setDownloadProgress({ loaded: p.loaded, total: p.total });
    });
  }, []);

  const cleanupTransientSrc = useCallback(() => {
    if (blobUrlRef.current) {
      URL.revokeObjectURL(blobUrlRef.current);
      blobUrlRef.current = null;
    }
    const p = cachePathRef.current;
    if (p) {
      cachePathRef.current = null;
      void deleteMediaCacheFile(p);
    }
  }, []);

  useEffect(() => {
    fallbackDoneRef.current = false;
    setSrc(resolveVideoElementSrc(trimmed));
    setHint(null);
    setFatal(null);
    setBuffering(false);
    setDownloadProgress(null);
    setNaturalSize(null);
    setImmersive(false);
    progressPendingRef.current = null;
    if (progressRafRef.current != null) {
      cancelAnimationFrame(progressRafRef.current);
      progressRafRef.current = null;
    }
    cleanupTransientSrc();
  }, [trimmed, cleanupTransientSrc]);

  useEffect(() => () => cleanupTransientSrc(), [cleanupTransientSrc]);

  useEffect(
    () => () => {
      if (progressRafRef.current != null) cancelAnimationFrame(progressRafRef.current);
    },
    [],
  );

  /** 视口变化时更新，用于沉浸式下旋转容器尺寸与横竖判断 */
  useEffect(() => {
    const sync = () => setViewport(readVisualViewportSize());
    sync();
    window.addEventListener("resize", sync);
    window.visualViewport?.addEventListener("resize", sync);
    window.visualViewport?.addEventListener("scroll", sync);
    return () => {
      window.removeEventListener("resize", sync);
      window.visualViewport?.removeEventListener("resize", sync);
      window.visualViewport?.removeEventListener("scroll", sync);
    };
  }, []);

  /** 沉浸式时禁止底层滚动；Esc 退出（桌面/Web） */
  useEffect(() => {
    if (!immersive) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setImmersive(false);
    };
    window.addEventListener("keydown", onKey);
    return () => {
      document.body.style.overflow = prev;
      window.removeEventListener("keydown", onKey);
    };
  }, [immersive]);

  /**
   * 将控件栏自带「全屏」转为应用内沉浸式：浏览器会先对 `<video>` 调 Fullscreen API，
   * 我们在 `fullscreenchange` 里立刻退出系统全屏并切换 `immersive`，避免与自定义旋转/contain 布局冲突。
   * iOS 部分内联播放走 `webkitEnterFullscreen` 且不经过 document 全屏时无法劫持，仍可点顶部「全屏播放」。
   */
  useEffect(() => {
    if (!viewerLayout) return;

    type DocFs = Document & {
      webkitFullscreenElement?: Element | null;
      exitFullscreen?: () => Promise<void>;
      webkitExitFullscreen?: () => void;
    };

    const getFullscreenElement = (): Element | null => {
      const d = document as DocFs;
      return d.fullscreenElement ?? d.webkitFullscreenElement ?? null;
    };

    const exitFullscreenCompat = (): Promise<void> => {
      const d = document as DocFs;
      if (typeof d.exitFullscreen === "function") return d.exitFullscreen().catch(() => {});
      if (typeof d.webkitExitFullscreen === "function") {
        d.webkitExitFullscreen();
        return Promise.resolve();
      }
      return Promise.resolve();
    };

    const onFullscreenChange = () => {
      const el = getFullscreenElement();
      const vid = videoRef.current;
      if (!vid || el !== vid) return;
      if (fullscreenHijackRef.current) return;
      fullscreenHijackRef.current = true;
      void exitFullscreenCompat().finally(() => {
        setImmersive((prev) => !prev);
        queueMicrotask(() => {
          fullscreenHijackRef.current = false;
        });
      });
    };

    document.addEventListener("fullscreenchange", onFullscreenChange);
    document.addEventListener("webkitfullscreenchange", onFullscreenChange);
    return () => {
      document.removeEventListener("fullscreenchange", onFullscreenChange);
      document.removeEventListener("webkitfullscreenchange", onFullscreenChange);
    };
  }, [viewerLayout]);

  const pickVideoExt = (url: string): string => {
    const base = url.split("?")[0].toLowerCase();
    if (base.endsWith(".webm")) return "webm";
    return "mp4";
  };

  const handleVideoError = useCallback(async () => {
    if (fallbackDownloadingRef.current) return;
    if (fallbackDoneRef.current) {
      setFatal("无法播放该视频");
      return;
    }
    fallbackDoneRef.current = true;
    fallbackDownloadingRef.current = true;
    setBuffering(true);
    setHint(null);
    setDownloadProgress({ loaded: 0, total: null });
    try {
      const buf = await requestBinary(trimmed, {
        onProgress: (loaded, total) => scheduleProgressUpdate(loaded, total),
      });
      // 确保最后一帧进度在取消 rAF 前落到 100%（避免 finally 里 cancel 掉未执行的 requestAnimationFrame）
      setDownloadProgress({ loaded: buf.byteLength, total: buf.byteLength });
      const ext = pickVideoExt(trimmed);
      const mime = ext === "webm" ? "video/webm" : "video/mp4";
      if (Capacitor.isNativePlatform()) {
        const { webSrc, relativePath } = await writeArrayBufferToMediaCache(buf, ext);
        cachePathRef.current = relativePath;
        setSrc(webSrc);
      } else {
        const blob = new Blob([buf], { type: mime });
        const u = URL.createObjectURL(blob);
        blobUrlRef.current = u;
        setSrc(u);
      }
      setHint(null);
    } catch (e) {
      setFatal(e instanceof Error ? e.message : "视频加载失败");
      setHint(null);
    } finally {
      fallbackDownloadingRef.current = false;
      setBuffering(false);
      setDownloadProgress(null);
      progressPendingRef.current = null;
      if (progressRafRef.current != null) {
        cancelAnimationFrame(progressRafRef.current);
        progressRafRef.current = null;
      }
    }
  }, [trimmed, scheduleProgressUpdate]);

  /** 记录片源分辨率，供全屏适配与旋转判断 */
  const handleLoadedMetadata = useCallback((e: React.SyntheticEvent<HTMLVideoElement>) => {
    const v = e.currentTarget;
    if (v.videoWidth > 0 && v.videoHeight > 0) {
      setNaturalSize({ w: v.videoWidth, h: v.videoHeight });
    }
  }, []);

  const pct =
    downloadProgress != null &&
    downloadProgress.total != null &&
    downloadProgress.total > 0
      ? Math.min(100, Math.round((downloadProgress.loaded / downloadProgress.total) * 100))
      : null;

  const rotateImmersive =
    immersive &&
    naturalSize != null &&
    shouldSuggestRotationForImmersive(naturalSize.w, naturalSize.h, viewport.width, viewport.height);

  const videoCommonProps: React.VideoHTMLAttributes<HTMLVideoElement> = {
    src,
    controls: true,
    playsInline: true,
    preload: "metadata",
    onLoadedMetadata: handleLoadedMetadata,
    onError: () => void handleVideoError(),
  };

  return (
    <div
      className={cn(
        "flex w-full min-h-0 flex-col items-center justify-center",
        immersive ? "fixed inset-0 z-[280] bg-black p-0" : "flex-1 p-2",
      )}
    >
      {!immersive && buffering && !downloadProgress && <p className="mb-2 text-xs text-muted-foreground">缓冲中…</p>}
      {!immersive && downloadProgress != null && !fatal ? (
        <div className="mb-3 w-full max-w-[min(100%,22rem)] space-y-1.5 px-1">
          <p className="text-center text-[11px] leading-snug text-muted-foreground">
            直连播放失败，正在下载后重试
            {pct != null ? `（${pct}%）` : "（下载中…）"}
          </p>
          {pct != null ? (
            <Progress className="h-2" value={pct} />
          ) : (
            <div className="h-2 w-full overflow-hidden rounded-full bg-secondary">
              <div className="h-full w-full animate-pulse rounded-full bg-primary/45" />
            </div>
          )}
        </div>
      ) : null}
      {!immersive && hint && !fatal && <p className="mb-2 text-xs text-muted-foreground">{hint}</p>}
      {fatal && <p className="px-4 text-center text-sm text-destructive">{fatal}</p>}

      {!fatal && viewerLayout && !immersive && (
        <Button
          type="button"
          variant="secondary"
          size="sm"
          className="mb-2 shrink-0 gap-1.5"
          onClick={() => setImmersive(true)}
        >
          <Maximize2 className="h-4 w-4" aria-hidden />
          全屏播放
        </Button>
      )}

      {!fatal && immersive && (
        <Button
          type="button"
          variant="ghost"
          size="icon"
          className="absolute z-10 rounded-full bg-black/50 text-white hover:bg-black/70 hover:text-white"
          style={{
            top: "calc(0.5rem + env(safe-area-inset-top, 0px))",
            right: "calc(0.5rem + env(safe-area-inset-right, 0px))",
          }}
          onClick={() => setImmersive(false)}
          aria-label="退出全屏"
        >
          <X className="h-5 w-5" />
        </Button>
      )}

      {!fatal && (
        <div
          className={cn(
            "flex w-full min-h-0 items-center justify-center",
            immersive ? "relative flex-1" : "flex-1",
          )}
        >
          {immersive ? (
            <ImmersiveVideoStage
              key={src}
              rotate={!!rotateImmersive}
              viewport={viewport}
              videoProps={videoCommonProps}
              videoRef={videoRef}
            />
          ) : (
            <video
              key={src}
              ref={videoRef}
              {...videoCommonProps}
              className="max-h-[min(72vh,100%)] w-full rounded-lg bg-black object-contain"
            />
          )}
        </div>
      )}
    </div>
  );
};
