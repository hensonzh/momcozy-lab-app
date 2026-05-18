import React from "react";
import StatusOverviewBody from "@/pages/status/StatusOverviewBody";
import TabPageTopReserve from "@/components/layout/TabPageTopReserve";
import TabPageScrollRegion from "@/components/layout/TabPageScrollRegion";
import TabPageEmbeddedNav from "@/components/layout/TabPageEmbeddedNav";

/**
 * 状态路由：顶栏预留、信息显示区、底部导航；仅中间区域滚动。
 */
const StatusPage: React.FC = () => {
  return (
    <>
      <div
        className="flex flex-col min-h-0 bg-background w-full"
        style={{ height: "100vh", maxHeight: "100vh" }}
      >
        <TabPageTopReserve />
        <TabPageScrollRegion>
          <StatusOverviewBody />
        </TabPageScrollRegion>
        <TabPageEmbeddedNav />
      </div>
    </>
  );
};

export default StatusPage;
