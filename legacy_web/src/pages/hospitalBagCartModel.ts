export type HospitalBagCartTone = "rose" | "mint" | "sky";

export type HospitalBagCartItem = {
  id: string;
  name: string;
  desc: string;
  qty: number;
  price: number;
  image_url?: string;
  image_alt?: string;
  currency?: "CNY" | "USD" | string;
  price_label?: string;
  sale_price_label?: string;
  official_price_usd?: number;
  sale_price_usd?: number;
  product_url?: string;
  sku_id?: string;
  model?: string;
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
  currency_totals: HospitalBagCartCurrencyTotal[];
  mixed_currency: boolean;
};

export type HospitalBagCartCurrencyTotal = {
  currency: string;
  subtotal: number;
  itemCount: number;
  discount: number;
  shipping: number;
  total: number;
};

export const hospitalBagCartUsdToCnyRate = 6.8;

const momcozyPumpImageUrls: Record<string, string> = {
  "milk-pump": "https://momcozy.com/cdn/shop/files/MomcozyMoblieFlow_BreastPump_7.jpg?v=1776163451",
  "pump-s9-pro": "https://momcozy.com/cdn/shop/files/S9pro_3ff43646-b9be-4b4d-a8d8-918834d887a0.jpg?v=1699943493",
  "pump-s12-pro-quick": "https://momcozy.com/cdn/shop/files/1.1_a787cf6f-0656-44dc-86e9-0a4f75846cbc.jpg?v=1776744837",
  "pump-m5-smart": "https://momcozy.com/cdn/shop/files/1_b8f691a7-6acf-44dc-acbc-ed6bf82e8a9d.jpg?v=1760428066",
  "pump-m6": "https://momcozy.com/cdn/shop/files/01_56489eac-5396-4685-aacc-3c6c14c39930.jpg?v=1775025039",
  "pump-v1-pro": "https://momcozy.com/cdn/shop/files/lQDPJws-Zh7cFX_NBdrNBLCwLR71U5WToVIG-TXf9_H4AA_1200_1498.jpg?v=1755159282",
  "pump-m9": "https://momcozy.com/cdn/shop/files/MomcozyMoblieFlow_BreastPump_7.jpg?v=1776163451",
  "pump-w1": "https://momcozy.com/cdn/shop/files/1._1_app2.jpg?v=1777030861",
  "pump-air-1": "https://momcozy.com/cdn/shop/files/MomcozyAir1Ultra-slimBreastPump_1.png?v=1740971384",
};

const defaultHospitalBagPumpItem: HospitalBagCartItem = {
  id: "pump-m9",
  name: "Momcozy M9 吸奶器",
  desc: "便携穿戴式双边吸乳，返家后排奶/储奶备用；是否带去医院先问医院",
  qty: 1,
  price: 1087.93,
  model: "M9",
  keywords: ["吸奶器", "便携式吸奶器", "M9", "Mobile Flow"],
};

const cartProductImageUrls: Record<string, string> = {
  "mom-pad": "https://momcozy.com/cdn/shop/files/01_e3747022-14ff-4a12-a503-044276f89265.webp?v=1779352318",
  "mom-sanitary": "https://momcozy.com/cdn/shop/files/01_e3747022-14ff-4a12-a503-044276f89265.webp?v=1779352318",
  "mom-underwear": "https://momcozy.com/cdn/shop/files/PK006-1_-1.png?v=1779351545",
  "mom-wipes": "https://momcozy.com/cdn/shop/files/12b.jpg?v=1779353160",
  "mom-bottle": "https://momcozy.com/cdn/shop/files/01_e3747022-14ff-4a12-a503-044276f89265.webp?v=1779352318",
  "mom-briefs": "https://momcozy.com/cdn/shop/files/b58ce7b99582c961375527c3c6b27ebb_9023fff7-0f2e-42c1-864e-fd2a7a732e72.png?v=1779351709",
  "baby-diaper": "https://babycozy.com/cdn/shop/files/1.1_8e53efbf-da7d-4997-a472-3a335bedbf31.jpg?v=1711696033",
  "baby-wipes": "https://momcozy.com/cdn/shop/files/12b.jpg?v=1779353160",
  "baby-towel": "https://momcozy.com/cdn/shop/files/1_d4e469a4-e733-4cf1-8863-c3c5256eca2a.jpg?v=1779353358",
  "baby-blanket": "https://momcozy.com/cdn/shop/files/1-1_abb6b92a-ac07-4b73-b3a5-7d995989b721.jpg?v=1779353389",
  "baby-blanket-basic": "https://momcozy.com/cdn/shop/files/1_7732d4e1-f5a7-4a75-8f7e-c888eed37548.jpg?v=1779352173",
  "baby-clothes": "https://momcozy.com/cdn/shop/files/1_f348eb24-2845-4b7b-8cff-6f78510fa1fa.webp?v=1779422192",
  "baby-bath-towel": "https://momcozy.com/cdn/shop/files/yujin.jpg?v=1779353668",
  "milk-pad": "https://momcozy.com/cdn/shop/files/5_dbb18aeb-7e96-4c95-a1a7-5a9378875b7b.jpg?v=1779352202",
  "milk-cream": "https://momcozy.com/cdn/shop/files/MomcozyNippleCreramforBreastfeeding_8.jpg?v=1779352434",
  "milk-storage": "https://momcozy.com/cdn/shop/files/13_5b267527-b032-4c66-bec8-21c675a15007.webp?v=1779430748",
  "milk-bra": "https://momcozy.com/cdn/shop/files/yn21_ae9a5331-7afc-4dde-abc1-5136e356bcbe.jpg?v=1736236303",
  "milk-bottle": "https://momcozy.com/cdn/shop/files/619nKXnpNKL._SL1500.jpg?v=1779354235",
};

const cartProductImageSpecs: Record<string, { label: string; bg: string; accent: string; shape: "pack" | "bottle" | "cloth" | "soft" }> = {
  "mom-pad": { label: "产褥垫", bg: "#fff0f5", accent: "#c9678e", shape: "soft" },
  "mom-sanitary": { label: "卫生巾", bg: "#fff5f8", accent: "#b84d73", shape: "soft" },
  "mom-underwear": { label: "内裤", bg: "#fff4ed", accent: "#bf7a5a", shape: "cloth" },
  "mom-wipes": { label: "护理湿巾", bg: "#f6f3ff", accent: "#8970b9", shape: "pack" },
  "mom-bottle": { label: "冲洗瓶", bg: "#edf8fb", accent: "#4193a7", shape: "bottle" },
  "mom-briefs": { label: "高腰内裤", bg: "#fff4ed", accent: "#a96b58", shape: "cloth" },
  "baby-diaper": { label: "纸尿裤", bg: "#edf9f5", accent: "#267c68", shape: "soft" },
  "baby-wipes": { label: "婴儿湿巾", bg: "#eefaf7", accent: "#3c9882", shape: "pack" },
  "baby-towel": { label: "棉柔巾", bg: "#f1fbff", accent: "#4a93b5", shape: "pack" },
  "baby-blanket": { label: "包被", bg: "#fff8e8", accent: "#c89a3c", shape: "cloth" },
  "baby-blanket-basic": { label: "基础包被", bg: "#fff8e8", accent: "#b88a32", shape: "cloth" },
  "baby-clothes": { label: "连体衣", bg: "#f5f7ff", accent: "#6c7db7", shape: "cloth" },
  "baby-bath-towel": { label: "浴巾", bg: "#eef8ff", accent: "#4385b4", shape: "cloth" },
  "milk-pad": { label: "防溢乳垫", bg: "#edf6ff", accent: "#2f6fa8", shape: "soft" },
  "milk-cream": { label: "护理霜", bg: "#fff6ee", accent: "#c47a45", shape: "bottle" },
  "milk-storage": { label: "储奶袋", bg: "#edf7ff", accent: "#3e83ad", shape: "pack" },
  "milk-bra": { label: "哺乳文胸", bg: "#fff0f6", accent: "#b45c86", shape: "cloth" },
  "milk-bottle": { label: "奶瓶", bg: "#eff9ff", accent: "#3c8baa", shape: "bottle" },
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
      defaultHospitalBagPumpItem,
      { id: "milk-bra", name: "哺乳文胸", desc: "产后和哺乳初期更舒适", qty: 1, price: 159.0, keywords: ["哺乳文胸", "文胸"] },
      { id: "milk-bottle", name: "宽口径奶瓶", desc: "混合喂养或返家后备用", qty: 1, price: 89.9, keywords: ["奶瓶"] },
    ],
  },
];

export function normalizeHospitalBagCartGroups(groups: HospitalBagCartGroup[]): HospitalBagCartGroup[] {
  return groups.map((group) => ({
    ...group,
    items: group.items.map(normalizeHospitalBagCartItem),
  }));
}

function normalizeHospitalBagCartItem(item: HospitalBagCartItem): HospitalBagCartItem {
  if (item.id !== "milk-pump" && item.name.trim() !== "便携式吸奶器") return item;
  const qty = Number.isFinite(item.qty) && item.qty > 0 ? item.qty : defaultHospitalBagPumpItem.qty;
  return { ...defaultHospitalBagPumpItem, qty };
}

export function cloneHospitalBagCartGroups(groups: HospitalBagCartGroup[]): HospitalBagCartGroup[] {
  return normalizeHospitalBagCartGroups(groups).map((group) => ({
    ...group,
    items: group.items.map((item) => ({ ...item, keywords: item.keywords ? [...item.keywords] : undefined })),
  }));
}

export function removeHospitalBagCartItem(groups: HospitalBagCartGroup[], itemId: string): HospitalBagCartGroup[] {
  return groups.map((group) => ({ ...group, items: group.items.filter((item) => item.id !== itemId) }));
}

export function calculateHospitalBagCartTotals(groups: HospitalBagCartGroup[]): HospitalBagCartTotals {
  const subtotal = Number(
    groups
      .reduce((sum, group) => sum + group.items.reduce((groupSum, item) => groupSum + hospitalBagCartItemPriceCny(item) * item.qty, 0), 0)
      .toFixed(2),
  );
  const itemCount = groups.reduce((sum, group) => sum + group.items.reduce((groupSum, item) => groupSum + item.qty, 0), 0);
  const discount = itemCount > 0 ? Number((subtotal * 0.08).toFixed(2)) : 0;
  const shipping = 0;
  const total = Number((subtotal - discount + shipping).toFixed(2));
  const currency_totals = [{ currency: "CNY", subtotal, itemCount, discount, shipping, total }];
  return { subtotal, itemCount, discount, shipping, total, currency_totals, mixed_currency: false };
}

export function hospitalBagCartItemPriceCny(item: HospitalBagCartItem): number {
  if (normalizeHospitalBagCartCurrency(item.currency) === "USD") {
    return Number((item.price * hospitalBagCartUsdToCnyRate).toFixed(2));
  }
  return item.price;
}

export function normalizeHospitalBagCartCurrency(currency: HospitalBagCartItem["currency"]): string {
  const normalized = String(currency || "CNY").trim().toUpperCase();
  return normalized === "USD" ? "USD" : "CNY";
}

export function formatHospitalBagCartMoney(amount: number, currency: string): string {
  if (normalizeHospitalBagCartCurrency(currency) === "USD") return `$${amount.toFixed(2)}`;
  return `¥${amount.toFixed(2)}`;
}

export function formatHospitalBagCartItemPrice(item: HospitalBagCartItem): string {
  if (normalizeHospitalBagCartCurrency(item.currency) === "USD") {
    return formatHospitalBagCartMoney(hospitalBagCartItemPriceCny(item), "CNY");
  }
  const label = item.price_label?.trim();
  if (label) return label;
  return formatHospitalBagCartMoney(item.price, normalizeHospitalBagCartCurrency(item.currency));
}

export function formatHospitalBagCartTotals(total: HospitalBagCartTotals): string {
  return formatHospitalBagCartMoney(total.total, "CNY");
}

export function resolveHospitalBagCartItemImage(item: HospitalBagCartItem): string {
  const explicit = item.image_url?.trim();
  if (explicit) return explicit;
  const pumpImage = momcozyPumpImageUrls[item.id];
  if (pumpImage) return pumpImage;
  const productImage = cartProductImageUrls[item.id];
  if (productImage) return productImage;
  const spec = cartProductImageSpecs[item.id] ?? {
    label: item.name.slice(0, 4),
    bg: "#f8f1f5",
    accent: "#8a6d7a",
    shape: "pack" as const,
  };
  return createCartProductImageDataUrl(spec);
}

export function resolveHospitalBagCartItemImageAlt(item: HospitalBagCartItem): string {
  return item.image_alt?.trim() || item.name;
}

function createCartProductImageDataUrl(spec: { label: string; bg: string; accent: string; shape: "pack" | "bottle" | "cloth" | "soft" }): string {
  const shape = cartProductShapeSvg(spec.shape, spec.accent);
  const safeLabel = escapeSvgText(spec.label);
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="160" height="160" viewBox="0 0 160 160">
      <rect width="160" height="160" rx="28" fill="${spec.bg}"/>
      <circle cx="126" cy="26" r="28" fill="#ffffff" opacity=".62"/>
      <circle cx="26" cy="132" r="34" fill="#ffffff" opacity=".48"/>
      ${shape}
      <text x="80" y="137" text-anchor="middle" font-family="Arial, 'PingFang SC', sans-serif" font-size="16" font-weight="700" fill="#4a3340">${safeLabel}</text>
    </svg>
  `.trim();
  return `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svg)}`;
}

function cartProductShapeSvg(shape: "pack" | "bottle" | "cloth" | "soft", accent: string): string {
  if (shape === "bottle") {
    return `
      <rect x="67" y="34" width="26" height="18" rx="7" fill="#fff"/>
      <rect x="58" y="48" width="44" height="64" rx="15" fill="#fff" stroke="${accent}" stroke-width="5"/>
      <path d="M68 66h24M68 80h24M68 94h18" stroke="${accent}" stroke-width="5" stroke-linecap="round" opacity=".72"/>
    `;
  }
  if (shape === "cloth") {
    return `
      <path d="M48 55c13-17 51-17 64 0l-11 13v43H59V68L48 55z" fill="#fff" stroke="${accent}" stroke-width="5" stroke-linejoin="round"/>
      <path d="M68 57c4 6 20 6 24 0" fill="none" stroke="${accent}" stroke-width="5" stroke-linecap="round"/>
    `;
  }
  if (shape === "soft") {
    return `
      <rect x="43" y="52" width="74" height="54" rx="23" fill="#fff" stroke="${accent}" stroke-width="5"/>
      <path d="M59 78c10-10 32-10 42 0" fill="none" stroke="${accent}" stroke-width="5" stroke-linecap="round" opacity=".75"/>
    `;
  }
  return `
    <rect x="45" y="50" width="70" height="60" rx="14" fill="#fff" stroke="${accent}" stroke-width="5"/>
    <path d="M59 66h42M59 82h42M59 98h28" stroke="${accent}" stroke-width="5" stroke-linecap="round" opacity=".78"/>
  `;
}

function escapeSvgText(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
