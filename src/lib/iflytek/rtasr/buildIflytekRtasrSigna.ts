import md5 from "js-md5";

/**
 * 生成讯飞实时语音转写 WebSocket 握手参数 signa（文档：HmacSHA1(MD5(appid+ts), apiKey) 再 Base64）。
 * @param appid 开放平台应用 appid
 * @param ts 秒级 Unix 时间戳字符串（与 URL 中 ts 一致）
 * @param apiKey 应用 apiKey（控制台「实时语音转写」服务密钥）
 * @returns Base64 编码的 signa
 */
export async function buildIflytekRtasrSigna(appid: string, ts: string, apiKey: string): Promise<string> {
  const baseString = `${appid}${ts}`;
  const md5Hex = md5(baseString);
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(apiKey),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(md5Hex));
  const bytes = new Uint8Array(sig);
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]!);
  }
  return btoa(binary);
}

/**
 * 拼接讯飞 RTASR wss 地址（查询串经 URLSearchParams 编码）。
 * @param appid 应用 appid
 * @param apiKey apiKey
 * @param queryExtra 可选：lang、pd、engLangType 等文档允许参数
 * @returns 完整 wss URL
 */
export async function buildIflytekRtasrWsUrl(
  appid: string,
  apiKey: string,
  queryExtra?: Record<string, string>,
): Promise<string> {
  const ts = Math.floor(Date.now() / 1000).toString();
  const signa = await buildIflytekRtasrSigna(appid, ts, apiKey);
  const params = new URLSearchParams({
    appid,
    ts,
    signa,
    ...(queryExtra ?? {}),
  });
  return `wss://rtasr.xfyun.cn/v1/ws?${params.toString()}`;
}
