import type { CapacitorConfig } from '@capacitor/cli';

/**
 * Capacitor 8 官方 Http 插件配置见：
 * https://capacitorjs.com/docs/apis/http#configuration
 * 开启 `CapacitorHttp.enabled` 后，原生端会 patch `fetch`/`XMLHttpRequest` 走原生网络，
 * 并保留 `Response.body` 的 ReadableStream，便于 Android/iOS 与 Web 一致地做 SSE 流式解析。
 */
const config: CapacitorConfig = {
  appId: 'com.momcozymai.app',
  appName: 'Momcozy',
  webDir: 'dist',
  server: {
    // 方案 A：Android WebView 使用 http 上下文，允许发起 ws://（生产环境请优先使用 https + wss）
    androidScheme: 'http',
  },
  android: {
    loggingBehavior: 'none',
  },
  plugins: {
    CapacitorHttp: {
      enabled: true,
    },
  },
};

export default config;
