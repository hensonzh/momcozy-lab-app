import React, { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  ArrowLeft,
  Baby,
  CreditCard,
  Heart,
  PackageCheck,
  RotateCcw,
  Trash2,
} from "lucide-react";
import {
  calculateHospitalBagCartTotals,
  cloneHospitalBagCartGroups,
  formatHospitalBagCartItemPrice,
  formatHospitalBagCartMoney,
  formatHospitalBagCartTotals,
  initialHospitalBagCartGroups,
  removeHospitalBagCartItem,
  resolveHospitalBagCartItemImage,
  resolveHospitalBagCartItemImageAlt,
  type HospitalBagCartItem,
  type HospitalBagCartGroup,
  type HospitalBagCartTone,
} from "@/pages/hospitalBagCartModel";

const toneClasses: Record<HospitalBagCartTone, string> = {
  rose: "bg-[#fff0f5] text-[#b84d73] border-[#f5cfdb]",
  mint: "bg-[#edf9f5] text-[#267c68] border-[#ccebe2]",
  sky: "bg-[#edf6ff] text-[#2f6fa8] border-[#cfe5f8]",
};

const itemIconClasses: Record<HospitalBagCartTone, string> = {
  rose: "bg-[#f9d9e4] text-[#b84d73]",
  mint: "bg-[#d4f0e7] text-[#267c68]",
  sky: "bg-[#d8ebfb] text-[#2f6fa8]",
};

function HospitalBagCartItemFallbackIcon({ tone }: { tone: HospitalBagCartTone }) {
  const Icon = tone === "mint" ? Baby : tone === "sky" ? Heart : PackageCheck;
  return (
    <div className={`flex h-14 w-14 items-center justify-center rounded-2xl ${itemIconClasses[tone]}`}>
      <Icon className="h-6 w-6" />
    </div>
  );
}

function HospitalBagCartItemImage({ item, tone }: { item: HospitalBagCartItem; tone: HospitalBagCartTone }) {
  const [hasError, setHasError] = useState(false);
  const src = resolveHospitalBagCartItemImage(item);
  if (hasError || !src) return <HospitalBagCartItemFallbackIcon tone={tone} />;
  return (
    <div className="h-14 w-14 overflow-hidden rounded-2xl border border-[#f0e1e7] bg-white shadow-sm">
      <img
        src={src}
        alt={resolveHospitalBagCartItemImageAlt(item)}
        className="h-full w-full object-cover"
        loading="lazy"
        onError={() => setHasError(true)}
      />
    </div>
  );
}

type HospitalBagCartProps = {
  cartGroups?: HospitalBagCartGroup[];
  onClose?: () => void;
  onRemoveItem?: (itemId: string, itemName: string) => void;
  onResetCart?: () => void;
};

const HospitalBagCart: React.FC<HospitalBagCartProps> = ({ cartGroups, onClose, onRemoveItem, onResetCart }) => {
  const navigate = useNavigate();
  const [localCartGroups, setLocalCartGroups] = useState<HospitalBagCartGroup[]>(() =>
    cloneHospitalBagCartGroups(initialHospitalBagCartGroups),
  );
  const effectiveCartGroups = cartGroups ?? localCartGroups;
  const visibleCartGroups = useMemo(() => effectiveCartGroups.filter((group) => group.items.length > 0), [effectiveCartGroups]);
  const totals = useMemo(() => calculateHospitalBagCartTotals(effectiveCartGroups), [effectiveCartGroups]);
  const { subtotal, itemCount, discount, shipping } = totals;

  const handleBack = () => {
    if (onClose) {
      onClose();
      return;
    }
    navigate(-1);
  };

  const handleRemoveItem = (itemId: string, itemName: string) => {
    if (onRemoveItem) {
      onRemoveItem(itemId, itemName);
      return;
    }
    setLocalCartGroups((groups) => removeHospitalBagCartItem(groups, itemId));
  };

  const handleResetCart = () => {
    if (onResetCart) {
      onResetCart();
      return;
    }
    setLocalCartGroups(cloneHospitalBagCartGroups(initialHospitalBagCartGroups));
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
            {itemCount} 件
          </span>
        </div>
      </header>

      <main className="min-h-0 flex-1 space-y-4 overflow-y-auto px-3.5 pb-[148px] pt-3">
        {visibleCartGroups.map((group) => (
          <section key={group.title} className="space-y-2">
            <div className="flex items-center justify-between">
              <h2 className="text-[15px] font-bold">{group.title}</h2>
              <span className={`rounded-full border px-2.5 py-1 text-[10px] font-semibold ${toneClasses[group.tone]}`}>
                {group.items.length} 件
              </span>
            </div>
            <div className="space-y-2">
              {group.items.map((item) => (
                <article key={item.name} className="grid grid-cols-[56px_minmax(0,1fr)_auto] gap-2.5 rounded-2xl border border-[#f0e1e7] bg-white p-3 shadow-sm">
                  <HospitalBagCartItemImage item={item} tone={group.tone} />
                  <div className="min-w-0">
                    <h3 className="truncate text-[13px] font-bold">{item.name}</h3>
                    <p className="mt-0.5 line-clamp-2 text-[11px] leading-snug text-[#7e6672]">{item.desc}</p>
                    <p className="mt-1 text-[10px] font-semibold text-[#9a7b89]">x{item.qty}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-[13px] font-bold">{formatHospitalBagCartItemPrice(item)}</p>
                    <button
                      type="button"
                      onClick={() => handleRemoveItem(item.id, item.name)}
                      className="mt-2 inline-flex items-center gap-1 rounded-full border border-[#edd6df] px-2 py-1 text-[10px] font-semibold text-[#6c4457]"
                      aria-label={`删除${item.name}`}
                    >
                      <Trash2 className="h-3 w-3" />
                      删除
                    </button>
                  </div>
                </article>
              ))}
            </div>
          </section>
        ))}

        {itemCount === 0 ? (
          <section className="rounded-[22px] border border-[#efdbe4] bg-white p-4 text-center shadow-[0_10px_28px_rgba(91,55,72,0.08)]">
            <p className="text-[13px] font-bold">购物车已经清空</p>
            <button
              type="button"
              onClick={handleResetCart}
              className="mt-3 inline-flex items-center gap-1 rounded-full border border-[#edd6df] px-3 py-1.5 text-[11px] font-bold text-[#6c4457]"
            >
              <RotateCcw className="h-3.5 w-3.5" />
              恢复默认清单
            </button>
          </section>
        ) : null}

        <section className="rounded-[22px] border border-[#efdbe4] bg-white p-4 shadow-[0_10px_28px_rgba(91,55,72,0.08)]">
          <h2 className="text-[15px] font-bold">订单摘要</h2>
          <div className="mt-3 space-y-2 text-[12px]">
            <div className="flex justify-between text-[#6f5663]">
              <span>商品小计</span>
              <span>{formatHospitalBagCartMoney(subtotal, "CNY")}</span>
            </div>
            <div className="flex justify-between text-[#267c68]">
              <span>组合优惠</span>
              <span>-{formatHospitalBagCartMoney(discount, "CNY")}</span>
            </div>
            <div className="flex justify-between text-[#6f5663]">
              <span>配送</span>
              <span>{shipping === 0 ? "免运费" : formatHospitalBagCartMoney(shipping, "CNY")}</span>
            </div>
            <div className="border-t border-[#f0e1e7] pt-3">
              <div className="flex items-end justify-between">
                <span className="text-[13px] font-bold">预计合计</span>
                <span className="text-[22px] font-black text-[#24889a]">{formatHospitalBagCartTotals(totals)}</span>
              </div>
            </div>
          </div>
        </section>
      </main>

      <footer className="fixed inset-x-0 bottom-0 z-20 mx-auto w-full max-w-lg border-t border-[#ead8df] bg-[#fff9fb]/96 px-3.5 pb-[max(12px,env(safe-area-inset-bottom))] pt-3 shadow-[0_-10px_28px_rgba(91,55,72,0.10)] backdrop-blur">
        <div className="mb-2 flex items-end justify-between gap-3">
          <div>
            <p className="text-[10px] font-semibold text-[#8a6d7a]">预计合计</p>
            <p className="text-[24px] font-black leading-none text-[#24889a]">{formatHospitalBagCartTotals(totals)}</p>
          </div>
          <p className="text-right text-[10px] leading-snug text-[#8a6d7a]">
            已含组合优惠 {formatHospitalBagCartMoney(discount, "CNY")}
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
