import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react-swc";
import path from "path";
import { componentTagger } from "lovable-tagger";

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  const apiBase = (env.VITE_API_BASE_URL || "").trim();
  const proxyTarget = apiBase || "http://127.0.0.1:8769";
  const deviceUsageProxyTarget = (env.VITE_DEVICE_USAGE_API_BASE_URL || apiBase || "").trim() || "http://127.0.0.1:8769";
  /** Markdown 聊天图：HTTP 源站，经此前缀代理为同源 HTTPS，避免浏览器 Mixed Content 拦截 */
  const chatImageProxyTarget =
    (env.VITE_CHAT_IMAGE_PROXY_TARGET || env.VITE_CHAT_IMAGE_BASE_URL || "").trim() ||
    "http://192.168.24.182:8900";
  const mediaHttpProxyTarget =
    (env.VITE_CHAT_IMAGE_PROXY_TARGET || env.VITE_CHAT_IMAGE_PROXY_TARGET || env.VITE_CHAT_IMAGE_BASE_URL || "").trim() ||
    chatImageProxyTarget;
  return {
  server: {
    host: "::",
    port: 8080,
    hmr: {
      overlay: false,
    },
    // 开发时 /api、/v1 走代理（业务 API 为 /v1/*）；未配置 VITE_API_BASE_URL 时默认 127.0.0.1:8769
    proxy: {
      "/api": { target: proxyTarget, changeOrigin: true, ws: true },
      "/v1": { target: proxyTarget, changeOrigin: true, ws: true },
      "/__device_usage_api_proxy": {
        target: deviceUsageProxyTarget,
        changeOrigin: true,
        ws: true,
        rewrite: (p) => (p.replace(/^\/__device_usage_api_proxy/, "") || "/"),
      },
      "/__chat_image_proxy": {
        target: chatImageProxyTarget,
        changeOrigin: true,
        rewrite: (p) => (p.replace(/^\/__chat_image_proxy/, "") || "/"),
      },
      "/__media_http_proxy": {
        target: mediaHttpProxyTarget,
        changeOrigin: true,
        rewrite: (p) => (p.replace(/^\/__media_http_proxy/, "") || "/"),
      },
    },
  },
  plugins: [react(), mode === "development" && componentTagger()].filter(Boolean),
  optimizeDeps: {
    include: ["@radix-ui/react-alert-dialog"],
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  };
});
