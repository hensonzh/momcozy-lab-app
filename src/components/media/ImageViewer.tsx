import { useCallback, useEffect, useLayoutEffect, useRef, useState, type FC, type MouseEvent } from "react";
import { resolveChatImageDisplaySrc } from "@/lib/chatImageDisplaySrc";

const MIN_SCALE = 1;
const MAX_SCALE = 5;
const DOUBLE_TAP_SCALE = 2.5;

type Size = { w: number; h: number };
type Transform = { scale: number; x: number; y: number };

type GestureState =
  | { type: "pan"; startX: number; startY: number; transform: Transform }
  | { type: "pinch"; startDistance: number; anchorX: number; anchorY: number };

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

function touchDistance(a: Touch, b: Touch): number {
  return Math.hypot(b.clientX - a.clientX, b.clientY - a.clientY);
}

function touchMidpoint(a: Touch, b: Touch): { x: number; y: number } {
  return {
    x: (a.clientX + b.clientX) / 2,
    y: (a.clientY + b.clientY) / 2,
  };
}

function fitImage(natural: Size, viewport: Size): Size {
  if (natural.w <= 0 || natural.h <= 0 || viewport.w <= 0 || viewport.h <= 0) return { w: 0, h: 0 };
  const fit = Math.min(viewport.w / natural.w, viewport.h / natural.h, 1);
  return { w: natural.w * fit, h: natural.h * fit };
}

function clampTransform(transform: Transform, viewport: Size, base: Size): Transform {
  if (viewport.w <= 0 || viewport.h <= 0 || base.w <= 0 || base.h <= 0) return transform;

  const scaledW = base.w * transform.scale;
  const scaledH = base.h * transform.scale;
  const baseX = (viewport.w - base.w) / 2;
  const baseY = (viewport.h - base.h) / 2;

  const x =
    scaledW <= viewport.w
      ? 0
      : clamp(transform.x, viewport.w - scaledW - baseX, -baseX);
  const y =
    scaledH <= viewport.h
      ? 0
      : clamp(transform.y, viewport.h - scaledH - baseY, -baseY);

  return { scale: clamp(transform.scale, MIN_SCALE, MAX_SCALE), x, y };
}

interface ImageViewerProps {
  /** 相对或绝对图片 URL */
  sourceUrl: string;
  /** 可选图片标题，用作 alt */
  title?: string;
}

/**
 * 全屏图片查看器：支持双指缩放、放大后拖动和双击放大/还原。
 * @param props.sourceUrl 图片地址
 * @param props.title 图片标题
 */
export const ImageViewer: FC<ImageViewerProps> = ({ sourceUrl, title }) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const gestureRef = useRef<GestureState | null>(null);
  const transformRef = useRef<Transform>({ scale: 1, x: 0, y: 0 });
  const layoutRef = useRef({ viewport: { w: 0, h: 0 }, base: { w: 0, h: 0 } });
  const [natural, setNatural] = useState<Size>({ w: 0, h: 0 });
  const [viewport, setViewport] = useState<Size>({ w: 0, h: 0 });
  const [transform, setTransform] = useState<Transform>({ scale: 1, x: 0, y: 0 });
  const [error, setError] = useState(false);

  const displaySrc = resolveChatImageDisplaySrc(sourceUrl) ?? sourceUrl;
  const base = fitImage(natural, viewport);
  const baseX = (viewport.w - base.w) / 2;
  const baseY = (viewport.h - base.h) / 2;

  layoutRef.current = { viewport, base };
  transformRef.current = transform;

  const setClampedTransform = useCallback((next: Transform) => {
    const { viewport: vp, base: b } = layoutRef.current;
    const clamped = clampTransform(next, vp, b);
    transformRef.current = clamped;
    setTransform(clamped);
  }, []);

  useEffect(() => {
    setNatural({ w: 0, h: 0 });
    setTransform({ scale: 1, x: 0, y: 0 });
    setError(false);
  }, [sourceUrl]);

  useLayoutEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const measure = () => setViewport({ w: el.clientWidth, h: el.clientHeight });
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  useLayoutEffect(() => {
    setClampedTransform(transformRef.current);
  }, [base.w, base.h, setClampedTransform, viewport.w, viewport.h]);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;

    const imagePointFromViewport = (clientX: number, clientY: number) => {
      const rect = el.getBoundingClientRect();
      const { viewport: vp, base: b } = layoutRef.current;
      const t = transformRef.current;
      const localX = clientX - rect.left;
      const localY = clientY - rect.top;
      const bx = (vp.w - b.w) / 2;
      const by = (vp.h - b.h) / 2;
      return {
        x: (localX - bx - t.x) / t.scale,
        y: (localY - by - t.y) / t.scale,
      };
    };

    const transformAroundViewportPoint = (clientX: number, clientY: number, nextScale: number, anchorX: number, anchorY: number) => {
      const rect = el.getBoundingClientRect();
      const { viewport: vp, base: b } = layoutRef.current;
      const localX = clientX - rect.left;
      const localY = clientY - rect.top;
      const bx = (vp.w - b.w) / 2;
      const by = (vp.h - b.h) / 2;
      setClampedTransform({
        scale: nextScale,
        x: localX - bx - anchorX * nextScale,
        y: localY - by - anchorY * nextScale,
      });
    };

    const onTouchStart = (e: TouchEvent) => {
      if (e.touches.length === 2) {
        const mid = touchMidpoint(e.touches[0], e.touches[1]);
        const anchor = imagePointFromViewport(mid.x, mid.y);
        gestureRef.current = {
          type: "pinch",
          startDistance: touchDistance(e.touches[0], e.touches[1]),
          anchorX: anchor.x,
          anchorY: anchor.y,
        };
        return;
      }
      if (e.touches.length === 1) {
        gestureRef.current = {
          type: "pan",
          startX: e.touches[0].clientX,
          startY: e.touches[0].clientY,
          transform: transformRef.current,
        };
      }
    };

    const onTouchMove = (e: TouchEvent) => {
      const gesture = gestureRef.current;
      if (!gesture) return;
      e.preventDefault();

      if (gesture.type === "pinch" && e.touches.length === 2) {
        const distance = touchDistance(e.touches[0], e.touches[1]);
        const scale = clamp(transformRef.current.scale * (distance / gesture.startDistance), MIN_SCALE, MAX_SCALE);
        const mid = touchMidpoint(e.touches[0], e.touches[1]);
        transformAroundViewportPoint(mid.x, mid.y, scale, gesture.anchorX, gesture.anchorY);
        gestureRef.current = { ...gesture, startDistance: distance };
        return;
      }

      if (gesture.type === "pan" && e.touches.length === 1 && transformRef.current.scale > 1) {
        setClampedTransform({
          ...gesture.transform,
          x: gesture.transform.x + e.touches[0].clientX - gesture.startX,
          y: gesture.transform.y + e.touches[0].clientY - gesture.startY,
        });
      }
    };

    const onTouchEnd = (e: TouchEvent) => {
      if (e.touches.length === 1) {
        gestureRef.current = {
          type: "pan",
          startX: e.touches[0].clientX,
          startY: e.touches[0].clientY,
          transform: transformRef.current,
        };
      } else {
        gestureRef.current = null;
      }
    };

    el.addEventListener("touchstart", onTouchStart, { passive: true });
    el.addEventListener("touchmove", onTouchMove, { passive: false });
    el.addEventListener("touchend", onTouchEnd, { passive: true });
    el.addEventListener("touchcancel", onTouchEnd, { passive: true });
    return () => {
      el.removeEventListener("touchstart", onTouchStart);
      el.removeEventListener("touchmove", onTouchMove);
      el.removeEventListener("touchend", onTouchEnd);
      el.removeEventListener("touchcancel", onTouchEnd);
    };
  }, [setClampedTransform]);

  const beginMousePan = (e: MouseEvent<HTMLDivElement>) => {
    if (transform.scale <= 1) return;
    e.preventDefault();
    gestureRef.current = {
      type: "pan",
      startX: e.clientX,
      startY: e.clientY,
      transform,
    };
  };

  const moveMousePan = (e: MouseEvent<HTMLDivElement>) => {
    const gesture = gestureRef.current;
    if (gesture?.type !== "pan" || transformRef.current.scale <= 1 || e.buttons !== 1) return;
    setClampedTransform({
      ...gesture.transform,
      x: gesture.transform.x + e.clientX - gesture.startX,
      y: gesture.transform.y + e.clientY - gesture.startY,
    });
  };

  const toggleZoom = (e: MouseEvent<HTMLDivElement>) => {
    if (transform.scale > 1) {
      setClampedTransform({ scale: 1, x: 0, y: 0 });
      return;
    }

    const rect = e.currentTarget.getBoundingClientRect();
    const anchorX = e.clientX - rect.left - baseX;
    const anchorY = e.clientY - rect.top - baseY;
    setClampedTransform({
      scale: DOUBLE_TAP_SCALE,
      x: e.clientX - rect.left - baseX - anchorX * DOUBLE_TAP_SCALE,
      y: e.clientY - rect.top - baseY - anchorY * DOUBLE_TAP_SCALE,
    });
  };

  if (error) {
    return <p className="text-center text-destructive px-4 text-sm">图片加载失败</p>;
  }

  return (
    <div
      ref={containerRef}
      className="relative flex-1 min-h-0 w-full overflow-hidden bg-black select-none"
      style={{ touchAction: "none", WebkitUserSelect: "none", userSelect: "none" }}
      onMouseDown={beginMousePan}
      onMouseMove={moveMousePan}
      onMouseUp={() => (gestureRef.current = null)}
      onMouseLeave={() => (gestureRef.current = null)}
      onDoubleClick={toggleZoom}
    >
      {!natural.w && <p className="absolute inset-0 flex items-center justify-center text-sm text-white/70">加载图片…</p>}
      <img
        src={displaySrc}
        alt={title ?? ""}
        draggable={false}
        className="absolute max-w-none rounded-sm"
        style={{
          width: base.w || undefined,
          height: base.h || undefined,
          transform: `translate(${baseX + transform.x}px, ${baseY + transform.y}px) scale(${transform.scale})`,
          transformOrigin: "top left",
          cursor: transform.scale > 1 ? "grab" : "zoom-in",
          visibility: natural.w ? "visible" : "hidden",
        }}
        onLoad={(e) => {
          setNatural({
            w: e.currentTarget.naturalWidth,
            h: e.currentTarget.naturalHeight,
          });
        }}
        onError={() => setError(true)}
      />
    </div>
  );
};
