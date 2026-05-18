import React, { useCallback, useEffect, useState } from "react";
import { Capacitor } from "@capacitor/core";
import { Preferences } from "@capacitor/preferences";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { DEFAULT_CHAT_USER_ID } from "@/pages/agentHub/agentHubConstants";
import {
  getNativeCanDrawOverlays,
  getNativeCanScheduleExactAlarms,
  getNativeIgnoringBatteryOptimizations,
  openNativeAppNotificationSettings,
  openNativeBatteryOptimizationSettings,
  openNativeExactAlarmSettings,
  openNativeOverlaySettings,
  syncNativeBackgroundNotifyConfig,
} from "@/lib/mmcBackgroundNotify";
import { requestAndroidPostNotificationsPermission } from "@/lib/pumpSessionNotification";

const ONBOARDING_KEY = "mmc_background_notify_onboarding_done";

/**
 * 首次在 Android 上打开应用时，引导通知 / 精确闹钟 / 悬浮窗 / 电池优化相关系统能力。
 */
const BackgroundNotifyOnboardingGate: React.FC = () => {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    void (async () => {
      if (Capacitor.getPlatform() !== "android") return;
      const { value } = await Preferences.get({ key: ONBOARDING_KEY });
      if (value === "1") return;
      setOpen(true);
    })();
  }, []);

  const markDone = useCallback(async () => {
    await Preferences.set({ key: ONBOARDING_KEY, value: "1" });
    setOpen(false);
  }, []);

  const onConfigure = useCallback(async () => {
    await syncNativeBackgroundNotifyConfig(DEFAULT_CHAT_USER_ID);
    await requestAndroidPostNotificationsPermission();
    await openNativeAppNotificationSettings();
    const exact = await getNativeCanScheduleExactAlarms();
    if (!exact) {
      await openNativeExactAlarmSettings();
    }
    const overlay = await getNativeCanDrawOverlays();
    if (!overlay) {
      await openNativeOverlaySettings();
    }
    const bat = await getNativeIgnoringBatteryOptimizations();
    if (!bat) {
      await openNativeBatteryOptimizationSettings();
    }
    await markDone();
  }, [markDone]);

  if (Capacitor.getPlatform() !== "android") return null;

  return (
    <AlertDialog open={open} onOpenChange={(v) => !v && void markDone()}>
      <AlertDialogContent className="rounded-2xl max-w-md">
        <AlertDialogHeader>
          <AlertDialogTitle>开启系统后台提醒</AlertDialogTitle>
          <AlertDialogDescription className="text-left space-y-2 leading-relaxed">
            <span className="block">
              为在后台准时提醒你吸奶/喂养、风险预警、生长数据与每日小结，请允许本应用的通知权限，并按需完成：
            </span>
            <span className="block text-muted-foreground text-sm">
              通知 → 精确闹钟与提醒（若系统提示）→ 悬浮窗（便于全屏外提醒）→ 关闭电池优化（提高后台可靠性）。
            </span>
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter className="flex-col sm:flex-col gap-2">
          <AlertDialogAction className="w-full rounded-xl" onClick={() => void onConfigure()}>
            依次打开相关设置
          </AlertDialogAction>
          <AlertDialogCancel className="w-full rounded-xl mt-0" onClick={() => void markDone()}>
            稍后再说
          </AlertDialogCancel>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
};

export default BackgroundNotifyOnboardingGate;
