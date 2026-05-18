import React from "react";
import { useNavigate } from "react-router-dom";
import { motion } from "framer-motion";
import { ArrowLeft, Heart, Shield, Zap, Leaf, Sparkles, Volume2, Wifi } from "lucide-react";
import TabPageTopReserve from "@/components/layout/TabPageTopReserve";
import TabPageScrollRegion from "@/components/layout/TabPageScrollRegion";
import TabPageEmbeddedNav from "@/components/layout/TabPageEmbeddedNav";

const sellingPoints = [
  {
    icon: <Heart className="w-5 h-5 text-primary" />,
    title: "妈妈身心关怀模式",
    desc: "内置心率感应与呼吸引导，吸乳时自动播放舒缓白噪音，帮助妈妈放松身心",
  },
  {
    icon: <Leaf className="w-5 h-5 text-primary" />,
    title: "亲肤零压穿戴",
    desc: "医疗级液态硅胶+记忆棉衬垫，仅 180g 极轻机身，穿戴几乎无感",
  },
  {
    icon: <Zap className="w-5 h-5 text-primary" />,
    title: "智能节律吸力",
    desc: "M.ai 实时分析泌乳节奏，自动切换刺激/深度模式，高效又温柔",
  },
  {
    icon: <Shield className="w-5 h-5 text-primary" />,
    title: "全密封防回流",
    desc: "专利三重密封结构，360° 任意体位使用，躺喂、侧躺均不漏奶",
  },
  {
    icon: <Volume2 className="w-5 h-5 text-primary" />,
    title: "静音科技 ≤35dB",
    desc: "无刷电机+降噪腔体设计，办公室、夜间使用不打扰宝宝和同事",
  },
  {
    icon: <Wifi className="w-5 h-5 text-primary" />,
    title: "M.ai 智能互联",
    desc: "蓝牙 5.3 自动记录每次吸乳数据，AI 分析趋势并提供个性化建议",
  },
];

const W1Promo: React.FC = () => {
  const navigate = useNavigate();

  return (
    <div
        className="flex flex-col min-h-0 bg-background w-full relative"
        style={{ height: "100vh", maxHeight: "100vh" }}
      >
        <TabPageTopReserve />
        <TabPageScrollRegion>
          {/* Hero section */}
          <div
            className="relative overflow-hidden"
            style={{
              background: `linear-gradient(160deg, hsl(340 35% 22%) 0%, hsl(345 40% 30%) 40%, hsl(350 35% 25%) 100%)`,
            }}
          >
            <div className="absolute inset-0 opacity-20">
              <div className="absolute top-10 right-10 w-40 h-40 rounded-full bg-primary/30 blur-3xl" />
              <div className="absolute bottom-5 left-5 w-32 h-32 rounded-full bg-mai-warm/20 blur-2xl" />
            </div>

            <div className="relative z-10 px-4 pt-3 pb-2">
              <button
                type="button"
                onClick={() => navigate("/device")}
                className="w-8 h-8 rounded-full bg-primary-foreground/10 flex items-center justify-center text-primary-foreground/80 hover:bg-primary-foreground/20 transition-colors"
              >
                <ArrowLeft className="w-4 h-4" />
              </button>
            </div>

            <div className="relative z-10 px-6 pb-8 pt-2 text-center">
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6 }}
              >
                <p className="text-[11px] font-semibold text-primary-foreground/50 tracking-[0.2em] uppercase mb-2">
                  Momcozy · New
                </p>
                <h1 className="text-3xl font-black text-primary-foreground tracking-tight">
                  W1
                </h1>
                <p className="text-sm text-primary-foreground/70 mt-2 font-medium leading-relaxed">
                  Wellness & Well-being
                </p>
                <p className="text-xs text-primary-foreground/50 mt-1">
                  为妈妈的身心健康而生
                </p>
              </motion.div>

              <motion.div
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: 0.3, duration: 0.5 }}
                className="mt-6 mx-auto w-36 h-36 rounded-full border-2 border-primary-foreground/10 flex items-center justify-center"
                style={{
                  background: `radial-gradient(circle, hsl(340 30% 35% / 0.6) 0%, transparent 70%)`,
                }}
              >
                <div className="text-center">
                  <Sparkles className="w-10 h-10 text-primary-foreground/40 mx-auto" />
                  <p className="text-[10px] text-primary-foreground/40 mt-1 font-medium">W1</p>
                </div>
              </motion.div>
            </div>
          </div>

          <div className="px-4 -mt-5 relative z-10 bg-background">
            <motion.div
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.4 }}
              className="rounded-2xl border border-border bg-card shadow-lg p-4 space-y-3"
            >
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
                  <Heart className="w-4 h-4 text-primary" />
                </div>
                <div>
                  <p className="text-sm font-bold text-foreground">Momcozy W1 穿戴式吸奶器</p>
                  <p className="text-[11px] text-muted-foreground">新一代身心关怀智能吸乳体验</p>
                </div>
              </div>
              <div className="grid grid-cols-3 gap-2">
                {[
                  { label: "重量", value: "180g" },
                  { label: "噪音", value: "≤35dB" },
                  { label: "续航", value: "4h+" },
                ].map((item) => (
                  <div key={item.label} className="bg-secondary/50 rounded-xl p-2 text-center">
                    <p className="text-[10px] text-muted-foreground">{item.label}</p>
                    <p className="text-sm font-bold text-foreground">{item.value}</p>
                  </div>
                ))}
              </div>
            </motion.div>
          </div>

          <div className="px-4 mt-5 space-y-3 pb-4 bg-background">
            <span className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider">
              核心亮点
            </span>
            {sellingPoints.map((sp, i) => (
              <motion.div
                key={i}
                initial={{ opacity: 0, x: -16 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.5 + i * 0.08 }}
                className="glass-panel rounded-xl p-4 flex items-start gap-3"
              >
                <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0">
                  {sp.icon}
                </div>
                <div>
                  <p className="text-xs font-bold text-foreground">{sp.title}</p>
                  <p className="text-[11px] text-muted-foreground mt-1 leading-relaxed">{sp.desc}</p>
                </div>
              </motion.div>
            ))}
          </div>
        </TabPageScrollRegion>
        <TabPageEmbeddedNav />
    </div>
  );
};

export default W1Promo;
