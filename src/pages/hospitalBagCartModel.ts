export type HospitalBagCartTone = "rose" | "mint" | "sky";

export type HospitalBagCartItem = {
  id: string;
  name: string;
  desc: string;
  qty: number;
  price: number;
  keywords?: string[];
};

export type HospitalBagCartGroup = {
  title: string;
  tone: HospitalBagCartTone;
  items: HospitalBagCartItem[];
};

export type HospitalBagCartTotals = {
  subtotal: number;
  itemCount: number;
  discount: number;
  shipping: number;
  total: number;
};

export const initialHospitalBagCartGroups: HospitalBagCartGroup[] = [
  {
    title: "妈妈护理",
    tone: "rose",
    items: [
      { id: "mom-pad", name: "产褥垫组合装", desc: "入院与产后前几天使用", qty: 1, price: 59.9, keywords: ["产褥垫", "护理垫"] },
      { id: "mom-sanitary", name: "产妇卫生巾", desc: "夜用加长款，按住院天数准备", qty: 1, price: 39.9, keywords: ["卫生巾"] },
      { id: "mom-underwear", name: "一次性内裤", desc: "高腰柔软，产后更方便更换", qty: 1, price: 49.9, keywords: ["内裤", "一次性内裤"] },
      { id: "mom-wipes", name: "产后护理湿巾", desc: "温和清洁，适合住院随身包", qty: 1, price: 29.9, keywords: ["湿巾", "护理湿巾"] },
      { id: "mom-bottle", name: "产后冲洗瓶", desc: "产后清洁更方便，是否带去医院按医院建议", qty: 1, price: 39.9, keywords: ["冲洗瓶"] },
      { id: "mom-briefs", name: "高腰收腹内裤", desc: "不压腹，更适合产后恢复期穿着", qty: 1, price: 69.9, keywords: ["收腹", "高腰"] },
    ],
  },
  {
    title: "宝宝出院",
    tone: "mint",
    items: [
      { id: "baby-diaper", name: "新生儿纸尿裤", desc: "NB 码小包装，避免带太多", qty: 1, price: 59.9, keywords: ["纸尿裤", "尿不湿"] },
      { id: "baby-wipes", name: "婴儿柔湿巾", desc: "无香精，适合换尿裤场景", qty: 1, price: 29.9, keywords: ["婴儿湿巾", "柔湿巾"] },
      { id: "baby-towel", name: "棉柔巾", desc: "洗脸、擦手、护理都可用", qty: 1, price: 29.9, keywords: ["棉柔巾"] },
      { id: "baby-blanket", name: "宝宝出院包被", desc: "柔软包裹，按季节搭配外层", qty: 1, price: 129.0, keywords: ["包被"] },
      { id: "baby-clothes", name: "新生儿连体衣礼盒", desc: "出院和回家第一周可替换穿", qty: 1, price: 159.0, keywords: ["连体衣", "衣服", "礼盒"] },
      { id: "baby-bath-towel", name: "婴儿浴巾", desc: "洗澡、包裹和保暖都可用", qty: 1, price: 59.9, keywords: ["浴巾"] },
    ],
  },
  {
    title: "母乳喂养",
    tone: "sky",
    items: [
      { id: "milk-pad", name: "防溢乳垫", desc: "母乳或混合喂养可先备小包装", qty: 1, price: 39.9, keywords: ["防溢乳垫", "乳垫"] },
      { id: "milk-cream", name: "乳头护理霜", desc: "哺乳初期不适时可咨询后使用", qty: 1, price: 49.9, keywords: ["乳头霜", "护理霜"] },
      { id: "milk-storage", name: "储奶袋", desc: "返家后储奶备用，住院可少量准备", qty: 1, price: 49.9, keywords: ["储奶袋"] },
      { id: "milk-pump", name: "便携式吸奶器", desc: "可选备用项，是否带去医院先问医院", qty: 1, price: 699.0, keywords: ["吸奶器"] },
      { id: "milk-bra", name: "哺乳文胸", desc: "产后和哺乳初期更舒适", qty: 1, price: 159.0, keywords: ["哺乳文胸", "文胸"] },
      { id: "milk-bottle", name: "宽口径奶瓶", desc: "混合喂养或返家后备用", qty: 1, price: 89.9, keywords: ["奶瓶"] },
    ],
  },
];

export function cloneHospitalBagCartGroups(groups: HospitalBagCartGroup[]): HospitalBagCartGroup[] {
  return groups.map((group) => ({
    ...group,
    items: group.items.map((item) => ({ ...item, keywords: item.keywords ? [...item.keywords] : undefined })),
  }));
}

export function removeHospitalBagCartItem(groups: HospitalBagCartGroup[], itemId: string): HospitalBagCartGroup[] {
  return groups.map((group) => ({ ...group, items: group.items.filter((item) => item.id !== itemId) }));
}

export function calculateHospitalBagCartTotals(groups: HospitalBagCartGroup[]): HospitalBagCartTotals {
  const subtotal = Number(groups.reduce((sum, group) => sum + group.items.reduce((groupSum, item) => groupSum + item.price * item.qty, 0), 0).toFixed(2));
  const itemCount = groups.reduce((sum, group) => sum + group.items.reduce((groupSum, item) => groupSum + item.qty, 0), 0);
  const discount = itemCount > 0 ? Number((subtotal * 0.08).toFixed(2)) : 0;
  const shipping = 0;
  const total = Number((subtotal - discount + shipping).toFixed(2));
  return { subtotal, itemCount, discount, shipping, total };
}
