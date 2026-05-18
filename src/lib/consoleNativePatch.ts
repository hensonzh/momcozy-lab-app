/**
 * Capacitor 原生 WebView 将 console 参数经桥传到 Android Logcat 时常丢失对象结构，表现为 `[object Object]`。
 * 须在入口最先 import，尽早替换全局 console，使后续模块初始化日志也能展开对象。
 */
import { Capacitor } from "@capacitor/core";
import { stringifyLogArg } from "@/lib/logger";

declare global {
  interface Window {
    __maiConsoleNativePatched__?: boolean;
  }
}

/**
 * 将单条 console 参数转为原生侧可读形式：仅对「会沦为 [object Object] 的对象类型」做深度序列化，标量原样保留以兼容 %s 等占位符。
 * @param arg 任意 console 实参
 * @returns 传给真实 console 方法的值（多为 string，少数为 number 等）
 */
function formatArgForNativeConsole(arg: unknown): unknown {
  if (arg === null || arg === undefined) return String(arg);
  const t = typeof arg;
  // 非 object：字符串/数字等直接交给系统 console，避免对 logger 已格式化的整句再套一层 JSON 引号
  if (t !== "object") return arg;
  // 走 logger 的安全序列化：Error、循环引用、Map/Set 等
  return stringifyLogArg(arg);
}

/**
 * 将一次 console 调用的全部参数做统一预处理。
 * @param args 原始参数元组
 * @returns 预处理后的参数数组
 */
function stringifyConsoleArgs(args: unknown[]): unknown[] {
  return args.map(formatArgForNativeConsole);
}

/**
 * 在原生环境下包装指定 console 方法，避免对象在 Logcat 中显示为 [object Object]。
 * @param method 要补丁的方法名
 * @param target 目标 console 对象
 */
function patchConsoleMethod(method: "log" | "warn" | "error" | "info" | "debug", target: Console): void {
  const original = target[method].bind(target);
  (target as unknown as Record<string, (...args: unknown[]) => void>)[method] = (...args: unknown[]) => {
    original(...stringifyConsoleArgs(args));
  };
}

function installConsoleNativePatch(): void {
  if (typeof window === "undefined") return;
  if (window.__maiConsoleNativePatched__) return;
  if (!Capacitor.isNativePlatform()) return;

  window.__maiConsoleNativePatched__ = true;

  const methods: Array<"log" | "warn" | "error" | "info" | "debug"> = [
    "log",
    "warn",
    "error",
    "info",
    "debug",
  ];
  for (const m of methods) {
    patchConsoleMethod(m, console);
  }
}

installConsoleNativePatch();
