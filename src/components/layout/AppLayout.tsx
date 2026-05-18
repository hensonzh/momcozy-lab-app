import React from "react";
import { useLocation } from "react-router-dom";
import BottomNav from "./BottomNav";
import { isTabShellPath } from "./tabShellRoutes";

interface AppLayoutProps {
  children: React.ReactNode;
}

/**
 * 应用外壳：顶栏安全区、主内容区、底部导航。
 * @param children 各路由页面内容
 */
const AppLayout: React.FC<AppLayoutProps> = ({ children }) => {
  const location = useLocation();
  const path = location.pathname;
  const tabShellOwnsChrome = isTabShellPath(path);

  /** 仅状态栏安全区；进度岛为悬浮层，不顶开正文。 */
  const topReserveHeightCss = "var(--top-safe)";

  const showVersionFooter =
    path !== "/" &&
    path !== "/media-viewer" &&
    !tabShellOwnsChrome;

  return (
    <div className="min-h-screen max-w-lg mx-auto relative flex flex-col bg-background">
      {/* 用 padding-top 代替独立顶条，避免 edge-to-edge 下出现「多一条」浅色顶带 */}
      <div
        className="relative flex min-h-0 flex-1 flex-col bg-background box-border"
        style={
          tabShellOwnsChrome
            ? { minHeight: "100vh" }
            : {
                paddingTop: topReserveHeightCss,
                minHeight: "100vh",
              }
        }
      >
        <main className={tabShellOwnsChrome ? "pb-0" : "pb-20"}>
          {children}
          {showVersionFooter && (
            <p className="text-center text-[9px] text-muted-foreground/50 py-3 select-none">
              mai.agenticapp_v1.3alpha_FZD_20260330
            </p>
          )}
        </main>
        {!tabShellOwnsChrome ? <BottomNav /> : null}
      </div>
    </div>
  );
};

export default AppLayout;
