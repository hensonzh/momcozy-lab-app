import React from "react";
import { useNavigate } from "react-router-dom";
import {
  ArrowLeft,
  Baby,
  CreditCard,
  Heart,
  PackageCheck,
} from "lucide-react";

const cartGroups = [
  {
    title: "妈妈护理",
    tone: "rose",
    items: [
      { name: "产褥垫组合装", desc: "入院与产后前几天使用", qty: 1, price: 19.9 },
      { name: "产妇卫生巾", desc: "夜用加长款，按住院天数准备", qty: 1, price: 16.9 },
      { name: "一次性内裤", desc: "高腰柔软，产后更方便更换", qty: 1, price: 15.9 },
      { name: "产后护理湿巾", desc: "温和清洁，适合住院随身包", qty: 1, price: 12.9 },
    ],
  },
  {
    title: "宝宝出院",
    tone: "mint",
    items: [
      { name: "新生儿纸尿裤", desc: "NB 码小包装，避免带太多", qty: 1, price: 23.9 },
      { name: "婴儿柔湿巾", desc: "无香精，适合换尿裤场景", qty: 1, price: 13.9 },
      { name: "棉柔巾", desc: "洗脸、擦手、护理都可用", qty: 1, price: 10.9 },
      { name: "宝宝出院包被", desc: "柔软包裹，按季节搭配外层", qty: 1, price: 36.9 },
    ],
  },
  {
    title: "母乳喂养",
    tone: "sky",
    items: [
      { name: "防溢乳垫", desc: "母乳或混合喂养可先备小包装", qty: 1, price: 12.9 },
      { name: "乳头护理霜", desc: "哺乳初期不适时可咨询后使用", qty: 1, price: 18.9 },
      { name: "储奶袋", desc: "返家后储奶备用，住院可少量准备", qty: 1, price: 15.9 },
      { name: "便携式吸奶器", desc: "可选备用项，是否带去医院先问医院", qty: 1, price: 129.0 },
    ],
  },
];

const toneClasses: Record<string, string> = {
  rose: "bg-[#fff0f5] text-[#b84d73] border-[#f5cfdb]",
  mint: "bg-[#edf9f5] text-[#267c68] border-[#ccebe2]",
  sky: "bg-[#edf6ff] text-[#2f6fa8] border-[#cfe5f8]",
};

const itemIconClasses: Record<string, string> = {
  rose: "bg-[#f9d9e4] text-[#b84d73]",
  mint: "bg-[#d4f0e7] text-[#267c68]",
  sky: "bg-[#d8ebfb] text-[#2f6fa8]",
};

const subtotal = cartGroups.reduce(
  (sum, group) => sum + group.items.reduce((groupSum, item) => groupSum + item.price * item.qty, 0),
  0,
);
const discount = 28;
const shipping = 0;
const total = subtotal - discount + shipping;

type HospitalBagCartProps = {
  onClose?: () => void;
};

const HospitalBagCart: React.FC<HospitalBagCartProps> = ({ onClose }) => {
  const navigate = useNavigate();
  const handleBack = () => {
    if (onClose) {
      onClose();
      return;
    }
    navigate(-1);
  };

  return (
    <div className="mx-auto flex h-[100dvh] max-h-[100dvh] w-full max-w-lg flex-col overflow-hidden bg-[#fff9fb] text-[#372330] sm:shadow-2xl">
      <header className="z-10 flex-none border-b border-[#f0dde5] bg-[#fff9fb]/95 px-3.5 pb-3 pt-[max(12px,env(safe-area-inset-top))] backdrop-blur">
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={handleBack}
            className="flex h-9 w-9 items-center justify-center rounded-full border border-[#edd6df] bg-white text-[#6c4457]"
            aria-label="返回"
          >
            <ArrowLeft className="h-4 w-4" />
          </button>
          <div className="min-w-0 flex-1">
            <h1 className="text-[18px] font-bold leading-tight">待产包一键打包</h1>
            <p className="text-[11px] text-[#8a6d7a]">已按待产包物品清单整理</p>
          </div>
          <span className="rounded-full border border-[#d7ece6] bg-[#eef9f5] px-2.5 py-1 text-[11px] font-semibold text-[#267c68]">
            12 件
          </span>
        </div>
      </header>

      <main className="min-h-0 flex-1 space-y-4 overflow-y-auto px-3.5 pb-[148px] pt-3">
        {cartGroups.map((group) => (
          <section key={group.title} className="space-y-2">
            <div className="flex items-center justify-between">
              <h2 className="text-[15px] font-bold">{group.title}</h2>
              <span className={`rounded-full border px-2.5 py-1 text-[10px] font-semibold ${toneClasses[group.tone]}`}>
                {group.items.length} 件
              </span>
            </div>
            <div className="space-y-2">
              {group.items.map((item) => (
                <article key={item.name} className="grid grid-cols-[40px_minmax(0,1fr)_auto] gap-2.5 rounded-2xl border border-[#f0e1e7] bg-white p-3 shadow-sm">
                  <div className={`flex h-10 w-10 items-center justify-center rounded-2xl ${itemIconClasses[group.tone]}`}>
                    {group.tone === "mint" ? <Baby className="h-5 w-5" /> : group.tone === "sky" ? <Heart className="h-5 w-5" /> : <PackageCheck className="h-5 w-5" />}
                  </div>
                  <div className="min-w-0">
                    <h3 className="truncate text-[13px] font-bold">{item.name}</h3>
                    <p className="mt-0.5 line-clamp-2 text-[11px] leading-snug text-[#7e6672]">{item.desc}</p>
                    <p className="mt-1 text-[10px] font-semibold text-[#9a7b89]">x{item.qty}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-[13px] font-bold">¥{item.price.toFixed(2)}</p>
                    <button type="button" className="mt-2 rounded-full border border-[#edd6df] px-2 py-1 text-[10px] font-semibold text-[#6c4457]">
                      已加入
                    </button>
                  </div>
                </article>
              ))}
            </div>
          </section>
        ))}

        <section className="rounded-[22px] border border-[#efdbe4] bg-white p-4 shadow-[0_10px_28px_rgba(91,55,72,0.08)]">
          <h2 className="text-[15px] font-bold">订单摘要</h2>
          <div className="mt-3 space-y-2 text-[12px]">
            <div className="flex justify-between text-[#6f5663]">
              <span>商品小计</span>
              <span>¥{subtotal.toFixed(2)}</span>
            </div>
            <div className="flex justify-between text-[#267c68]">
              <span>组合优惠</span>
              <span>-¥{discount.toFixed(2)}</span>
            </div>
            <div className="flex justify-between text-[#6f5663]">
              <span>配送</span>
              <span>{shipping === 0 ? "免运费" : `¥${shipping.toFixed(2)}`}</span>
            </div>
            <div className="border-t border-[#f0e1e7] pt-3">
              <div className="flex items-end justify-between">
                <span className="text-[13px] font-bold">预计合计</span>
                <span className="text-[22px] font-black text-[#24889a]">¥{total.toFixed(2)}</span>
              </div>
            </div>
          </div>
        </section>
      </main>

      <footer className="fixed inset-x-0 bottom-0 z-20 mx-auto w-full max-w-lg border-t border-[#ead8df] bg-[#fff9fb]/96 px-3.5 pb-[max(12px,env(safe-area-inset-bottom))] pt-3 shadow-[0_-10px_28px_rgba(91,55,72,0.10)] backdrop-blur">
        <div className="mb-2 flex items-end justify-between gap-3">
          <div>
            <p className="text-[10px] font-semibold text-[#8a6d7a]">预计合计</p>
            <p className="text-[24px] font-black leading-none text-[#24889a]">¥{total.toFixed(2)}</p>
          </div>
          <p className="text-right text-[10px] leading-snug text-[#8a6d7a]">
            已含组合优惠 ¥{discount.toFixed(2)}
          </p>
        </div>
        <button
          type="button"
          className="flex w-full items-center justify-center gap-2 rounded-2xl bg-[#24889a] px-4 py-3 text-[15px] font-bold text-white shadow-sm"
        >
          <CreditCard className="h-4 w-4" />
          去结算
        </button>
      </footer>
    </div>
  );
};

export default HospitalBagCart;
