import React, { useState, useRef, useEffect, useCallback, useImperativeHandle, forwardRef } from "react";
import { useNavigate } from "react-router-dom";
import { Camera, Upload, X, Sparkles, Bluetooth, Package, ImagePlus } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import InlineCalibration from "@/components/calibration/InlineCalibration";
import { Button } from "@/components/ui/button";
import MaiAvatar from "@/components/Mai/MaiAvatar";
import KnowledgeCardSheet from "./KnowledgeCardSheet";
import BluetoothSearchDrawer from "./BluetoothSearchDrawer";
import { cn } from "@/lib/utils";
import { useBargeIn } from "@/hooks/useBargeIn";
import { configurePumpAfterBleConnect } from "@/lib/ble";
import { reportDeviceInfoAfterProtocolConfigured } from "@/lib/deviceInfoReport";
import { deviceStore, type StoredDeviceInfo } from "@/lib/deviceStore";
import { knowledgeCards, measurementSteps, arMockResults } from "@/data/deviceMockData";
import { MEDIA_DEMO_URLS } from "@/data/mediaDemoUrls";
import { openDocLinkInMediaViewer } from "@/lib/openMediaViewer";
import type { DocLinkItem } from "@/types/docLink";
import type { KnowledgeCardData, PhotoIdentifyResult } from "@/data/deviceMockData";
import mockDuckbillImg from "@/assets/mock-duckbill.jpg";
import mockFlangeImg from "@/assets/mock-flange.jpg";
import mockSealImg from "@/assets/mock-seal.jpg";
import unboxStep1Img from "@/assets/unbox-step1-accessories.png";
import unboxStep2Img from "@/assets/unbox-step2-controls.png";
import unboxStep3Img from "@/assets/unbox-step3-charging.png";
import unboxStep4Img from "@/assets/unbox-step4-pairing.png";
import unboxStep5Img from "@/assets/unbox-step5-disassembly.png";
import unboxStep6Img from "@/assets/unbox-step6-cleaning.png";
import unboxStep7Img from "@/assets/unbox-step7-measuring.png";
import unboxStep8Img from "@/assets/unbox-step8-assembly.png";

const mockImageMap: Record<string, string> = {
  duckbill: mockDuckbillImg,
  flange: mockFlangeImg,
  seal: mockSealImg,
};

const unboxGuideImages: Record<string, string> = {
  step1: unboxStep1Img,
  step2: unboxStep2Img,
  step3: unboxStep3Img,
  step4: unboxStep4Img,
  step5: unboxStep5Img,
  step6: unboxStep6Img,
  step7: unboxStep7Img,
  step8: unboxStep8Img,
};

interface ChatMsg {
  id: string;
  role: "mai" | "user";
  content: string;
  knowledgeKey?: string;
  type?: "text" | "image" | "identify-result" | "choice" | "device-card" | "doc-links" | "inline-calibration" | "guide-image";
  imageUrl?: string;
  identifyResult?: PhotoIdentifyResult;
  choiceOptions?: { label: string; action: string }[];
  deviceCard?: { model: string; firmware?: string; serial?: string; flangeSize: number; sealSize: string; sellingPoints?: { icon: string; text: string }[] };
  docLinks?: DocLinkItem[];
}

const unboxStepContent = {
  // Legacy fields kept for wearing-guide references
  assembly: "组装指引 🔧\n\n1️⃣ 将鸭嘴阀插入法兰底部卡槽，确保完全卡紧\n2️⃣ 将硅胶塞放入法兰内侧，对齐缺口\n3️⃣ 将组装好的法兰组件对准主机吸口，顺时针旋转锁定\n\n⚠️ 听到「咔」声说明安装到位",
  pairIntro: "配对激活 📶\n\n现在让我们把设备连接到手机上吧！\n\n请先确认：\n• 主机已充电并开机\n• 手机蓝牙已开启\n\n准备好了就开始配对～",
  // New 8-step unbox content
  step1: "**第 1 步：认识你的配件** 🔍\n\n你的 Momcozy Air 1 包含以下配件：\n\n❶ **24mm 法兰主机** ×2（左/右各一）\n❷ **无线充电收纳盒** ×1\n❸ **法兰保护盖** ×2\n❹ **USB Type-C 充电线** ×1\n❺ **磁吸充电线** ×1\n❻ **17mm 法兰内衬** ×2\n❼ **19mm 法兰内衬** ×2\n❽ **21mm 法兰内衬** ×2\n❾ **备用鸭嘴阀** ×2\n❿ **乳头测量卡** ×1\n⓫ **快速入门指南** ×1\n⓬ **用户手册** ×1\n\n请对照图片核对配件是否齐全～ 📦",
  step2: "**第 2 步：按键与控制** 🎛️\n\n了解你的主机操作：\n\n❶ **模式切换键** — 在刺激/深度模式间切换\n❷ **减档键 (-)** — 降低吸力档位\n❸ **加档键 (+)** — 提高吸力档位\n❹ **电源键** — 长按 2 秒开/关机，短按暂停/继续\n\n💡 **指示灯说明**：\n• ⚪ 白灯常亮 = 电量充足\n• 🔴 红灯常亮 = 电量低（剩余 1 次循环）\n• 🟢 绿灯闪烁 = 充电中\n• 🟢 绿灯常亮 = 充电完成",
  step3: "**第 3 步：充电指引** 🔋\n\n两种充电方式：\n\n**方式 A：磁吸直充**\n将磁吸充电线连接主机充电口，直接为主机充电\n\n**方式 B：收纳盒无线充电**\n将主机放入无线充电收纳盒，合上盖子即自动开始充电\n\n📊 **收纳盒电量指示**：\n从左到右 4 颗灯分别代表 25%、50%、75%、100% 电量\n\n⚠️ 首次使用前建议充满电哦～",
  step4: "**第 4 步：配网激活** 📶\n\n让设备连接到手机：\n\n**a.** 长按电源键 2 秒，指示灯白色闪烁即进入配对模式\n**b.** 确保手机蓝牙已开启\n\n按照 App 指引完成左右两侧设备配对，连接成功后即可开始使用！",
  step5: "**第 5 步：主机拆卸** 🔧\n\n使用前需要拆解清洗，步骤如下：\n\n**a.** 将法兰从主机上取下\n**b.** 从集乳杯中取出隔膜\n**c.** 拆解集乳杯的前后盖\n**d.** 分离鸭嘴阀\n\n⚠️ 注意区分**不可水洗部件**（主机本体）和**可水洗部件**（法兰、集乳杯、鸭嘴阀、隔膜等）",
  step6: "**第 6 步：清洁消毒** 🧹\n\n三种消毒方式任选：\n\n**方式 1：流水清洗 + 煮沸消毒**\n用温水清洗后，放入沸水中消毒 3-5 分钟\n\n**方式 2：浸泡消毒**\n使用消毒液浸泡，注意配件不要接触容器边缘\n\n**方式 3：微波蒸汽消毒袋**\n将配件放入蒸汽消毒袋，微波 5-10 分钟\n\n⚠️ **请勿直接放入微波炉消毒！必须使用蒸汽消毒袋**\n\n消毒完成后，请将所有配件彻底晾干 ✨",
  step7: "**第 7 步：乳头测量与法兰内衬选择** 📏\n\n正确尺寸 = 舒适 + 高效！\n\n**测量方法**：\n**a.** 使用附带的测量卡，在吸奶后乳头充分伸展时测量\n**b.** 测量乳头最宽处直径（mm）\n\n**尺寸对照**：\n• 11-13mm → 选 **15mm** 内衬（需另购）\n• 13-15mm → 选 **17mm** 内衬\n• 15-17mm → 选 **19mm** 内衬\n• 17-20mm → 选 **21mm** 内衬\n• 20-23mm → 选 **24mm**（无需内衬）\n\n💡 合适的法兰能最大化出奶量，防止乳头损伤",
  step8: "**第 8 步：组装** 🔧\n\n按照以下顺序组装：\n\n**a.** 将鸭嘴阀安装到集乳杯上，确保安装到位\n**b.** 组装集乳杯，确保前后盖正确安装\n**c.** ⭐ **确保隔膜内侧完全干燥**，先将隔膜盖扣在硅胶上，再安装到集乳杯盖上，防止漏气\n**d.** 将主机与法兰紧密连接，确保无漏气，否则无吸力\n**e.** 将法兰连接到主机上，确保尺寸正确、安装到位\n\n⚠️ 主机与法兰必须紧密连接，否则没有吸力！",
};

export interface InlineDeviceFlowHandle {
  /** Forward external text input into the flow */
  handleExternalInput: (text: string) => boolean; // returns true if consumed
}

interface Props {
  flowType: "unbox" | "measurement" | "photo-identify" | "maintenance" | "wearing-guide";
  onComplete?: () => void;
}

const InlineDeviceFlow = forwardRef<InlineDeviceFlowHandle, Props>(({ flowType, onComplete }, ref) => {
  const navigate = useNavigate();
  const [messages, setMessages] = useState<ChatMsg[]>([]);
  const [streaming, setStreaming] = useState(false);
  const [measureStep, setMeasureStep] = useState(-1);
  const [unboxStep, setUnboxStep] = useState(-1);
  const [showPhotoMenu, setShowPhotoMenu] = useState(false);
  const [showBtDrawer, setShowBtDrawer] = useState(false);
  const [btSide, setBtSide] = useState<"L" | "R">("L"); // track which side is pairing
  const [calibrationActive, setCalibrationActive] = useState(false);
  const [knowledgeOpen, setKnowledgeOpen] = useState(false);
  const [activeKnowledge, setActiveKnowledge] = useState<KnowledgeCardData | null>(null);
  const [initialized, setInitialized] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const { track, interrupt } = useBargeIn();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const cameraInputRef = useRef<HTMLInputElement>(null);

  // scroll into view on message change
  useEffect(() => {
    setTimeout(() => containerRef.current?.scrollIntoView({ behavior: "smooth", block: "end" }), 100);
  }, [messages, showPhotoMenu]);

  const pushMsg = useCallback((msg: Omit<ChatMsg, "id">, delay = 800) => {
    setStreaming(true);
    const tid = setTimeout(() => {
      setMessages((prev) => [...prev, { ...msg, id: `msg-${Date.now()}-${Math.random()}` }]);
      setStreaming(false);
    }, delay);
    track(tid);
  }, [track]);

  const pushMai = useCallback((content: string, extra?: Partial<ChatMsg>, delay = 800) => {
    pushMsg({ role: "mai", content, ...extra }, delay);
  }, [pushMsg]);

  const pushUser = useCallback((content: string) => {
    setMessages((prev) => [...prev, { id: `user-${Date.now()}`, role: "user", content }]);
  }, []);

  // Initialize flow
  useEffect(() => {
    if (initialized) return;
    setInitialized(true);

    if (flowType === "unbox") {
      startUnboxFlow();
    } else if (flowType === "measurement") {
      pushMai(
        "你想了解乳头尺寸的正确测量方法呢～ 我可以一步步带你操作，也可以直接给你完整的指引卡片，你更喜欢哪种方式？ 💕",
        {
          type: "choice",
          choiceOptions: [
            { label: "📋 一步步教我", action: "measure-step" },
            { label: "📖 直接看指引卡片", action: "measure-card" },
          ],
        },
        400
      );
    } else if (flowType === "photo-identify") {
      pushMai("来识别配件吧！📷 请拍照或上传配件图片，我来帮你识别～", undefined, 400);
      setTimeout(() => setShowPhotoMenu(true), 800);
    } else if (flowType === "maintenance") {
      pushMai("设备保养助手来啦！🧹\n\n请拍照或上传配件图片，我来帮你识别配件并提供清洁保养建议～", undefined, 400);
      setTimeout(() => setShowPhotoMenu(true), 800);
    } else if (flowType === "wearing-guide") {
      pushMai("欢迎使用上身指引！👗\n\n我会带你完成以下流程：\n\n1️⃣ **确认配件尺寸** — 检查法兰/硅胶塞是否合适\n2️⃣ **穿戴指引** — 正确佩戴吸奶器\n3️⃣ **设备连接** — 连接左右两侧设备\n4️⃣ **后续推荐** — 力度滴定或直接开始吸奶\n\n首先，你需要调整法兰/硅胶塞尺寸吗？还是尺寸已经确认好了，直接开始穿戴指引？", {
        type: "choice",
        choiceOptions: [
          { label: "📏 需要调整尺寸", action: "wg-adjust-size" },
          { label: "👗 直接开始穿戴", action: "wg-start-wearing" },
        ],
      }, 400);
    }
  }, [flowType, initialized]);

  const startUnboxFlow = useCallback(() => {
    setUnboxStep(0);
    // Step 1: Simulate user uploading a photo of the Air 1 packaging
    setMessages((prev) => [...prev, {
      id: `user-photo-${Date.now()}`,
      role: "user",
      content: "刚收到这个吸奶器，帮我看看～",
      type: "image",
      imageUrl: unboxStep1Img,
    }]);
    setStreaming(true);

    // AI recognizes the device - Phase 1
    const t1 = setTimeout(() => {
      setStreaming(false);
      setMessages((prev) => [...prev, {
        id: `mai-recog-${Date.now()}`,
        role: "mai",
        content: "我识别到了！这是 **Momcozy Air 1** 🎉\n\n看起来你是刚收到这款产品～ 恭喜！这是我们专为妈妈舒适体验打造的穿戴式吸奶器，让我介绍一下它的亮点：",
      }]);
    }, 1200);
    track(t1);

    // Phase 2: Product highlights from mom experience perspective
    const t2 = setTimeout(() => {
      setStreaming(true);
      setTimeout(() => {
        setStreaming(false);
        setMessages((prev) => [...prev, {
          id: `mai-highlights-${Date.now()}`,
          role: "mai",
          content: "✨ **Momcozy Air 1 — 为你而设计**\n\n🤱 **真正免手持** — 仅 180g 超轻机身，放入内衣即可自由活动，边吸奶边做你想做的事\n\n🤫 **安静不打扰** — ≤35dB 低噪设计，宝宝在旁也能安心使用\n\n🌸 **温柔贴合** — 医疗级硅胶法兰 + 多尺寸内衬，找到最适合你的舒适体验\n\n🔋 **无线充电收纳盒** — 出门只带一个盒子，随时随地补电\n\n📱 **智能 App 联动** — 自动记录每次吸乳数据，AI 帮你分析泌乳趋势",
        }]);
      }, 800);
    }, 2000);
    track(t2);

    // Phase 3: E-manual card + video link
    const t3 = setTimeout(() => {
      setStreaming(true);
      setTimeout(() => {
        setStreaming(false);
        setMessages((prev) => [...prev, {
          id: `mai-docs-${Date.now()}`,
          role: "mai",
          content: "这是产品的电子资料，随时可以查阅 📚",
          type: "doc-links",
          docLinks: [
            {
              title: "Air 1 电子说明书",
              icon: "📖",
              desc: "完整产品说明及使用指南",
              url: MEDIA_DEMO_URLS.manualPdf,
              kind: "pdf",
            },
            {
              title: "开箱设置视频教程",
              icon: "🎬",
              desc: "3 分钟视频带你快速上手",
              url: MEDIA_DEMO_URLS.unboxVideo,
              kind: "video",
            },
            { title: "常见问题 FAQ", icon: "❓", desc: "新手常见问题解答", kind: "other" },
          ],
        }]);
      }, 800);
    }, 3800);
    track(t3);

    // Phase 4: Offer step-by-step guidance with all steps overview
    const t4 = setTimeout(() => {
      setStreaming(true);
      setTimeout(() => {
        setStreaming(false);
        setMessages((prev) => [...prev, {
          id: `mai-overview-${Date.now()}`,
          role: "mai",
          content: "我可以为你提供完整的开箱设置指引 💕\n\n完整流程一览：\n\n1️⃣ **认识配件** — 核对包装内所有配件\n2️⃣ **按键与控制** — 了解主机操作方式\n3️⃣ **充电指引** — 两种充电方式说明\n4️⃣ **配网激活** — 蓝牙连接手机\n\n连接完成后如需立即使用，还有：\n5️⃣ **主机拆卸** — 首次使用前的拆解\n6️⃣ **清洁消毒** — 首次使用必须彻底消毒\n7️⃣ **乳头测量与内衬选择** — 找到最合适的尺寸\n8️⃣ **组装** — 正确组装开始使用\n\n你想怎么开始？",
          type: "choice",
          choiceOptions: [
            { label: "📋 一步步带我走", action: "unbox-step-by-step" },
            { label: "🔍 有特别想了解的步骤", action: "unbox-pick-step" },
          ],
        }]);
      }, 800);
    }, 5600);
    track(t4);
  }, [track]);

  const handleKnowledgeClick = (key: string) => {
    const card = knowledgeCards[key];
    if (card) {
      setActiveKnowledge(card);
      setKnowledgeOpen(true);
    }
  };

  const handleCalibrationComplete = useCallback(() => {
    setCalibrationActive(false);
    setUnboxStep(-1);
    setMeasureStep(-1);
    pushMai("舒适度测试完成！🎉\n\n已为你保存最佳吸力档位设置。你的设备已经完全设置好了，随时可以开始使用～ 💕");
    setTimeout(() => onComplete?.(), 1000);
  }, [pushMai, onComplete]);

  // Helper: both L/R devices confirmed — show selling points + smart choice
  const showBothDevicesConfirmed = useCallback(() => {
    pushMai("左右两侧设备均已连接确认！🎉", {
      type: "device-card",
      deviceCard: {
        model: "Momcozy M.ai Pro",
        firmware: "v2.1.4",
        serial: "MP-2026-L-0831 / MP-2026-R-0831",
        flangeSize: 24,
        sealSize: "M",
        sellingPoints: [
          { icon: "⚡", text: "智能双频吸力，模拟宝宝自然吮吸" },
          { icon: "🤫", text: "超静音设计，低至 30dB" },
          { icon: "🩺", text: "医疗级硅胶，FDA 认证" },
          { icon: "📊", text: "AI 智能记录，自动分析泌乳趋势" },
        ],
      },
    });
    setTimeout(() => {
      pushMsg({
        role: "mai",
        content: "你的选择真棒！💕 设备已全部就绪～\n\n接下来你可以：\n\n🎯 **力度滴定**（推荐）— 找到最适合你的吸力档位\n🍼 **直接开始吸奶** — 使用默认档位\n\n💡 建议先做力度滴定哦，只需要几分钟～",
        type: "choice",
        choiceOptions: [
          { label: "🎯 力度滴定（推荐）", action: "wg-start-cal" },
          { label: "🍼 直接开始吸奶", action: "wg-start-pump" },
          { label: "✅ 完成退出", action: "flow-done" },
        ],
      }, 1600);
    }, 0);
  }, [pushMai, pushMsg]);

  // ─── Choice handler ───
  const handleChoiceAction = useCallback((action: string) => {
    if (action === "measure-step") {
      pushUser("一步步教我吧～");
      setMeasureStep(0);
      pushMai("好的，我来一步步教你正确测量乳头尺寸～ 💕\n\n" + measurementSteps[0].instruction, { knowledgeKey: "measurement" });
    } else if (action === "measure-card") {
      pushUser("直接看指引卡片");
      pushMai("好的，这是完整的测量指引，按步骤自己操作就好～ 完成后告诉我哦 💕", {
        knowledgeKey: "measurement",
        type: "choice",
        choiceOptions: [
          { label: "✅ 调整好了", action: "measure-card-done" },
        ],
      });
    } else if (action === "measure-card-done") {
      pushUser("调整好了！");
      if (flowType === "wearing-guide") {
        setMeasureStep(-1);
        pushMai("尺寸调整完成！🎉 现在回到穿戴指引～\n\n你更喜欢哪种方式？", {
          type: "choice",
          choiceOptions: [
            { label: "📋 分步引导我", action: "wg-wearing-steps" },
            { label: "📖 给我说明书", action: "wg-wearing-manual" },
          ],
        });
      } else if (flowType === "unbox") {
        setMeasureStep(-1);
        setUnboxStep(8);
        pushMai("尺寸调整完成！🎉 接下来进入最后一步：组装 🔧");
        setTimeout(() => {
          pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step8 }, 800);
          setTimeout(() => {
            pushMsg({
              role: "mai",
              content: unboxStepContent.step8,
              type: "choice",
              choiceOptions: [
                { label: "✅ 组装完成！", action: "unbox-all-done" },
              ],
            }, 1600);
          }, 0);
        }, 0);
      } else {
        pushMai("尺寸测量完成！🎉\n\n接下来你可以做一次耐受度测试，帮助找到最适合你的吸力档位～", {
          type: "choice",
          choiceOptions: [
            { label: "✅ 开始耐受度测试", action: "measure-cal-start" },
            { label: "⏭️ 下次再说", action: "measure-cal-skip" },
          ],
        });
      }
    } else if (action === "photo-again") {
      setShowPhotoMenu(true);
    } else if (action === "flow-done") {
      pushUser("完成 ✅");
      pushMai("好的，有任何问题随时找我哦～ 💕");
      setTimeout(() => onComplete?.(), 1000);
    } else if (action === "maintenance-clean") {
      pushUser("查看清洁保养指南");
      pushMai("🧼 **配件清洁保养指南**\n\n📌 **日常清洁**\n• 每次使用后拆卸所有接触奶液的配件\n• 用温水 + 奶瓶清洗液浸泡 5 分钟\n• 软毛刷轻刷缝隙，自然晾干\n\n📌 **深度消毒（每周 1-2 次）**\n• 沸水消毒：配件放入沸水中煮 3-5 分钟\n• 蒸汽消毒：使用蒸汽消毒器按说明操作\n\n📌 **注意事项**\n• ❌ 避免使用微波炉加热消毒\n• ❌ 避免使用钢丝球或强力清洁剂\n• ✅ 晾干后存放于干燥通风处\n\n⏰ 建议每次使用后立即清洗，避免奶渍干固 💕", {
        type: "choice",
        choiceOptions: [
          { label: "🔧 穿戴组装指南", action: "maintenance-assembly" },
          { label: "📷 继续识别配件", action: "photo-again" },
          { label: "✅ 完成", action: "flow-done" },
        ],
      });
    } else if (action === "maintenance-assembly") {
      pushUser("查看穿戴组装指南");
      pushMai("🔧 **穿戴组装指南**\n\n📌 **组装顺序**\n1️⃣ 鸭嘴阀 → 插入法兰底部卡槽，确保完全卡紧\n2️⃣ 硅胶塞 → 放入法兰内侧，对齐缺口\n3️⃣ 法兰组件 → 对准主机吸口，顺时针旋转锁定\n\n📌 **穿戴要点**\n• 乳头居中对准法兰管道口\n• 法兰边缘贴合乳房，确保无缝隙\n• 穿上哺乳内衣固定主机\n\n📌 **自检清单**\n• ✅ 乳头在管道内自由伸缩\n• ✅ 无侧压或摩擦感\n• ✅ 主机稳固不滑落\n• ✅ 听到「咔」声说明安装到位\n\n有问题随时问我哦～ 💕", {
        type: "choice",
        choiceOptions: [
          { label: "🧼 清洁保养指南", action: "maintenance-clean" },
          { label: "📷 继续识别配件", action: "photo-again" },
          { label: "✅ 完成", action: "flow-done" },
        ],
      });
    }
    // ─── Wearing guide flow ───
    else if (action === "wg-adjust-size") {
      pushUser("需要先调整尺寸");
      pushMai("好的～ 我可以一步步带你测量，也可以直接给你指引卡片自己操作，你更喜欢哪种方式？ 💕", {
        type: "choice",
        choiceOptions: [
          { label: "📋 一步步教我", action: "measure-step" },
          { label: "📖 给我指引自己操作", action: "measure-card" },
        ],
      });
    } else if (action === "wg-start-wearing") {
      pushUser("尺寸已确认，直接开始穿戴");
      pushMai("好的！接下来是穿戴指引 👗\n\n你更喜欢哪种方式？", {
        type: "choice",
        choiceOptions: [
          { label: "📋 分步引导我", action: "wg-wearing-steps" },
          { label: "📖 给我说明书", action: "wg-wearing-manual" },
        ],
      });
    } else if (action === "wg-wearing-steps") {
      pushUser("分步引导我吧～");
      pushMai("第一步：准备工作 🧹\n\n1️⃣ 确保所有配件已清洗并晾干\n2️⃣ 确认法兰、鸭嘴阀、硅胶塞已正确组装\n3️⃣ 准备好哺乳内衣\n\n准备好了告诉我～", {
        type: "choice",
        choiceOptions: [
          { label: "✅ 准备好了", action: "wg-step2" },
        ],
      });
    } else if (action === "wg-step2") {
      pushUser("准备好了！");
      pushMai("第二步：放置法兰 📐\n\n1️⃣ 将乳头对准法兰管道口中央\n2️⃣ 法兰边缘完全贴合乳房，确保无缝隙\n3️⃣ 轻轻按压法兰边缘，形成密封\n\n⚠️ 乳头应居中，不偏不倚\n\n放好了告诉我～", {
        type: "choice",
        choiceOptions: [
          { label: "✅ 放好了", action: "wg-step3" },
        ],
      });
    } else if (action === "wg-step3") {
      pushUser("放好了！");
      pushMai("第三步：固定主机 🔒\n\n1️⃣ 穿上哺乳内衣，将主机卡入内衣中固定\n2️⃣ 确认主机稳固不滑落\n3️⃣ 调整位置至舒适\n\n✅ **自检清单**：\n• 乳头在管道内自由伸缩？\n• 无侧压或摩擦感？\n• 乳晕没有被过度拉入？\n• 主机稳固不滑落？\n\n如果都没问题，穿戴完成啦！ 🎉", {
        type: "choice",
        choiceOptions: [
          { label: "✅ 一切正常", action: "wg-complete" },
          { label: "❌ 有些不适", action: "wg-discomfort" },
        ],
      });
    } else if (action === "wg-discomfort") {
      pushUser("感觉有些不适...");
      pushMai("别担心，这很常见！💕\n\n可能的原因：\n• **侧压/摩擦** → 法兰尺寸可能不合适，建议重新测量\n• **乳晕被拉入** → 法兰口径偏大，需换小一号\n• **主机滑落** → 内衣支撑不够，尝试调整穿戴位置\n\n你要现在调整法兰尺寸吗？", {
        type: "choice",
        choiceOptions: [
          { label: "📏 重新测量尺寸", action: "wg-adjust-size" },
          { label: "👗 再试一次穿戴", action: "wg-wearing-steps" },
          { label: "✅ 没关系，继续", action: "wg-complete" },
        ],
      });
    } else if (action === "wg-wearing-manual") {
      pushUser("给我说明书就好");
      pushMai("好的，这是穿戴说明书 📖\n\n**穿戴步骤总览：**\n\n1️⃣ **组装确认** — 鸭嘴阀→法兰底部卡紧，硅胶塞→法兰内侧对齐，法兰→主机顺时针旋转锁定（听到「咔」声）\n\n2️⃣ **放置法兰** — 乳头居中对准管道口，边缘完全贴合乳房\n\n3️⃣ **固定主机** — 穿哺乳内衣固定，确认稳固\n\n4️⃣ **自检** — 乳头自由伸缩、无侧压摩擦、乳晕无过度拉入、主机不滑落\n\n⚠️ 如有不适，可能需要调整法兰/硅胶塞尺寸", {
        type: "choice",
        choiceOptions: [
          { label: "✅ 穿好了", action: "wg-complete" },
        ],
      });
    } else if (action === "wg-complete") {
      pushUser("穿戴完成！");
      // Step 4: 设备连接 — auto-check BT
      pushMai("穿戴完成！🎉 接下来进入第三步：**设备连接** 📶\n\n🔍 正在自动检查蓝牙连接状态...");
      const mockHasBt = false; // toggle for demo
      setTimeout(() => {
        if (mockHasBt) {
          // Already connected — show L side device card for confirmation
          pushMsg({
            role: "mai",
            content: "检测到已连接的左侧设备 📶",
            type: "device-card",
            deviceCard: {
              model: "Momcozy M.ai Pro (L)",
              firmware: "v2.1.4",
              serial: "MP-2026-L-0831",
              flangeSize: 24,
              sealSize: "M",
            },
          }, 1200);
          setTimeout(() => {
            pushMsg({
              role: "mai",
              content: "这是你正在使用的**左侧**设备吗？",
              type: "choice",
              choiceOptions: [
                { label: "✅ 是的", action: "wg-bt-L-is-mine" },
                { label: "❌ 不是这台", action: "wg-bt-L-not-mine" },
              ],
            }, 2000);
          }, 0);
        } else {
          // Not connected — troubleshooting guidance
          pushMsg({
            role: "mai",
            content: "⚠️ 未检测到蓝牙连接\n\n请检查以下几点：\n\n1️⃣ **设备开机** — 长按主机电源键 2 秒，指示灯亮起即开机\n2️⃣ **手机蓝牙** — 确保手机蓝牙已打开（设置 → 蓝牙 → 开启）\n3️⃣ **靠近设备** — 将手机放在设备 1 米以内\n4️⃣ **排障** — 如指示灯未亮请先充电；长按电源键 5 秒可重置蓝牙\n\n确认后，我们先连接左侧设备～",
            type: "choice",
            choiceOptions: [
              { label: "📶 开始连接左侧设备", action: "wg-bt-start-L" },
            ],
          }, 1400);
        }
      }, 0);
    } else if (action === "wg-bt-L-is-mine") {
      pushUser("是的，就是这台左侧设备");
      // L confirmed, check R
      pushMai("左侧设备确认！✅\n\n正在检查右侧设备连接...");
      const mockHasBtR = false; // toggle for demo
      setTimeout(() => {
        if (mockHasBtR) {
          pushMsg({
            role: "mai",
            content: "检测到已连接的右侧设备 📶",
            type: "device-card",
            deviceCard: {
              model: "Momcozy M.ai Pro (R)",
              firmware: "v2.1.4",
              serial: "MP-2026-R-0831",
              flangeSize: 24,
              sealSize: "M",
            },
          }, 1000);
          setTimeout(() => {
            pushMsg({
              role: "mai",
              content: "这是你正在使用的**右侧**设备吗？",
              type: "choice",
              choiceOptions: [
                { label: "✅ 是的", action: "wg-bt-R-is-mine" },
                { label: "❌ 不是这台", action: "wg-bt-R-not-mine" },
              ],
            }, 1800);
          }, 0);
        } else {
          pushMsg({
            role: "mai",
            content: "右侧设备未连接，请确认右侧主机已开机且蓝牙开启～",
            type: "choice",
            choiceOptions: [
              { label: "📶 开始连接右侧设备", action: "wg-bt-start-R" },
            ],
          }, 1200);
        }
      }, 0);
    } else if (action === "wg-bt-L-not-mine") {
      pushUser("不是这台设备");
      pushMai("好的，请确认你的设备已开机且蓝牙已开启，我们重新搜索连接～\n\n💡 检查要点：\n• 确保目标设备已开机（指示灯亮起）\n• 手机蓝牙已开启\n• 靠近目标设备", {
        type: "choice",
        choiceOptions: [
          { label: "📶 搜索左侧设备", action: "wg-bt-start-L" },
        ],
      });
    } else if (action === "wg-bt-R-is-mine") {
      pushUser("是的，就是这台右侧设备");
      // Both sides confirmed — show selling points + smart choice
      showBothDevicesConfirmed();
    } else if (action === "wg-bt-R-not-mine") {
      pushUser("不是这台设备");
      pushMai("好的，请确认你的右侧设备已开机且蓝牙已开启，我们重新搜索连接～", {
        type: "choice",
        choiceOptions: [
          { label: "📶 搜索右侧设备", action: "wg-bt-start-R" },
        ],
      });
    } else if (action === "wg-bt-start-L") {
      pushUser("开始连接左侧设备");
      setBtSide("L");
      pushMai("正在搜索左侧设备... 📶");
      setTimeout(() => setShowBtDrawer(true), 800);
    } else if (action === "wg-bt-start-R") {
      pushUser("开始连接右侧设备");
      setBtSide("R");
      pushMai("正在搜索右侧设备... 📶");
      setTimeout(() => setShowBtDrawer(true), 800);
    } else if (action === "wg-bt-L-confirmed") {
      pushUser("确认左侧设备！");
      pushMai("左侧设备连接成功！✅\n\n接下来连接右侧设备～", {
        type: "choice",
        choiceOptions: [
          { label: "📶 开始连接右侧设备", action: "wg-bt-start-R" },
        ],
      });
    } else if (action === "wg-bt-R-confirmed") {
      pushUser("确认右侧设备！");
      // Both sides connected — show selling points + smart choice
      showBothDevicesConfirmed();
    } else if (action === "wg-start-cal") {
      pushUser("先做耐受度滴定！");
      pushMai("好的！正在为你启动舒适度测试... 🎯");
      setTimeout(() => {
        setCalibrationActive(true);
        pushMsg({ role: "mai", content: "", type: "inline-calibration" }, 1200);
      }, 0);
    } else if (action === "wg-start-pump") {
      pushUser("直接开始吸奶");
      pushMai("好的，正在跳转到吸奶页面... 🍼");
      setTimeout(() => {
        onComplete?.();
        navigate("/pump");
      }, 1000);
    }
    else if (action.startsWith("knowledge-")) {
      handleKnowledgeClick(action.replace("knowledge-", ""));
    }
    // ─── Unboxing flow (redesigned 8-step) ───
    // Helper: all-steps navigation menu
    const allStepsMenu = (excludeStep?: number): { label: string; action: string }[] => {
      const steps: { label: string; action: string }[] = [
        { label: "1️⃣ 认识配件", action: "unbox-jump-1" },
        { label: "2️⃣ 按键与控制", action: "unbox-jump-2" },
        { label: "3️⃣ 充电指引", action: "unbox-jump-3" },
        { label: "4️⃣ 配网激活", action: "unbox-jump-4" },
        { label: "5️⃣ 主机拆卸", action: "unbox-jump-5" },
        { label: "6️⃣ 清洁消毒", action: "unbox-jump-6" },
        { label: "7️⃣ 乳头测量", action: "unbox-jump-7" },
        { label: "8️⃣ 组装", action: "unbox-jump-8" },
      ];
      return excludeStep ? steps.filter((_, i) => i + 1 !== excludeStep) : steps;
    };

    // Show step navigator — accept number input
    if (action === "unbox-show-nav") {
      pushUser("我想了解其他步骤");
      setUnboxStep(0.5); // special state: awaiting step number input
      pushMai("好的，输入步骤编号即可跳转 👇\n\n1. 认识配件\n2. 按键与控制\n3. 充电指引\n4. 配网激活\n5. 主机拆卸\n6. 清洁消毒\n7. 乳头测量与内衬选择\n8. 组装\n\n直接输入数字 **1-8** 即可～", {
        type: "choice",
        choiceOptions: [
          { label: "📋 从头一步步走", action: "unbox-step-by-step" },
          { label: "✅ 都了解了，完成", action: "unbox-final-done" },
        ],
      });
    }

    else if (action === "unbox-step-by-step") {
      pushUser("一步步带我走～");
      setUnboxStep(1);
      pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step1 }, 400);
      setTimeout(() => {
        pushMsg({
          role: "mai",
          content: unboxStepContent.step1,
          type: "choice",
          choiceOptions: [
            { label: "✅ 配件齐全，下一步", action: "unbox-to-step2" },
            { label: "📷 拍照识别不认识的配件", action: "unbox-parts-photo" },
            { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
          ],
        }, 1200);
      }, 0);
    } else if (action === "unbox-pick-step") {
      pushUser("我想了解特定步骤");
      setUnboxStep(0.5);
      pushMai("好的，输入步骤编号即可跳转 👇\n\n1. 认识配件\n2. 按键与控制\n3. 充电指引\n4. 配网激活\n5. 主机拆卸\n6. 清洁消毒\n7. 乳头测量与内衬选择\n8. 组装\n\n直接输入数字 **1-8** 即可～", {
        type: "choice",
        choiceOptions: [
          { label: "📋 从头一步步走", action: "unbox-step-by-step" },
        ],
      });
    }
    // Jump to specific steps (1-8) — each step shows image + content + nav options
    else if (action === "unbox-jump-1") {
      pushUser("认识配件");
      setUnboxStep(1);
      pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step1 }, 400);
      setTimeout(() => {
        pushMsg({ role: "mai", content: unboxStepContent.step1, type: "choice", choiceOptions: [
          { label: "▶️ 从这步开始往下走", action: "unbox-to-step2" },
          { label: "📷 拍照识别配件", action: "unbox-parts-photo" },
          { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
        ]}, 1200);
      }, 0);
    } else if (action === "unbox-jump-2") {
      pushUser("按键与控制");
      setUnboxStep(2);
      pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step2 }, 400);
      setTimeout(() => {
        pushMsg({ role: "mai", content: unboxStepContent.step2, type: "choice", choiceOptions: [
          { label: "▶️ 从这步开始往下走", action: "unbox-to-step3" },
          { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
        ]}, 1200);
      }, 0);
    } else if (action === "unbox-jump-3") {
      pushUser("充电指引");
      setUnboxStep(3);
      pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step3 }, 400);
      setTimeout(() => {
        pushMsg({ role: "mai", content: unboxStepContent.step3, type: "choice", choiceOptions: [
          { label: "▶️ 从这步开始往下走", action: "unbox-to-step4" },
          { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
        ]}, 1200);
      }, 0);
    } else if (action === "unbox-jump-4") {
      pushUser("配网激活");
      setUnboxStep(4);
      pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step4 }, 400);
      setTimeout(() => {
        pushMsg({ role: "mai", content: unboxStepContent.step4, type: "choice", choiceOptions: [
          { label: "📶 立即配网", action: "unbox-bt-start" },
          { label: "▶️ 跳过，继续下一步", action: "unbox-after-pair-skip" },
          { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
        ]}, 1200);
      }, 0);
    } else if (action === "unbox-jump-5") {
      pushUser("主机拆卸");
      setUnboxStep(5);
      pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step5 }, 400);
      setTimeout(() => {
        pushMsg({ role: "mai", content: unboxStepContent.step5, type: "choice", choiceOptions: [
          { label: "▶️ 从这步开始往下走", action: "unbox-show-step6" },
          { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
        ]}, 1200);
      }, 0);
    } else if (action === "unbox-jump-6") {
      pushUser("清洁消毒");
      setUnboxStep(6);
      pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step6 }, 400);
      setTimeout(() => {
        pushMsg({ role: "mai", content: unboxStepContent.step6, type: "choice", choiceOptions: [
          { label: "▶️ 从这步开始往下走", action: "unbox-show-step7" },
          { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
        ]}, 1200);
      }, 0);
    } else if (action === "unbox-jump-7") {
      pushUser("乳头测量");
      setUnboxStep(7);
      pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step7 }, 400);
      setTimeout(() => {
        pushMsg({ role: "mai", content: unboxStepContent.step7, type: "choice", choiceOptions: [
          { label: "📏 帮我一步步测量", action: "measure-step" },
          { label: "▶️ 从这步开始往下走", action: "unbox-show-step8" },
          { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
        ]}, 1200);
      }, 0);
    } else if (action === "unbox-jump-8") {
      pushUser("组装");
      setUnboxStep(8);
      pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step8 }, 400);
      setTimeout(() => {
        pushMsg({ role: "mai", content: unboxStepContent.step8, type: "choice", choiceOptions: [
          { label: "✅ 组装完成！", action: "unbox-all-done" },
          { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
        ]}, 1200);
      }, 0);
    }
    // Step-by-step flow transitions (with nav options at each step)
    else if (action === "unbox-parts-photo") {
      pushUser("我拍照识别一下配件");
      setUnboxStep(1.5);
      setShowPhotoMenu(true);
    } else if (action === "unbox-to-step2") {
      pushUser("配件齐全，继续～");
      setUnboxStep(2);
      pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step2 }, 400);
      setTimeout(() => {
        pushMsg({
          role: "mai",
          content: unboxStepContent.step2,
          type: "choice",
          choiceOptions: [
            { label: "✅ 了解了，下一步", action: "unbox-to-step3" },
            { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
          ],
        }, 1200);
      }, 0);
    } else if (action === "unbox-to-step3") {
      pushUser("了解了，继续～");
      setUnboxStep(3);
      pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step3 }, 400);
      setTimeout(() => {
        pushMsg({
          role: "mai",
          content: unboxStepContent.step3,
          type: "choice",
          choiceOptions: [
            { label: "✅ 了解了，下一步", action: "unbox-to-step4" },
            { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
          ],
        }, 1200);
      }, 0);
    } else if (action === "unbox-to-step4") {
      pushUser("了解了，继续～");
      setUnboxStep(4);
      pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step4 }, 400);
      setTimeout(() => {
        pushMsg({
          role: "mai",
          content: unboxStepContent.step4,
          type: "choice",
          choiceOptions: [
            { label: "📶 立即配网", action: "unbox-bt-start" },
            { label: "⏭️ 先跳过配网", action: "unbox-after-pair-skip" },
            { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
          ],
        }, 1200);
      }, 0);
    } else if (action === "unbox-bt-start") {
      pushUser("开始配对！");
      setBtSide("L");
      pushMai("正在搜索附近的蓝牙设备... 📶");
      setTimeout(() => setShowBtDrawer(true), 800);
    } else if (action === "unbox-bt-confirmed") {
      pushUser("确认，就是这个设备！");
      setUnboxStep(4.6);
      pushMai("蓝牙连接成功！✅\n\n设备已成功绑定 📱\n🔋 电量：78%\n📡 连接状态：稳定\n\n配网激活完成！🎉", {
        type: "device-card",
        deviceCard: {
          model: "Momcozy Air 1",
          firmware: "v1.0.2",
          serial: "AIR1-2026-0831",
          flangeSize: 24,
          sealSize: "M",
        },
      });
      setTimeout(() => {
        pushMsg({
          role: "mai",
          content: "你现在需要立即使用吸奶器吗？ 🍼\n\n💡 **温馨提示**：首次使用前，建议先对所有接触奶液的配件进行**彻底的清洁和消毒**，确保卫生安全哦～",
          type: "choice",
          choiceOptions: [
            { label: "🍼 需要，继续指引", action: "unbox-need-use" },
            { label: "✅ 暂时不用，完成", action: "unbox-final-done" },
            { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
          ],
        }, 1600);
      }, 0);
    } else if (action === "unbox-after-pair-skip") {
      pushUser("先跳过配网");
      pushMai("好的，你可以之后在设备管理页随时配网 📶\n\n你现在需要立即使用吸奶器吗？ 🍼\n\n💡 **温馨提示**：首次使用前，建议先对所有接触奶液的配件进行**彻底的清洁和消毒**，确保卫生安全哦～", {
        type: "choice",
        choiceOptions: [
          { label: "🍼 需要，继续指引", action: "unbox-need-use" },
          { label: "✅ 暂时不用，完成", action: "unbox-final-done" },
          { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
        ],
      });
    } else if (action === "unbox-need-use") {
      pushUser("需要使用，继续指引～");
      setUnboxStep(5);
      pushMai("好的！首次使用前我们需要完成以下步骤：\n\n5️⃣ **主机拆卸** — 拆解各部件以便清洗\n6️⃣ **清洁消毒** — 首次使用必须彻底消毒\n7️⃣ **乳头测量与内衬选择** — 找到最舒适的尺寸\n8️⃣ **组装** — 正确组装准备使用\n\n我们开始第 5 步：主机拆卸 🔧", {
        type: "choice",
        choiceOptions: [
          { label: "📋 继续", action: "unbox-show-step5" },
          { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
        ],
      });
    } else if (action === "unbox-show-step5") {
      pushUser("继续～");
      pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step5 }, 400);
      setTimeout(() => {
        pushMsg({
          role: "mai",
          content: unboxStepContent.step5,
          type: "choice",
          choiceOptions: [
            { label: "✅ 拆好了，下一步", action: "unbox-show-step6" },
            { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
          ],
        }, 1200);
      }, 0);
    } else if (action === "unbox-show-step6") {
      pushUser("拆好了～");
      setUnboxStep(6);
      pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step6 }, 400);
      setTimeout(() => {
        pushMsg({
          role: "mai",
          content: unboxStepContent.step6,
          type: "choice",
          choiceOptions: [
            { label: "✅ 消毒完成，下一步", action: "unbox-show-step7" },
            { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
          ],
        }, 1200);
      }, 0);
    } else if (action === "unbox-show-step7") {
      pushUser("消毒完成～");
      setUnboxStep(7);
      pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step7 }, 400);
      setTimeout(() => {
        pushMsg({
          role: "mai",
          content: unboxStepContent.step7,
          type: "choice",
          choiceOptions: [
            { label: "📏 帮我一步步测量", action: "measure-step" },
            { label: "✅ 尺寸已确认，下一步", action: "unbox-show-step8" },
            { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
          ],
        }, 1200);
      }, 0);
    } else if (action === "unbox-show-step8") {
      pushUser("继续组装～");
      setUnboxStep(8);
      pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step8 }, 400);
      setTimeout(() => {
        pushMsg({
          role: "mai",
          content: unboxStepContent.step8,
          type: "choice",
          choiceOptions: [
            { label: "✅ 组装完成！", action: "unbox-all-done" },
            { label: "🔀 跳转其他步骤", action: "unbox-show-nav" },
          ],
        }, 1200);
      }, 0);
    } else if (action === "unbox-all-done") {
      pushUser("组装完成！");
      setUnboxStep(-1);
      pushMai("恭喜你！所有准备工作都完成了 🎉🎉\n\n你的 Momcozy Air 1 已经准备就绪！\n\n接下来你可以：", {
        type: "choice",
        choiceOptions: [
          { label: "🍼 开始吸奶", action: "wg-start-pump" },
          { label: "🎯 先做力度滴定（推荐）", action: "unbox-goto-cal" },
          { label: "✅ 完成退出", action: "unbox-final-done" },
        ],
      });
    }
    else if (action === "unbox-goto-cal") {
      pushUser("先做力度滴定！");
      pushMai("好的！正在为你启动舒适度测试... 🎯");
      setTimeout(() => {
        setCalibrationActive(true);
        pushMsg({ role: "mai", content: "", type: "inline-calibration" }, 1200);
      }, 0);
    } else if (action === "unbox-final-done") {
      pushUser("就到这里吧～");
      setUnboxStep(-1);
      pushMai("没问题！你的设备已经设置完成 🎉\n\n之后有任何问题，随时找我哦～ 💕");
      setTimeout(() => onComplete?.(), 1000);
    }
    // Measure flow: after last step offer cal
    else if (action === "measure-cal-start") {
      pushUser("准备好了，开始吧！");
      pushMai("好的！正在为你启动舒适度测试... 🎯");
      setTimeout(() => {
        setCalibrationActive(true);
        pushMsg({ role: "mai", content: "", type: "inline-calibration" }, 1200);
      }, 0);
    } else if (action === "measure-cal-skip") {
      pushUser("下次再说吧～");
      pushMai("没问题！随时可以回来做耐受度测试哦～ 💕");
      setTimeout(() => onComplete?.(), 1000);
    }
  }, [pushMai, pushUser, pushMsg, onComplete, showBothDevicesConfirmed]);

  // Photo identification
  const handlePhotoIdentify = (file: File) => {
    const url = URL.createObjectURL(file);
    setMessages((prev) => [
      ...prev,
      { id: `user-img-${Date.now()}`, role: "user", content: "帮我看看这是什么配件？", type: "image", imageUrl: url },
    ]);
    setShowPhotoMenu(false);
    setStreaming(true);
    const result = arMockResults[Math.floor(Math.random() * arMockResults.length)];
    setTimeout(() => {
      setStreaming(false);
      setMessages((prev) => [
        ...prev,
        {
          id: `mai-identify-${Date.now()}`, role: "mai",
          content: `我识别出来了！这很可能是 **${result.partName}** ${result.partIcon}`,
          type: "identify-result", identifyResult: result, knowledgeKey: result.knowledgeKey,
        },
      ]);
      handlePostIdentify(result);
    }, 2000);
  };

  const handleDemoIdentify = (result: PhotoIdentifyResult) => {
    const img = mockImageMap[result.mockImage];
    if (!img) return;
    setShowPhotoMenu(false);
    setMessages((prev) => [
      ...prev,
      { id: `user-demo-${Date.now()}`, role: "user", content: "帮我看看这个配件", type: "image", imageUrl: img },
    ]);
    setStreaming(true);
    setTimeout(() => {
      setStreaming(false);
      setMessages((prev) => [
        ...prev,
        {
          id: `mai-id-${Date.now()}`, role: "mai",
          content: `我识别出来了！这很可能是 **${result.partName}** ${result.partIcon}`,
          type: "identify-result", identifyResult: result, knowledgeKey: result.knowledgeKey,
        },
      ]);
      handlePostIdentify(result);
    }, 2000);
  };

  const handlePostIdentify = (result: PhotoIdentifyResult) => {
    if (unboxStep === 1.5) {
      // Unbox step 1: after identifying a part, offer to continue or identify more
      setTimeout(() => {
        setUnboxStep(1);
        pushMsg({
          role: "mai", content: `已识别 **${result.partName}** ${result.partIcon}！还有其他不认识的配件吗？或者我们继续下一步～`,
          type: "choice",
          choiceOptions: [
            { label: "📷 继续识别其他配件", action: "unbox-parts-photo" },
            { label: "✅ 配件都认识了，继续", action: "unbox-to-step2" },
          ],
        }, 600);
      }, 600);
    } else if (flowType === "maintenance") {
      // Maintenance flow: show cleaning/assembly cards
      setTimeout(() => {
        const maintenanceCards: { label: string; action: string }[] = [
          { label: "🧼 清洁保养指南", action: "maintenance-clean" },
          { label: "🔧 穿戴组装指南", action: "maintenance-assembly" },
          { label: "📷 继续识别其他配件", action: "photo-again" },
          { label: "✅ 完成", action: "flow-done" },
        ];
        setMessages((prev) => [
          ...prev,
          {
            id: `mai-maint-${Date.now()}`, role: "mai",
            content: `已识别 **${result.partName}** ${result.partIcon}，${result.suggestion}\n\n你可以查看以下保养指南：`,
            type: "choice",
            choiceOptions: maintenanceCards,
          },
        ]);
      }, 600);
    } else {
      setTimeout(() => {
        setMessages((prev) => [
          ...prev,
          {
            id: `mai-followup-${Date.now()}`, role: "mai", content: result.suggestion,
            type: "choice",
            choiceOptions: [
              { label: "📖 查看维护指南", action: `knowledge-${result.knowledgeKey}` },
              { label: "📷 识别其他配件", action: "photo-again" },
              { label: "✅ 完成", action: "flow-done" },
            ],
          },
        ]);
      }, 600);
    }
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) handlePhotoIdentify(file);
    e.target.value = "";
  };

  // Handle text input for step advancement
  const handleTextInput = useCallback((text: string): boolean => {
    // Measurement step flow
    if (measureStep >= 0 && measureStep < measurementSteps.length - 1) {
      pushUser(text);
      const nextIdx = measureStep + 1;
      setMeasureStep(nextIdx);
      pushMai(measurementSteps[nextIdx].instruction);
      if (nextIdx === measurementSteps.length - 1) {
        if (flowType === "wearing-guide") {
          // Return to wearing guide after size adjustment
          setTimeout(() => {
            setMeasureStep(-1);
            pushMsg({
              role: "mai",
              content: "尺寸调整完成！🎉 现在回到穿戴指引～\n\n你更喜欢哪种方式？",
              type: "choice",
              choiceOptions: [
                { label: "📋 分步引导我", action: "wg-wearing-steps" },
                { label: "📖 给我说明书", action: "wg-wearing-manual" },
              ],
            }, 1600);
          }, 0);
        } else if (flowType === "unbox") {
          // After measure in unbox flow, go to step 8 assembly
          setTimeout(() => {
            setMeasureStep(-1);
            setUnboxStep(8);
            pushMsg({ role: "mai", content: "尺寸调整完成！🎉 接下来进入最后一步：组装 🔧" }, 800);
            setTimeout(() => {
              pushMsg({ role: "mai", content: "", type: "guide-image", imageUrl: unboxGuideImages.step8 }, 1600);
              setTimeout(() => {
                pushMsg({
                  role: "mai",
                  content: unboxStepContent.step8,
                  type: "choice",
                  choiceOptions: [
                    { label: "✅ 组装完成！", action: "unbox-all-done" },
                  ],
                }, 2400);
              }, 0);
            }, 0);
          }, 0);
        } else {
          const calContent = "尺寸测量完成！🎉\n\n接下来你可以做一次耐受度测试，帮助找到最适合你的吸力档位，让吸奶更舒适高效～";
          setTimeout(() => {
            pushMsg({
              role: "mai", content: calContent,
              type: "choice",
              choiceOptions: [
                { label: "✅ 开始耐受度测试", action: "measure-cal-start" },
                { label: "⏭️ 下次再说", action: "measure-cal-skip" },
              ],
            }, 1600);
          }, 0);
        }
      }
      return true;
    }

    // Unbox: number input for step navigation
    if (unboxStep === 0.5 || (unboxStep >= 0 && flowType === "unbox")) {
      const trimmed = text.trim();
      const stepNum = parseInt(trimmed, 10);
      if (stepNum >= 1 && stepNum <= 8) {
        const jumpActions = [
          "unbox-jump-1", "unbox-jump-2", "unbox-jump-3", "unbox-jump-4",
          "unbox-jump-5", "unbox-jump-6", "unbox-jump-7", "unbox-jump-8",
        ];
        handleChoiceAction(jumpActions[stepNum - 1]);
        return true;
      }
    }

    // Unbox: BT step — ignore text input, handled by drawer
    if (unboxStep === 4) { return true; }

    // Flow is active but no specific step needs input — still consume to prevent main chat
    if (unboxStep >= 0 || flowType === "photo-identify") {
      return false;
    }

    return false;
  }, [measureStep, unboxStep, flowType, pushUser, pushMai, pushMsg, handleChoiceAction]);

  // Expose input handler to parent
  useImperativeHandle(ref, () => ({
    handleExternalInput: (text: string) => handleTextInput(text),
  }), [handleTextInput]);

  // BT drawer callback
  const handleBtConnected = useCallback(async (deviceId: string, deviceName: string, rssi: number) => {
    const side = btSide;
    const fullInfo: StoredDeviceInfo = {
      deviceId,
      deviceName,
      connected: true,
      battery: 0,
      rssi,
      flangeSize: 24,
      sealSize: "M",
      model: deviceName,
      firmware: "-",
      serialNumber: deviceId,
    };
    deviceStore.setDevice(side, fullInfo);
    reportDeviceInfoAfterProtocolConfigured();
    try {
      await configurePumpAfterBleConnect(deviceId, side);
    } catch {
      // 协议配置失败时，不阻断当前引导流程
    }

    setShowBtDrawer(false);
    if (flowType === "wearing-guide") {
      const deviceLabel = side === "L" ? "左侧" : "右侧";
      const serial = side === "L" ? "MP-2026-L-0831" : "MP-2026-R-0831";
      const battery = side === "L" ? "78" : "82";
      // Show device info card for confirmation
      pushMsg({
        role: "mai",
        content: `已连接到${deviceLabel}设备 📶`,
        type: "device-card",
        deviceCard: {
          model: `Momcozy M.ai Pro (${side})`,
          firmware: "v2.1.4",
          serial,
          flangeSize: 24,
          sealSize: "M",
        },
      }, 600);
      setTimeout(() => {
        pushMsg({
          role: "mai",
          content: `这是你的${deviceLabel}设备吗？`,
          type: "choice",
          choiceOptions: [
            { label: "✅ 是的", action: side === "L" ? "wg-bt-L-confirmed" : "wg-bt-R-confirmed" },
            { label: "❌ 不是这台", action: side === "L" ? "wg-bt-L-not-mine" : "wg-bt-R-not-mine" },
          ],
        }, 1400);
      }, 0);
    } else if (unboxStep === 4 || unboxStep === 0) {
      pushMai("检测到附近设备 📶\n\n🔗 已发现：**Momcozy Air 1**\n📡 信号强度：强\n🔋 电量：78%\n\n这是你的设备吗？", {
        type: "choice",
        choiceOptions: [
          { label: "✅ 没错，就是这个", action: "unbox-bt-confirmed" },
          { label: "🔄 重新搜索", action: "unbox-bt-start" },
        ],
      }, 600);
    }
  }, [unboxStep, flowType, btSide, pushMai, pushMsg]);

  /* ── Bubble helper ── */
  const Bubble: React.FC<{ children: React.ReactNode; delay?: number }> = ({ children, delay = 0 }) => (
    <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay, duration: 0.3 }}
      className="flex gap-2 items-start"
    >
      <div className="max-w-[85%] rounded-2xl rounded-bl-md bg-card border border-accent/40 bg-accent/10 px-3 py-2 text-[13px] leading-relaxed">
        {children}
      </div>
    </motion.div>
  );

  /* ── Render a single message ── */
  const renderMessage = (msg: ChatMsg) => {
    const isMai = msg.role === "mai";

    return (
      <div key={msg.id} className={cn("flex gap-2", msg.type === "inline-calibration" ? "flex-row w-full" : isMai ? "flex-row" : "flex-row-reverse")}>
        
        <div className={cn("flex flex-col gap-1.5", msg.type === "inline-calibration" ? "max-w-full w-full" : "max-w-[80%]")}>
          {/* User image */}
          {msg.type === "image" && msg.imageUrl && (
            <motion.div initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }}
              className="rounded-2xl overflow-hidden border border-border/50 max-w-[200px]">
              <img src={msg.imageUrl} alt="上传的照片" className="w-full aspect-[4/3] object-cover" />
              <div className="px-3 py-2 bg-primary text-primary-foreground text-[12px]">{msg.content}</div>
            </motion.div>
          )}

          {/* Guide image (step illustration) */}
          {msg.type === "guide-image" && msg.imageUrl && (
            <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}
              className="rounded-2xl overflow-hidden border border-border/50 bg-card">
              <img src={msg.imageUrl} alt="步骤指引图" className="w-full object-contain max-h-[280px]" />
            </motion.div>
          )}

          {/* Identify result */}
          {msg.type === "identify-result" && msg.identifyResult && (
            <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}
              className="rounded-2xl bg-secondary/60 border border-border/50 rounded-bl-md overflow-hidden">
              <div className="px-3.5 py-2.5 text-[13px] leading-relaxed text-foreground">{msg.content}</div>
              <div className="px-3.5 pb-2.5">
                <p className="text-[11px] text-muted-foreground leading-relaxed">
                  {msg.identifyResult.specInfo}
                </p>
              </div>
            </motion.div>
          )}

          {/* Device info card */}
          {msg.type === "device-card" && msg.deviceCard && (
            <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}
              className="rounded-2xl bg-secondary/60 border border-border/50 rounded-bl-md overflow-hidden">
              <div className="px-3.5 pt-3 pb-1 flex items-center gap-2">
                <div className="w-8 h-8 rounded-xl bg-primary/10 flex items-center justify-center">
                  {msg.deviceCard.firmware ? <Bluetooth className="w-4 h-4 text-primary" /> : <Package className="w-4 h-4 text-primary" />}
                </div>
                <div>
                  <p className="text-[13px] font-bold text-foreground">{msg.deviceCard.model}</p>
                  {msg.deviceCard.firmware && <p className="text-[10px] text-muted-foreground">固件 {msg.deviceCard.firmware}</p>}
                </div>
              </div>
              <div className="px-3.5 py-2 grid grid-cols-2 gap-1.5">
                {[
                  ...(msg.deviceCard.serial ? [{ label: "序列号", value: msg.deviceCard.serial }] : []),
                  { label: "法兰口径", value: `${msg.deviceCard.flangeSize}mm` },
                  { label: "硅胶塞", value: msg.deviceCard.sealSize + " 号" },
                  ...(msg.deviceCard.firmware ? [{ label: "状态", value: "✅ 已连接" }] : []),
                ].map((item) => (
                  <div key={item.label} className="bg-background/60 rounded-lg px-2.5 py-1.5">
                    <p className="text-[9px] text-muted-foreground">{item.label}</p>
                    <p className="text-[11px] font-semibold text-foreground">{item.value}</p>
                  </div>
                ))}
              </div>
              {msg.deviceCard.sellingPoints && msg.deviceCard.sellingPoints.length > 0 && (
                <div className="px-3.5 pb-2 space-y-1">
                  <p className="text-[9px] font-semibold text-muted-foreground uppercase tracking-wider">产品亮点</p>
                  {msg.deviceCard.sellingPoints.map((sp, i) => (
                    <div key={i} className="flex items-center gap-2 px-2.5 py-1.5 rounded-lg bg-primary/5 border border-primary/10">
                      <span className="text-sm">{sp.icon}</span>
                      <p className="text-[11px] text-foreground font-medium">{sp.text}</p>
                    </div>
                  ))}
                </div>
              )}
              <div className="px-3.5 pb-2.5 text-[13px] leading-relaxed text-foreground">{msg.content}</div>
            </motion.div>
          )}

          {/* Doc links */}
          {msg.type === "doc-links" && msg.docLinks && (
            <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}
              className="rounded-2xl bg-secondary/60 border border-border/50 rounded-bl-md overflow-hidden">
              <div className="px-3.5 py-2.5 text-[13px] leading-relaxed text-foreground">{msg.content}</div>
              <div className="px-3.5 pb-3 space-y-1.5">
                {msg.docLinks.map((doc, i) => (
                  <motion.button key={i}
                    type="button"
                    initial={{ opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: 0.2 + i * 0.1 }}
                    className="w-full flex items-center gap-2.5 px-3 py-2 rounded-xl bg-background/60 border border-border/30 hover:border-primary/30 hover:bg-primary/5 transition-colors text-left"
                    onClick={() => openDocLinkInMediaViewer(navigate, doc)}
                  >
                    <span className="text-lg">{doc.icon}</span>
                    <div className="flex-1 min-w-0">
                      <p className="text-[12px] font-semibold text-foreground truncate">{doc.title}</p>
                      <p className="text-[10px] text-muted-foreground truncate">{doc.desc}</p>
                    </div>
                    <span className="text-[10px] text-primary font-medium">查看 →</span>
                  </motion.button>
                ))}
              </div>
            </motion.div>
          )}

          {/* Inline calibration */}
          {msg.type === "inline-calibration" && (
            <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}
              className="w-full max-w-none">
              <InlineCalibration onComplete={handleCalibrationComplete} />
            </motion.div>
          )}

          {/* Text / choice bubble */}
          {(!msg.type || msg.type === "text" || msg.type === "choice") && (
            <div className={cn(
              "rounded-2xl px-3.5 py-2.5 text-[13px] leading-relaxed whitespace-pre-line",
              isMai ? "bg-card border border-accent/40 bg-accent/10 rounded-bl-md text-foreground"
                    : "bg-primary text-primary-foreground rounded-br-md"
            )}>
              {msg.content}
            </div>
          )}

          {/* Knowledge card CTA */}
          {msg.knowledgeKey && (
            <motion.button initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }} onClick={() => handleKnowledgeClick(msg.knowledgeKey!)}
              className="self-start rounded-xl bg-primary/10 border border-primary/20 px-3 py-2 text-[12px] font-semibold text-primary hover:bg-primary/15 transition-colors">
              📖 查看{knowledgeCards[msg.knowledgeKey]?.title || "详情"}
            </motion.button>
          )}

          {/* Choice buttons — only show on the LAST choice message */}
          {msg.type === "choice" && msg.choiceOptions && msg.id === lastChoiceId && (
            <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }} className="flex flex-wrap gap-2 mt-1">
              {msg.choiceOptions.map((opt) => (
                <button key={opt.action} onClick={() => handleChoiceAction(opt.action)}
                  className="px-3 py-1.5 rounded-xl bg-primary/10 border border-primary/20 text-[12px] font-semibold text-primary hover:bg-primary/20 transition-colors">
                  {opt.label}
                </button>
              ))}
            </motion.div>
          )}
        </div>
      </div>
    );
  };

  // Find the last choice message id to only show pills on the latest choice
  const lastChoiceId = [...messages].reverse().find(m => m.type === "choice")?.id ?? null;

  // Determine if we need a quick-advance button
  const needsInput = measureStep >= 0;

  return (
    <div ref={containerRef} className="space-y-3">
      {messages.map(renderMessage)}

      {/* Streaming indicator */}
      {streaming && (
        <div className="flex gap-2">
          <div className="rounded-2xl bg-card border border-accent/40 bg-accent/10 rounded-bl-md px-3.5 py-2.5">
            <div className="flex gap-1.5 items-center">
              <Sparkles className="w-3 h-3 text-primary animate-pulse" />
              <div className="flex gap-1">
                {[0, 1, 2].map((i) => (
                  <motion.div key={i} className="w-1.5 h-1.5 rounded-full bg-muted-foreground"
                    animate={{ opacity: [0.3, 1, 0.3] }}
                    transition={{ duration: 1, repeat: Infinity, delay: i * 0.2 }} />
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Photo menu */}
      <AnimatePresence>
        {showPhotoMenu && (
          <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: 12 }}
            className="rounded-2xl bg-card border border-border shadow-lg p-3 space-y-2.5">
            <div className="flex items-center justify-between">
              <span className="text-[11px] font-bold text-foreground flex items-center gap-1.5">
                <Camera className="w-3.5 h-3.5 text-primary" /> 选择识别方式
              </span>
              <button onClick={() => setShowPhotoMenu(false)} className="text-muted-foreground hover:text-foreground">
                <X className="w-3.5 h-3.5" />
              </button>
            </div>
            <div className="flex gap-2">
              <Button size="sm" onClick={() => cameraInputRef.current?.click()} className="flex-1 rounded-xl h-9 gap-1.5 text-xs">
                <Camera className="w-3.5 h-3.5" /> 拍照
              </Button>
              <Button size="sm" variant="outline" onClick={() => fileInputRef.current?.click()} className="flex-1 rounded-xl h-9 gap-1.5 text-xs">
                <Upload className="w-3.5 h-3.5" /> 上传
              </Button>
            </div>
            <div className="space-y-1">
              <span className="text-[10px] text-muted-foreground font-medium">演示样本</span>
              <div className="flex gap-1.5">
                {arMockResults.map((item) => (
                  <button key={item.mockImage} onClick={() => handleDemoIdentify(item)}
                    className="flex-1 rounded-lg overflow-hidden border border-border/50 hover:border-primary/40 transition-colors group">
                    <div className="aspect-[4/3] overflow-hidden bg-secondary/50">
                      <img src={mockImageMap[item.mockImage]} alt={item.partName}
                        className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200" />
                    </div>
                    <div className="py-0.5 bg-card">
                      <p className="text-[9px] font-semibold text-foreground text-center">{item.partIcon} {item.partName}</p>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Quick advance button for guided steps */}
      {needsInput && !streaming && !showPhotoMenu && (
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.3 }} className="flex justify-center">
          <Button onClick={() => handleTextInput("好的，继续～")} size="sm" className="rounded-2xl px-5 text-xs font-bold">
            ✅ 继续下一步
          </Button>
        </motion.div>
      )}

      {/* Hidden file inputs */}
      <input ref={cameraInputRef} type="file" accept="image/*" capture="environment" className="hidden" onChange={handleFileChange} />
      <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={handleFileChange} />

      {/* Sub-sheets */}
      <KnowledgeCardSheet data={activeKnowledge} open={knowledgeOpen} onClose={() => setKnowledgeOpen(false)} />
      <BluetoothSearchDrawer
        open={showBtDrawer} side={btSide} currentDeviceId=""
        onClose={() => setShowBtDrawer(false)}
        onConnect={(deviceId, deviceName, rssi) => void handleBtConnected(deviceId, deviceName, rssi)}
        onDisconnect={(deviceId) => {
          const store = deviceStore.get();
          if (store.L?.deviceId === deviceId) deviceStore.setConnected("L", false);
          if (store.R?.deviceId === deviceId) deviceStore.setConnected("R", false);
        }}
      />
    </div>
  );
});

export default InlineDeviceFlow;
