// Mock data for smart manual search cards
export interface ManualCard {
  id: string;
  title: string;
  icon: string;
  summary: string;
  tags: string[];
  detail: KnowledgeCardData;
}

export interface KnowledgeCardData {
  title: string;
  icon: string;
  sections: { heading: string; content: string }[];
  tip?: string;
}

export const knowledgeCards: Record<string, KnowledgeCardData> = {
  flange: {
    title: "法兰安装与选择指南",
    icon: "🔧",
    sections: [
      { heading: "📐 尺寸选择", content: "测量乳头直径（不含乳晕），加 2-4mm 即为推荐法兰口径。常见尺寸 21/24/27/30mm。" },
      { heading: "✅ 正确安装", content: "确保乳头居中通过法兰管道，无侧压或摩擦感。吸力启动后乳头应在管道内自由伸缩。" },
      { heading: "⚠️ 不适信号", content: "如出现乳头发白、疼痛、或乳晕被过度拉入管道，说明尺寸不合适，请更换。" },
    ],
    tip: "产后乳房大小会变化，建议每 4-6 周重新测量一次哦～",
  },
  duckbill: {
    title: "鸭嘴阀清洗与更换",
    icon: "🦆",
    sections: [
      { heading: "📌 清洗方法", content: "每次使用后用温水+奶瓶清洗液浸泡 5 分钟，自然晾干。避免用力拉扯阀片。" },
      { heading: "⏰ 更换周期", content: "建议每 2-4 周更换一次。当阀片出现变形、裂纹或吸力明显下降时需立即更换。" },
      { heading: "🔍 自检方法", content: "捏住鸭嘴阀两侧，松开后应迅速弹回。如果弹回缓慢或无法完全闭合，说明需要更换。" },
    ],
    tip: "你当前的鸭嘴阀已使用 18 天，建议本周内更换哦～ 💕",
  },
  seal: {
    title: "硅胶塞选号指南",
    icon: "📐",
    sections: [
      { heading: "📏 测量方法", content: "测量乳头直径后 +2mm 即为推荐塞号。常见尺寸范围 19-27mm。" },
      { heading: "🎯 合适标准", content: "佩戴后乳头周围应有均匀轻柔的密封感，不应有明显压痕或缝隙漏气。" },
      { heading: "🔄 更换信号", content: "硅胶老化变硬、出现裂纹或密封性下降时需更换，一般使用寿命 2-3 个月。" },
    ],
    tip: "不同品牌的塞号可能有差异，建议以实测为准～",
  },
  measurement: {
    title: "乳头尺寸正确测量指南",
    icon: "📏",
    sections: [
      { heading: "📋 准备工作", content: "准备一把软尺或专用测量卡，在哺乳或吸奶后乳头充分伸展时测量最准确。" },
      { heading: "📐 步骤一：找到测量位置", content: "将软尺或测量卡轻放在乳头根部（乳头与乳晕的交界处），不要包含乳晕部分。" },
      { heading: "📏 步骤二：测量直径", content: "测量乳头最宽处的直径（水平方向），单位为毫米。左右两侧都需要分别测量。" },
      { heading: "🔢 步骤三：计算推荐尺寸", content: "将测量到的乳头直径 +2~4mm，即为推荐的法兰/硅胶塞口径。例如乳头直径 17mm → 推荐 19-21mm 法兰。" },
      { heading: "✅ 步骤四：验证舒适度", content: "试戴后检查：乳头应在管道内自由伸缩，无侧压摩擦，乳晕不被过度拉入。如有不适请调整尺寸。" },
    ],
    tip: "产后乳房大小会变化，建议每 4-6 周重新测量一次，确保始终使用最合适的尺寸哦～ 💕",
  },
};

export const manualCards: ManualCard[] = [
  {
    id: "mc1",
    title: "如何正确安装法兰",
    icon: "🔧",
    summary: "确保法兰与乳房贴合，乳头居中，无挤压感。",
    tags: ["法兰", "安装"],
    detail: knowledgeCards.flange,
  },
  {
    id: "mc2",
    title: "鸭嘴阀清洗与更换",
    icon: "🦆",
    summary: "鸭嘴阀建议每 2-4 周更换一次，每次使用后用温水冲洗。",
    tags: ["鸭嘴阀", "清洗", "更换"],
    detail: knowledgeCards.duckbill,
  },
  {
    id: "mc3",
    title: "硅胶塞选号指南",
    icon: "📐",
    summary: "测量乳头直径后 +2mm 即为推荐塞号，常见尺寸 19-27mm。",
    tags: ["硅胶塞", "尺寸"],
    detail: knowledgeCards.seal,
  },
  {
    id: "mc4",
    title: "蓝牙配对故障排除",
    icon: "📶",
    summary: "长按主机电源键 5 秒重置蓝牙，确保手机蓝牙已开启。",
    tags: ["蓝牙", "配对", "故障"],
    detail: {
      title: "蓝牙配对故障排除",
      icon: "📶",
      sections: [
        { heading: "🔄 重置蓝牙", content: "长按主机电源键 5 秒直至指示灯快闪，进入配对模式。" },
        { heading: "📱 手机设置", content: "确保手机蓝牙已开启，并在附近无其他已配对的同型号设备。" },
        { heading: "🗑️ 清除配对", content: "在手机蓝牙设置中忘记该设备，然后重新搜索配对。" },
      ],
      tip: "如果反复无法连接，尝试重启手机后再配对。",
    },
  },
  {
    id: "mc5",
    title: "吸力模式说明",
    icon: "💨",
    summary: "刺激模式模拟宝宝快速吮吸，深度模式提供持续负压。",
    tags: ["模式", "吸力"],
    detail: {
      title: "吸力模式说明",
      icon: "💨",
      sections: [
        { heading: "⚡ 刺激模式", content: "模拟宝宝快速短促吮吸，帮助触发奶阵反射，通常持续 1-2 分钟。" },
        { heading: "🌊 深度模式", content: "提供持续稳定负压，模拟宝宝深度吮吸节奏，高效排空乳汁。" },
        { heading: "🔀 自动切换", content: "智能模式下设备会根据流速自动在刺激与深度模式间切换。" },
      ],
    },
  },
];

// Photo identification mock results
export interface PhotoIdentifyResult {
  partName: string;
  partIcon: string;
  description: string;
  suggestion: string;
  knowledgeKey: string; // maps to knowledgeCards
  chatCardContent: string;
  confidence: number; // 0-100 (internal, not displayed)
  mockImage: string; // import path key
  specInfo: string; // common spec description text for this part type
}

// Keep legacy alias
export type ARResult = PhotoIdentifyResult;

export const arMockResults: PhotoIdentifyResult[] = [
  {
    partName: "鸭嘴阀",
    partIcon: "🦆",
    description: "单向止回阀，防止奶液回流",
    suggestion: "建议每 2-4 周更换，当前使用已 18 天",
    knowledgeKey: "duckbill",
    confidence: 97.3,
    mockImage: "duckbill",
    specInfo: "鸭嘴阀是单向止回阀，用于防止奶液回流。常见材质为食品级硅胶，建议每 2-4 周更换一次。当阀片出现变形、裂纹或弹性下降时需立即更换。",
    chatCardContent:
      "🦆 **鸭嘴阀清洗与更换指南**\n\n我帮你识别了鸭嘴阀配件！以下是专属建议：\n\n📌 **清洗方法**：每次使用后用温水+奶瓶清洗液浸泡5分钟，自然晾干\n\n⏰ **更换周期**：建议每 2-4 周更换一次。当阀片出现变形、裂纹或吸力明显下降时需立即更换\n\n💡 **小贴士**：你当前的鸭嘴阀已使用 18 天，建议本周内更换哦～\n\n需要我帮你加入购物清单吗？ 💕",
  },
  {
    partName: "法兰",
    partIcon: "🔧",
    description: "吸乳护罩，确保舒适贴合与高效吸乳",
    suggestion: "当前法兰 24mm，尺寸匹配良好",
    knowledgeKey: "flange",
    confidence: 95.1,
    mockImage: "flange",
    specInfo: "法兰（吸乳护罩）用于贴合乳房引导吸乳，常见口径有 21/24/27/30mm。选择时需根据乳头直径 +2~4mm 确定合适尺寸，确保乳头居中无侧压。",
    chatCardContent:
      "🔧 **法兰安装与选择指南**\n\n我帮你识别了法兰配件！以下是专属建议：\n\n📐 **尺寸确认**：你当前使用的 24mm 法兰匹配良好\n\n✅ **安装要点**：确保乳头居中通过法兰管道，无侧压或摩擦感\n\n💡 **小贴士**：产后乳房大小会变化，建议每 4-6 周重新测量一次哦～ 💕",
  },
  {
    partName: "硅胶塞",
    partIcon: "📐",
    description: "密封插件，适配不同乳头尺寸",
    suggestion: "当前 M 号硅胶塞，密封性良好",
    knowledgeKey: "seal",
    confidence: 93.8,
    mockImage: "seal",
    specInfo: "硅胶塞是密封插件，用于适配不同乳头尺寸。常见尺寸范围 19-27mm，材质为液态硅胶。佩戴后应有均匀密封感，使用寿命一般为 2-3 个月。",
    chatCardContent:
      "📐 **硅胶塞选号指南**\n\n我帮你识别了硅胶塞配件！以下是专属建议：\n\n📏 **当前型号**：M 号 (21mm)，密封性良好\n\n🎯 **合适标准**：佩戴后乳头周围应有均匀轻柔的密封感\n\n💡 **小贴士**：不同品牌的塞号可能有差异，建议以实测为准～ 💕",
  },
];

// Mai chat responses for device topics
export const deviceChatResponses: Record<string, { reply: string; knowledgeKey: string }> = {
  flange: {
    reply: "关于法兰，我来帮你详细了解一下～",
    knowledgeKey: "flange",
  },
  duckbill: {
    reply: "鸭嘴阀的清洗和更换很重要哦，一起来看看～",
    knowledgeKey: "duckbill",
  },
  seal: {
    reply: "硅胶塞的选号很关键，让我来教你怎么选～",
    knowledgeKey: "seal",
  },
  measurement: {
    reply: "好的，我来一步步教你正确测量乳头尺寸～ 这很重要哦，合适的尺寸能让吸奶更舒适高效 💕",
    knowledgeKey: "measurement",
  },
};

// Step-by-step measurement guide for Mai conversation
export const measurementSteps = [
  { step: 1, instruction: "首先，请准备一把软尺或专用测量卡。最佳测量时机是在哺乳或吸奶后，乳头充分伸展的时候。\n\n准备好了告诉我哦～ 👍", waitPrompt: "准备好了" },
  { step: 2, instruction: "很好！现在请将软尺或测量卡轻放在乳头根部——也就是乳头与乳晕的交界处。\n\n⚠️ 注意：不要包含乳晕部分哦！\n\n放好了就告诉我～", waitPrompt: "放好了" },
  { step: 3, instruction: "接下来测量乳头最宽处的直径（水平方向），单位是毫米。\n\n📏 左右两侧都需要分别测量哦～\n\n测量完成后把数值告诉我吧！比如『左边17mm，右边18mm』", waitPrompt: "测量完成" },
  { step: 4, instruction: "收到！根据你的测量结果，将直径 +2~4mm 就是推荐的法兰/硅胶塞口径。\n\n例如：乳头直径 17mm → 推荐 19-21mm 法兰\n\n你可以试戴一下，我来帮你检查是否合适～ 戴好了告诉我！", waitPrompt: "戴好了" },
  { step: 5, instruction: "最后一步验证舒适度 ✅\n\n请检查以下几点：\n• 乳头在管道内能自由伸缩吗？\n• 有没有侧压或摩擦感？\n• 乳晕是否被过度拉入？\n\n如果都没问题，说明尺寸合适！🎉\n如果有不适，可能需要调整尺寸，告诉我具体情况我来帮你分析～", waitPrompt: "" },
];
