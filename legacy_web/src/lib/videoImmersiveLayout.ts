/**
 * 判断沉浸式全屏时是否建议将视频旋转 90°。
 * 横屏片源在竖屏视口（或竖屏片源在横屏视口）时，旋转后可用视口长边对齐片源长边，显著减少黑边。
 *
 * @param videoW `<video>.videoWidth`
 * @param videoH `<video>.videoHeight`
 * @param screenW 视口宽度（如 `window.innerWidth`）
 * @param screenH 视口高度（如 `window.innerHeight`）
 * @returns 为 true 时在容器内对视频外包一层 `rotate(90deg)` 布局
 */
export function shouldSuggestRotationForImmersive(
  videoW: number,
  videoH: number,
  screenW: number,
  screenH: number,
): boolean {
  if (videoW <= 0 || videoH <= 0 || screenW <= 0 || screenH <= 0) return false;
  const videoLandscape = videoW > videoH;
  const videoPortrait = videoH > videoW;
  const screenLandscape = screenW > screenH;
  const screenPortrait = screenH > screenW;
  if (videoLandscape && screenPortrait) return true;
  if (videoPortrait && screenLandscape) return true;
  return false;
}

/**
 * 读取当前浏览器视口宽高（含 `visualViewport` 时优先，利于移动端地址栏伸缩）。
 *
 * @returns `{ width, height }` 像素值
 */
export function readVisualViewportSize(): { width: number; height: number } {
  if (typeof window === "undefined") return { width: 0, height: 0 };
  const vv = window.visualViewport;
  if (vv && vv.width > 0 && vv.height > 0) {
    return { width: vv.width, height: vv.height };
  }
  return { width: window.innerWidth, height: window.innerHeight };
}
