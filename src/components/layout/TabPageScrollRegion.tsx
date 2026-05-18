import React from "react";

type TabPageScrollRegionProps = {
  children: React.ReactNode;
};

/**
 * Tab 页中间信息显示区：仅此区域纵向滚动；底部略留空，避免贴紧嵌入底栏。
 */
const TabPageScrollRegion: React.FC<TabPageScrollRegionProps> = ({ children }) => (
  <div className="flex-1 min-h-0 overflow-y-auto overscroll-y-contain pb-4">{children}</div>
);

export default TabPageScrollRegion;
