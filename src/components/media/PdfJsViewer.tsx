import { useCallback, useEffect, useLayoutEffect, useRef, useState, type MutableRefObject } from "react";
import { getDocument, GlobalWorkerOptions, type PDFDocumentProxy, type PDFPageProxy, type RenderTask } from "pdfjs-dist";
import pdfWorker from "pdfjs-dist/build/pdf.worker.min.mjs?url";
import { requestBinary } from "@/lib/http";

GlobalWorkerOptions.workerSrc = pdfWorker;

/** 捏合缩放下限：1 表示与「适配屏宽」一致 */
const MIN_PINCH_ZOOM = 1;
/** 捏合缩放上限（再大仅靠 CSS 放大，文字会略糊） */
const MAX_PINCH_ZOOM = 4;

/**
 * 计算两个触摸点之间的像素距离。
 * @param a 第一个触点
 * @param b 第二个触点
 * @returns 欧氏距离
 */
function touchDistance(a: Touch, b: Touch): number {
  return Math.hypot(b.clientX - a.clientX, b.clientY - a.clientY);
}

/** 供捏合计算使用的布局快照（未缩放内容尺寸 + 滚动视口内可用宽高） */
type PinchLayoutSnapshot = { wc: number; hc: number; vw: number; vh: number };

/** 捏合后待同步的锚点（未缩放内容坐标 u,v + 触点相对视口的 vx,vy） */
type PendingPinchScroll = { u: number; v: number; vx: number; vy: number };

/**
 * 将滚动偏移限制在 [0, max]。
 * @param value 目标 scrollLeft / scrollTop
 * @param max 最大可滚动距离
 * @returns 钳制后的值
 */
function clampScroll(value: number, max: number): number {
  return Math.min(Math.max(0, value), max);
}

/**
 * 在滚动容器上绑定双指捏合缩放：按捏合起点比例得到目标 zoom，并以双指中心为锚点修正 scroll，避免整页漂移。
 * @param scrollEl 可滚动元素（overflow: auto）
 * @param zoomRef 与 React 中 zoom state 同步的 ref
 * @param setZoom 更新缩放
 * @param min 最小缩放
 * @param max 最大缩放
 * @param getLayout 读取当前未缩放内容宽高与视口可用宽高（与轨道居中公式一致）
 * @param pendingScrollRef 写入锚点；由外层 useLayoutEffect 在布局后写 scroll，避免滚动锚定抢 scrollTop
 * @returns 移除事件监听的清理函数
 */
function bindPinchZoom(
  scrollEl: HTMLElement,
  zoomRef: MutableRefObject<number>,
  setZoom: (z: number) => void,
  min: number,
  max: number,
  getLayout: () => PinchLayoutSnapshot,
  pendingScrollRef: MutableRefObject<PendingPinchScroll | null>,
): () => void {
  let pinchStartDist = 0;
  let pinchStartZoom = 1;
  const clampZ = (z: number) => Math.min(max, Math.max(min, z));

  const onTouchStart = (e: TouchEvent) => {
    if (e.touches.length === 2) {
      pinchStartDist = touchDistance(e.touches[0], e.touches[1]);
      pinchStartZoom = zoomRef.current;
    }
  };

  const onTouchMove = (e: TouchEvent) => {
    if (e.touches.length !== 2 || pinchStartDist <= 0) return;
    e.preventDefault();
    const d = touchDistance(e.touches[0], e.touches[1]);
    const z1 = clampZ(pinchStartZoom * (d / pinchStartDist));
    const z0 = zoomRef.current;
    // 与当前 zoom 无变化时勿写 pending，否则 setState 可能跳过渲染、布局回调不会清空 ref
    if (Math.abs(z1 - z0) < 1e-6) return;

    const { wc, hc, vw, vh } = getLayout();

    // 尚未完成测量时仅更新缩放，避免除零
    if (wc <= 0 || hc <= 0 || vw <= 0 || vh <= 0) {
      pendingScrollRef.current = null;
      zoomRef.current = z1;
      setZoom(z1);
      return;
    }

    const midX = (e.touches[0].clientX + e.touches[1].clientX) / 2;
    const midY = (e.touches[0].clientY + e.touches[1].clientY) / 2;
    const rect = scrollEl.getBoundingClientRect();
    const cs = getComputedStyle(scrollEl);
    const pl = parseFloat(cs.paddingLeft) || 0;
    const pt = parseFloat(cs.paddingTop) || 0;
    // 相对「可滚动内容区」左上角，与 scrollLeft/scrollTop 累加一致（clientLeft/Top 为边框宽）
    const vx = midX - rect.left - scrollEl.clientLeft - pl;
    const vy = midY - rect.top - scrollEl.clientTop - pt;

    // 轨道尺寸：与 pinchLayoutRef / 下方轨道 JSX 一致（内容区宽高，不含滚动条）
    const TW0 = Math.max(vw, wc * z0);
    const L0 = (TW0 - wc * z0) / 2;

    const docX = scrollEl.scrollLeft + vx;
    const docY = scrollEl.scrollTop + vy;
    // 以 spacer 左上角为原点、未缩放内容坐标系下的锚点（垂直方向贴顶对齐）
    const u = (docX - L0) / z0;
    const v = docY / z0;

    pendingScrollRef.current = { u, v, vx, vy };
    zoomRef.current = z1;
    setZoom(z1);
  };

  const onTouchEndOrCancel = (e: TouchEvent) => {
    if (e.touches.length < 2) pinchStartDist = 0;
  };

  scrollEl.addEventListener("touchstart", onTouchStart, { passive: true });
  scrollEl.addEventListener("touchmove", onTouchMove, { passive: false });
  scrollEl.addEventListener("touchend", onTouchEndOrCancel, { passive: true });
  scrollEl.addEventListener("touchcancel", onTouchEndOrCancel, { passive: true });

  return () => {
    scrollEl.removeEventListener("touchstart", onTouchStart);
    scrollEl.removeEventListener("touchmove", onTouchMove);
    scrollEl.removeEventListener("touchend", onTouchEndOrCancel);
    scrollEl.removeEventListener("touchcancel", onTouchEndOrCancel);
  };
}

interface PdfJsViewerProps {
  /** 相对或绝对 GET URL（与 `requestBinary` 解析规则一致） */
  sourceUrl: string;
}

/**
 * 单页 PDF 画布：按屏宽缩放并支持高分屏。
 * @param props.pdf 已加载的文档
 * @param props.pageNumber 页码（从 1 起）
 */
const PdfPageCanvas: React.FC<{ pdf: PDFDocumentProxy; pageNumber: number }> = ({ pdf, pageNumber }) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    let cancelled = false;
    let page: PDFPageProxy | null = null;
    let renderTask: RenderTask | null = null;

    const paint = async () => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      const p = await pdf.getPage(pageNumber);
      if (cancelled) {
        void p.cleanup();
        return;
      }
      page = p;
      const base = p.getViewport({ scale: 1 });
      const dpr = typeof window !== "undefined" ? window.devicePixelRatio || 1 : 1;
      const maxCssW = typeof window !== "undefined" ? Math.min(window.innerWidth - 24, base.width) : base.width;
      const scale = (maxCssW / base.width) * dpr;
      const viewport = p.getViewport({ scale });
      const ctx = canvas.getContext("2d");
      if (!ctx) return;
      canvas.width = viewport.width;
      canvas.height = viewport.height;
      canvas.style.width = `${viewport.width / dpr}px`;
      canvas.style.height = `${viewport.height / dpr}px`;
      const rt = p.render({ canvasContext: ctx, viewport });
      renderTask = rt;
      await rt.promise.catch(() => undefined);
    };

    void paint();
    return () => {
      cancelled = true;
      try {
        renderTask?.cancel();
      } catch {
        /* ignore */
      }
      void page?.cleanup();
    };
  }, [pdf, pageNumber]);

  return <canvas ref={canvasRef} className="max-w-full shadow-md rounded bg-white" />;
};

/**
 * 使用 pdf.js 拉取远程 PDF 并分页渲染。
 * @param props.sourceUrl 资源地址
 */
export const PdfJsViewer: React.FC<PdfJsViewerProps> = ({ sourceUrl }) => {
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [pdf, setPdf] = useState<PDFDocumentProxy | null>(null);
  const [zoom, setZoom] = useState(1);
  const [contentBox, setContentBox] = useState({ w: 0, h: 0 });
  const [viewportBox, setViewportBox] = useState({ vw: 0, vh: 0 });
  const docRef = useRef<PDFDocumentProxy | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);
  const pinchLayoutRef = useRef<PinchLayoutSnapshot>({ wc: 0, hc: 0, vw: 0, vh: 0 });
  const pendingPinchScrollRef = useRef<PendingPinchScroll | null>(null);
  const zoomRef = useRef(1);
  zoomRef.current = zoom;

  const releaseDoc = useCallback(() => {
    const d = docRef.current;
    docRef.current = null;
    if (d) void d.destroy().catch(() => undefined);
  }, []);

  // 切换文档时恢复默认缩放，避免沿用上一次的放大倍数
  useEffect(() => {
    pendingPinchScrollRef.current = null;
    setZoom(1);
  }, [sourceUrl]);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    setError(null);
    releaseDoc();
    setPdf(null);

    (async () => {
      try {
        const buf = await requestBinary(sourceUrl);
        if (!alive) return;
        const task = getDocument({ data: buf });
        const doc = await task.promise;
        if (!alive) {
          await doc.destroy().catch(() => undefined);
          return;
        }
        docRef.current = doc;
        setPdf(doc);
      } catch (e) {
        if (alive) setError(e instanceof Error ? e.message : "加载 PDF 失败");
      } finally {
        if (alive) setLoading(false);
      }
    })();

    return () => {
      alive = false;
      releaseDoc();
    };
  }, [sourceUrl, releaseDoc]);

  // 测量未应用 transform 时的内容宽高，用于撑开可滚动区域（transform 不参与布局）
  useLayoutEffect(() => {
    const el = contentRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => {
      setContentBox({ w: el.offsetWidth, h: el.offsetHeight });
    });
    ro.observe(el);
    setContentBox({ w: el.offsetWidth, h: el.offsetHeight });
    return () => ro.disconnect();
  }, [pdf]);

  // 滚动视口内「可内容区」尺寸，用于轨道宽度 max(vw, wc*zoom) 与捏合锚点公式
  useLayoutEffect(() => {
    const el = scrollRef.current;
    if (!el || !pdf) return;
    const measure = () => {
      const cs = getComputedStyle(el);
      const pl = parseFloat(cs.paddingLeft) || 0;
      const pr = parseFloat(cs.paddingRight) || 0;
      const pt = parseFloat(cs.paddingTop) || 0;
      const pb = parseFloat(cs.paddingBottom) || 0;
      setViewportBox({
        vw: Math.max(0, el.clientWidth - pl - pr),
        vh: Math.max(0, el.clientHeight - pt - pb),
      });
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, [pdf]);

  // 双指捏合缩放（双指时 preventDefault，避免与部分 WebView 整页缩放冲突）
  useEffect(() => {
    const el = scrollRef.current;
    if (!el || !pdf) return;
    return bindPinchZoom(
      el,
      zoomRef,
      setZoom,
      MIN_PINCH_ZOOM,
      MAX_PINCH_ZOOM,
      () => pinchLayoutRef.current,
      pendingPinchScrollRef,
    );
  }, [pdf]);

  // zoom 变更后立刻同步 scroll，并用真实 scrollWidth/Height 钳制，避免与浏览器滚动锚定打架
  useLayoutEffect(() => {
    const el = scrollRef.current;
    const p = pendingPinchScrollRef.current;
    if (!el || !p) return;
    const { wc, hc, vw, vh } = pinchLayoutRef.current;
    if (wc <= 0 || hc <= 0 || vw <= 0 || vh <= 0) {
      pendingPinchScrollRef.current = null;
      return;
    }
    const z1 = zoom;
    const TW1 = Math.max(vw, wc * z1);
    const L1 = (TW1 - wc * z1) / 2;
    const newSL = L1 + p.u * z1 - p.vx;
    const newST = p.v * z1 - p.vy;
    const maxSL = Math.max(0, el.scrollWidth - el.clientWidth);
    const maxST = Math.max(0, el.scrollHeight - el.clientHeight);
    el.scrollLeft = clampScroll(newSL, maxSL);
    el.scrollTop = clampScroll(newST, maxST);
    pendingPinchScrollRef.current = null;
  }, [zoom]);

  if (loading) {
    return <p className="text-center text-muted-foreground py-10 text-sm">加载 PDF…</p>;
  }
  if (error) {
    return <p className="text-center text-destructive px-4 text-sm">{error}</p>;
  }
  if (!pdf) return null;

  const n = pdf.numPages;
  const wc = contentBox.w;
  const hc = contentBox.h;
  const vw = viewportBox.vw;
  const vh = viewportBox.vh;
  pinchLayoutRef.current = { wc, hc, vw, vh };

  const spacerW = wc > 0 ? wc * zoom : 0;
  const spacerH = hc > 0 ? hc * zoom : 0;
  const trackW = vw > 0 ? Math.max(vw, spacerW) : spacerW;
  // 与 bindPinchZoom 中 TH = max(vh, hc*z) 一致，避免短页时垂直锚点与 DOM 可滚动高度不一致
  const trackH = spacerH > 0 ? Math.max(spacerH, vh > 0 ? vh : 0) : undefined;
  const spacerLeft = trackW > 0 && spacerW > 0 ? (trackW - spacerW) / 2 : 0;

  return (
    <div
      ref={scrollRef}
      className="overflow-auto flex-1 min-h-0 w-full px-2 pb-10 select-none"
      style={{
        WebkitUserSelect: "none",
        userSelect: "none",
        overflowAnchor: "none",
      }}
    >
      {/* 固定用「轨道宽 + 绝对定位 left」居中，避免 mx-auto 随 zoom 变宽时把整页甩到一侧 */}
      <div
        className="relative min-w-full"
        style={{
          width: trackW > 0 ? `${trackW}px` : "100%",
          minHeight: trackH,
        }}
      >
        <div
          className="absolute top-0"
          style={{
            left: spacerLeft,
            width: spacerW > 0 ? spacerW : undefined,
            height: spacerH > 0 ? spacerH : undefined,
          }}
        >
          <div
            ref={contentRef}
            className="flex flex-col items-center gap-4 w-max"
            style={{ transform: `scale(${zoom})`, transformOrigin: "top left" }}
          >
            {Array.from({ length: n }, (_, i) => (
              <PdfPageCanvas key={i + 1} pdf={pdf} pageNumber={i + 1} />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};
