declare global {
  interface Window {
    MmcNativePumpSession?: {
      updateSession?: (state: string, processAll: number) => void;
      stopSession?: () => void;
      canDrawOverlays?: () => boolean;
      openOverlaySettings?: () => void;
      hasPostNotificationsPermission?: () => boolean;
      consumePendingNavigateJson?: () => string;
      showCompletionNotice?: () => void;
      showAutoEndNotice?: (title: string, body: string, path: string, autoEndTeardown: boolean) => void;
    };
  }
}

export function getNativeAndroidPumpSessionBridge() {
  return typeof window !== "undefined" ? window.MmcNativePumpSession : undefined;
}

export {};
