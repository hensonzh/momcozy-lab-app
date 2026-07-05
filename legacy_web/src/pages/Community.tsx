import React from "react";
import momcozyAgentAvatar from "@/assets/momcozy-agent.png";
import TabPageTopReserve from "@/components/layout/TabPageTopReserve";
import TabPageScrollRegion from "@/components/layout/TabPageScrollRegion";
import TabPageEmbeddedNav from "@/components/layout/TabPageEmbeddedNav";

const Community: React.FC = () => {
  return (
    <div
      className="flex flex-col min-h-0 bg-background w-full"
      style={{ height: "100vh", maxHeight: "100vh" }}
    >
      <TabPageTopReserve />
      <TabPageScrollRegion>
        <div className="min-h-full flex flex-col items-center justify-center p-6 text-center">
          <div className="mb-4 flex h-20 w-20 items-center justify-center rounded-full bg-primary/10 shadow-[0_10px_28px_rgba(58,39,49,0.08)]">
            <img
              src={momcozyAgentAvatar}
              alt=""
              aria-hidden="true"
              className="h-16 w-16 rounded-full object-cover shadow-sm"
            />
          </div>
          <h1 className="text-xl font-bold text-foreground mb-2">社区功能还在建设中哦～</h1>
          <p className="text-sm text-muted-foreground">
            我们将打造一个妈妈们一起交流分享的社区，敬请期待～
          </p>
        </div>
      </TabPageScrollRegion>
      <TabPageEmbeddedNav />
    </div>
  );
};

export default Community;
