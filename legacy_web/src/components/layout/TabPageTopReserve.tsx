import React from "react";

/**
 * Tab 页顶栏预留（状态栏安全区）；吸乳进度岛悬浮不占用布局高度。
 */
const TabPageTopReserve: React.FC = () => {
  const height = "var(--top-safe)";
  return (
    <div
      className="w-full shrink-0 bg-background"
      style={{ height }}
      aria-hidden
    />
  );
};

export default TabPageTopReserve;
