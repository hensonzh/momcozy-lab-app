import React from "react";
import { Users } from "lucide-react";
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
          <div className="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mb-4">
            <Users className="w-8 h-8 text-primary" />
          </div>
          <h1 className="text-xl font-bold text-foreground mb-2">社区功能建设中</h1>
          <p className="text-sm text-muted-foreground">
            未来你将在这里与更多妈妈交流分享，敬请期待！
          </p>
        </div>
      </TabPageScrollRegion>
      <TabPageEmbeddedNav />
    </div>
  );
};

export default Community;
