import React, { useEffect, useMemo, useRef, useState } from "react";
import { ArrowLeft, Check, ChevronDown, Trash2, UserRoundCog } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import TabPageTopReserve from "@/components/layout/TabPageTopReserve";
import {
  clearRuntimeUserInfo,
  getRuntimeMomStageForUser,
  getRuntimeUserConfig,
  getRuntimeUserIds,
  switchRuntimeUserConfig,
  type RuntimeMomStage,
} from "@/lib/debugUserConfig";
import { toast } from "@/hooks/use-toast";

const stageLabels: Record<RuntimeMomStage, string> = {
  prenatal: "孕期",
  postpartum: "产后",
};

const UserParameterConfig: React.FC = () => {
  const navigate = useNavigate();
  const initial = useMemo(
    () =>
      getRuntimeUserConfig({
        defaultUserId: import.meta.env.VITE_DEFAULT_USER_ID as string | undefined,
        defaultMomStage: import.meta.env.VITE_MOM_STAGE as string | undefined,
      }),
    [],
  );
  const [knownUserIds, setKnownUserIds] = useState(() => getRuntimeUserIds());
  const [userId, setUserId] = useState(initial.userId);
  const [momStage, setMomStage] = useState<RuntimeMomStage>(initial.momStage);
  const [saving, setSaving] = useState(false);
  const [userListOpen, setUserListOpen] = useState(false);
  const userPickerRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!userListOpen) return;
    const onPointerDown = (event: MouseEvent | TouchEvent) => {
      const target = event.target as Node | null;
      if (target && userPickerRef.current?.contains(target)) return;
      setUserListOpen(false);
    };
    document.addEventListener("mousedown", onPointerDown);
    document.addEventListener("touchstart", onPointerDown);
    return () => {
      document.removeEventListener("mousedown", onPointerDown);
      document.removeEventListener("touchstart", onPointerDown);
    };
  }, [userListOpen]);

  const reloadTo = (path: string) => {
    window.setTimeout(() => {
      window.location.assign(path);
    }, 240);
  };

  const handleUserIdChange = (next: string) => {
    setUserId(next);
    const trimmed = next.trim();
    if (!knownUserIds.includes(trimmed)) return;
    setMomStage(getRuntimeMomStageForUser(trimmed, import.meta.env.VITE_MOM_STAGE as string | undefined));
  };

  const handleSelectUser = (next: string) => {
    handleUserIdChange(next);
    setUserListOpen(false);
  };

  const handleSwitchUser = async () => {
    const trimmedUserId = userId.trim();
    if (!trimmedUserId) {
      toast({ title: "请输入用户名" });
      return;
    }
    setSaving(true);
    const existed = knownUserIds.includes(trimmedUserId);
    await switchRuntimeUserConfig({ userId: trimmedUserId, momStage });
    setKnownUserIds(getRuntimeUserIds());
    toast({ title: existed ? "用户已切换" : "用户已新建并切换" });
    reloadTo("/");
  };

  const handleDeleteUser = async () => {
    setSaving(true);
    await clearRuntimeUserInfo();
    setKnownUserIds(getRuntimeUserIds());
    setUserId("");
    setMomStage("postpartum");
    toast({ title: "用户和本地数据已删除" });
    reloadTo("/device");
  };

  return (
    <div className="flex min-h-screen flex-col bg-background">
      <TabPageTopReserve />
      <header className="flex shrink-0 items-center gap-3 px-4 pb-3 pt-4">
        <button
          type="button"
          onClick={() => navigate(-1)}
          className="flex h-10 w-10 items-center justify-center rounded-full border border-border/60 bg-card text-foreground shadow-sm"
          aria-label="返回"
        >
          <ArrowLeft className="h-5 w-5" />
        </button>
        <div className="min-w-0">
          <h1 className="text-lg font-bold text-foreground">用户参数配置</h1>
          <p className="mt-0.5 text-xs text-muted-foreground">
            当前来源：{initial.source === "runtime" ? "本地用户信息" : "环境变量默认值"}
          </p>
        </div>
      </header>

      <main className="flex-1 px-4 pb-8 pt-2">
        <section className="space-y-5 rounded-[20px] border border-border/60 bg-card p-4 shadow-sm">
          <div className="space-y-2">
            <Label htmlFor="debug-user-id">用户名</Label>
            <div className="relative" ref={userPickerRef}>
              <Input
                id="debug-user-id"
                value={userId}
                onFocus={() => setUserListOpen(true)}
                onClick={() => setUserListOpen(true)}
                onChange={(event) => handleUserIdChange(event.target.value)}
                placeholder="选择或输入用户 ID"
                autoCapitalize="none"
                autoCorrect="off"
                className="pr-11"
              />
              <button
                type="button"
                onClick={() => setUserListOpen((open) => !open)}
                className="absolute right-1 top-1 flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground hover:bg-muted hover:text-foreground"
                aria-label="展开用户列表"
              >
                <ChevronDown className={`h-4 w-4 transition-transform ${userListOpen ? "rotate-180" : ""}`} />
              </button>
              {userListOpen ? (
                <div className="absolute left-0 right-0 top-[calc(100%+6px)] z-50 max-h-56 overflow-y-auto rounded-md border border-border bg-popover p-1 text-popover-foreground shadow-lg">
                  {knownUserIds.length > 0 ? (
                    knownUserIds.map((id) => {
                      const selected = id === userId.trim();
                      return (
                        <button
                          key={id}
                          type="button"
                          onClick={() => handleSelectUser(id)}
                          className="flex w-full items-center justify-between gap-2 rounded-sm px-3 py-2 text-left text-sm hover:bg-accent hover:text-accent-foreground"
                        >
                          <span className="min-w-0 flex-1 truncate">{id}</span>
                          {selected ? <Check className="h-4 w-4 shrink-0 text-primary" /> : null}
                        </button>
                      );
                    })
                  ) : (
                    <div className="px-3 py-2 text-sm text-muted-foreground">暂无已保存用户</div>
                  )}
                </div>
              ) : null}
            </div>
          </div>

          <div className="space-y-2">
            <Label>用户类型</Label>
            <Select value={momStage} onValueChange={(value) => setMomStage(value as RuntimeMomStage)}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="prenatal">{stageLabels.prenatal}</SelectItem>
                <SelectItem value="postpartum">{stageLabels.postpartum}</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="grid grid-cols-1 gap-3 pt-2">
            <Button type="button" variant="outline" onClick={handleDeleteUser} disabled={saving} className="h-11">
              <Trash2 className="h-4 w-4" />
              删除用户
            </Button>
            <Button type="button" onClick={handleSwitchUser} disabled={saving} className="h-11">
              <UserRoundCog className="h-4 w-4" />
              切换用户
            </Button>
          </div>
        </section>
      </main>
    </div>
  );
};

export default UserParameterConfig;
