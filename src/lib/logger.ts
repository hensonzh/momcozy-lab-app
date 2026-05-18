/**
 * Logger: 输出调用方文件:行号，并对对象做安全序列化，避免 [object Object]。
 */

type LogLevel = "log" | "warn" | "error";

const LOG_LEVEL_PRIORITY: Record<LogLevel, number> = {
  log: 10,
  warn: 20,
  error: 30,
};

function normalizeLogLevel(raw: string | undefined): LogLevel {
  const level = (raw || "").trim().toLowerCase();
  if (level === "warn" || level === "warning") return "warn";
  if (level === "error" || level === "off" || level === "silent") return "error";
  return "log";
}

function readGlobalLogLevel(): LogLevel {
  try {
    if (typeof import.meta !== "undefined") {
      return normalizeLogLevel((import.meta.env?.VITE_LOG_LEVEL as string | undefined) ?? "");
    }
  } catch {
    // ignore
  }
  return "log";
}

function readIncludeModuleList(): string[] {
  try {
    if (typeof import.meta !== "undefined") {
      const raw = (import.meta.env?.VITE_LOG_INCLUDE as string | undefined) ?? "";
      return raw
        .split(",")
        .map((item) => item.trim().toLowerCase())
        .filter(Boolean);
    }
  } catch {
    // ignore
  }
  return [];
}

function readModuleLevelMap(): Map<string, LogLevel> {
  const moduleLevelMap = new Map<string, LogLevel>();
  try {
    if (typeof import.meta !== "undefined") {
      const raw = (import.meta.env?.VITE_LOG_LEVEL_BY_MODULE as string | undefined) ?? "";
      const entryList = raw.split(",").map((item) => item.trim()).filter(Boolean);
      for (const entry of entryList) {
        const eqIndex = entry.indexOf("=");
        if (eqIndex <= 0) continue;
        const moduleName = entry.slice(0, eqIndex).trim().toLowerCase();
        const levelRaw = entry.slice(eqIndex + 1).trim();
        if (!moduleName) continue;
        moduleLevelMap.set(moduleName, normalizeLogLevel(levelRaw));
      }
    }
  } catch {
    // ignore
  }
  return moduleLevelMap;
}

const GLOBAL_LOG_LEVEL = readGlobalLogLevel();
const INCLUDE_MODULE_LIST = readIncludeModuleList();
const MODULE_LEVEL_MAP = readModuleLevelMap();
/** 单条日志里对象展开的最大深度，防止极端深层结构卡死主线程 */
const MAX_STRINGIFY_DEPTH = 14;
/** 单对象最多枚举的自有属性数量 */
const MAX_OBJECT_KEYS = 256;
/** 数组最多输出的元素个数 */
const MAX_ARRAY_ITEMS = 256;

/**
 * 将任意值序列化为可读字符串；支持循环引用、重复引用、Error、Date、Map/Set、BigInt 等。
 * @param value 日志中的任意参数
 * @param depth 当前递归深度（内部使用）
 * @param seen 当前路径上的对象集合，用于检测环（离开子树时会删除，避免误判兄弟间共享引用）
 * @returns 可读的 JSON 风格或描述字符串，不会是裸的 `[object Object]`
 */
function stringifyUnknownForLog(value: unknown, depth = 0, seen = new WeakSet<object>()): string {
  if (depth > MAX_STRINGIFY_DEPTH) return '"[MaxDepth]"';

  if (value === null) return "null";
  if (value === undefined) return "undefined";

  const t = typeof value;
  if (t === "string") return JSON.stringify(value);
  if (t === "number" || t === "boolean") return String(value);
  if (t === "bigint") return `${value}n`;
  if (t === "symbol") return String(value);
  if (t === "function") {
    const fn = value as (...args: unknown[]) => unknown;
    const name = fn.name ? String(fn.name) : "anonymous";
    return `"[Function ${name}]"`;
  }

  if (typeof value !== "object") return String(value);

  if (value instanceof Error) {
    const err = value as Error & { cause?: unknown };
    // 保留多行 stack，避免 JSON 转义后难以阅读
    let out = `${err.name}: ${err.message}`;
    if (err.stack) out += `\n${err.stack}`;
    if (err.cause !== undefined) out += `\ncause: ${stringifyUnknownForLog(err.cause, depth + 1, seen)}`;
    return out;
  }

  if (value instanceof Date) return JSON.stringify(value.toISOString());

  if (Array.isArray(value)) {
    if (seen.has(value)) return '"[Circular]"';
    seen.add(value);
    try {
      const n = Math.min(value.length, MAX_ARRAY_ITEMS);
      const lines: string[] = [];
      for (let i = 0; i < n; i++) {
        lines.push(`${"  ".repeat(depth + 1)}${stringifyUnknownForLog(value[i], depth + 1, seen)}`);
      }
      if (value.length > MAX_ARRAY_ITEMS) {
        lines.push(`${"  ".repeat(depth + 1)}"... ${value.length - MAX_ARRAY_ITEMS} more items"`);
      }
      return `[\n${lines.join(",\n")}\n${"  ".repeat(depth)}]`;
    } finally {
      seen.delete(value);
    }
  }

  if (value instanceof Map) {
    if (seen.has(value)) return '"[Circular Map]"';
    seen.add(value);
    try {
      const lines: string[] = [];
      let count = 0;
      for (const [k, v] of value.entries()) {
        if (count >= MAX_OBJECT_KEYS) {
          lines.push(`${"  ".repeat(depth + 1)}"... ${value.size - MAX_OBJECT_KEYS} more entries"`);
          break;
        }
        const keyStr = stringifyUnknownForLog(k, depth + 1, seen);
        lines.push(`${"  ".repeat(depth + 1)}${keyStr} => ${stringifyUnknownForLog(v, depth + 1, seen)}`);
        count++;
      }
      return `Map {\n${lines.join(",\n")}\n${"  ".repeat(depth)}}`;
    } finally {
      seen.delete(value);
    }
  }

  if (value instanceof Set) {
    if (seen.has(value)) return '"[Circular Set]"';
    seen.add(value);
    try {
      const lines: string[] = [];
      let i = 0;
      for (const item of value.values()) {
        if (i >= MAX_ARRAY_ITEMS) {
          lines.push(`${"  ".repeat(depth + 1)}"... ${value.size - MAX_ARRAY_ITEMS} more items"`);
          break;
        }
        lines.push(`${"  ".repeat(depth + 1)}${stringifyUnknownForLog(item, depth + 1, seen)}`);
        i++;
      }
      return `Set {\n${lines.join(",\n")}\n${"  ".repeat(depth)}}`;
    } finally {
      seen.delete(value);
    }
  }

  // 普通对象 / 类实例：先尝试 JSON（处理常见可序列化对象），失败则用枚举键兜底
  if (seen.has(value)) return '"[Circular]"';
  seen.add(value);
  try {
    try {
      return JSON.stringify(value, null, 2);
    } catch {
      // 循环引用等：改为手动展开
    }
    const keys = Object.keys(value as object);
    const lines: string[] = [];
    const lim = Math.min(keys.length, MAX_OBJECT_KEYS);
    for (let i = 0; i < lim; i++) {
      const k = keys[i];
      let v: unknown;
      try {
        v = (value as Record<string, unknown>)[k];
      } catch {
        v = "[Unreadable property]";
      }
      lines.push(`${"  ".repeat(depth + 1)}${JSON.stringify(k)}: ${stringifyUnknownForLog(v, depth + 1, seen)}`);
    }
    if (keys.length > MAX_OBJECT_KEYS) {
      lines.push(`${"  ".repeat(depth + 1)}"... ${keys.length - MAX_OBJECT_KEYS} more keys"`);
    }
    const symKeys = Object.getOwnPropertySymbols(value);
    for (const sym of symKeys.slice(0, 16)) {
      let v: unknown;
      try {
        v = (value as Record<string | symbol, unknown>)[sym];
      } catch {
        v = "[Unreadable property]";
      }
      lines.push(
        `${"  ".repeat(depth + 1)}${JSON.stringify(String(sym))}: ${stringifyUnknownForLog(v, depth + 1, seen)}`,
      );
    }
    return `{\n${lines.join(",\n")}\n${"  ".repeat(depth)}}`;
  } finally {
    seen.delete(value);
  }
}

/**
 * 将单条日志参数转为字符串：统一走 {@link stringifyUnknownForLog}，杜绝 String(obj) 与 stringify 失败时的 [object Object]。
 * @param value 任意日志参数
 * @returns 可读字符串
 */
function safeStringify(value: unknown): string {
  try {
    return stringifyUnknownForLog(value);
  } catch {
    try {
      return Object.prototype.toString.call(value);
    } catch {
      return "[Unknown]";
    }
  }
}

/**
 * 与 {@link log} 使用相同的序列化规则，供原生端 console 补丁等复用。
 * @param value 任意值
 * @returns 可读字符串
 */
export function stringifyLogArg(value: unknown): string {
  return safeStringify(value);
}

function getCallerFileLine(): string {
  try {
    const stack = new Error().stack;
    if (!stack) return "?";
    const lines = stack.split("\n");
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (/logger\.(ts|js)/i.test(line)) continue;
      const m = line.match(/\(([^)]+):(\d+)(?::(\d+))?\)/) || line.match(/(?:file:\/\/|https?:\/\/[^/]+\/)?([^:]+):(\d+)(?::(\d+))?/);
      if (m && m[1] && m[2]) {
        const path = m[1];
        const lineNum = m[2];
        try {
          const short = path.replace(/^.*[/\\]src[/\\]/, "src/").replace(/^.*[/\\]/, "");
          return `${short}:${lineNum}`;
        } catch {
          // 如果路径处理失败，返回原始路径和行号
          return `${path}:${lineNum}`;
        }
      }
    }
  } catch {
    /* ignore */
  }
  return "?";
}

function formatMessage(level: LogLevel, args: unknown[]): string {
  const location = getCallerFileLine();
  const parts = args.map(safeStringify);
  return `[${location}] ${parts.join(" ")}`;
}

export function log(...args: unknown[]): void {
  if (LOG_LEVEL_PRIORITY.log < LOG_LEVEL_PRIORITY[GLOBAL_LOG_LEVEL]) return;
  console.log(formatMessage("log", args));
}

export function warn(...args: unknown[]): void {
  if (LOG_LEVEL_PRIORITY.warn < LOG_LEVEL_PRIORITY[GLOBAL_LOG_LEVEL]) return;
  console.warn(formatMessage("warn", args));
}

export function error(...args: unknown[]): void {
  if (LOG_LEVEL_PRIORITY.error < LOG_LEVEL_PRIORITY[GLOBAL_LOG_LEVEL]) return;
  console.error(formatMessage("error", args));
}

function shouldLogForModule(moduleName: string, level: LogLevel): boolean {
  const moduleLower = moduleName.trim().toLowerCase();
  const moduleLevel = MODULE_LEVEL_MAP.get(moduleLower) ?? GLOBAL_LOG_LEVEL;
  if (LOG_LEVEL_PRIORITY[level] < LOG_LEVEL_PRIORITY[moduleLevel]) return false;
  if (INCLUDE_MODULE_LIST.length === 0) return true;
  return INCLUDE_MODULE_LIST.some((item) => item === "*" || moduleLower.includes(item));
}

export function createScopedConsole(moduleName: string): Pick<Console, "log" | "warn" | "error"> {
  const prefix = `[${moduleName}]`;
  return {
    log: (...args: unknown[]) => {
      if (!shouldLogForModule(moduleName, "log")) return;
      globalThis.console.log(prefix, ...args);
    },
    warn: (...args: unknown[]) => {
      if (!shouldLogForModule(moduleName, "warn")) return;
      globalThis.console.warn(prefix, ...args);
    },
    error: (...args: unknown[]) => {
      if (!shouldLogForModule(moduleName, "error")) return;
      globalThis.console.error(prefix, ...args);
    },
  };
}
