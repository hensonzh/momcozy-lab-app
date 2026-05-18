import React from "react";
import BottomNav from "./BottomNav";

/**
 * Tab 页底部导航：嵌入列布局（不 fixed），不参与中间区域滚动。
 */
const TabPageEmbeddedNav: React.FC = () => <BottomNav variant="embedded" />;

export default TabPageEmbeddedNav;
