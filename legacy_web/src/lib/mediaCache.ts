import { Capacitor } from "@capacitor/core";
import { Directory, Filesystem } from "@capacitor/filesystem";

const CACHE_SUBDIR = "media_viewer_cache";

/**
 * ArrayBuffer 转 base64（供 Filesystem 写入二进制；大文件会短暂占用双倍内存峰值）。
 * @param buffer 原始缓冲
 * @returns base64 字符串
 */
function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  const len = bytes.length;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

/**
 * 将二进制写入应用 Cache 目录并返回 WebView 可用的 `convertFileSrc` URL。
 * @param data 文件内容
 * @param extension 扩展名（含或不含点均可，如 mp4 / .mp4）
 * @returns webSrc 供 video/img 使用；relativePath 供退出时删除
 */
export async function writeArrayBufferToMediaCache(
  data: ArrayBuffer,
  extension: string,
): Promise<{ webSrc: string; relativePath: string }> {
  const ext = extension.replace(/^\./, "");
  const name = `${Date.now()}_${Math.random().toString(36).slice(2, 10)}.${ext}`;
  const relativePath = `${CACHE_SUBDIR}/${name}`;
  await Filesystem.writeFile({
    path: relativePath,
    directory: Directory.Cache,
    data: arrayBufferToBase64(data),
    recursive: true,
  });
  const { uri } = await Filesystem.getUri({
    path: relativePath,
    directory: Directory.Cache,
  });
  return { webSrc: Capacitor.convertFileSrc(uri), relativePath };
}

/**
 * 删除单次查看产生的缓存文件。
 * @param relativePath `writeArrayBufferToMediaCache` 返回的 relativePath
 */
export async function deleteMediaCacheFile(relativePath: string): Promise<void> {
  try {
    await Filesystem.deleteFile({
      path: relativePath,
      directory: Directory.Cache,
    });
  } catch {
    /* 已删除或不存在 */
  }
}

/**
 * 尽力清空 viewer 缓存子目录（启动或大版本升级时可调用；当前由页面 unmount 单文件删除为主）。
 */
export async function clearMediaViewerCacheBestEffort(): Promise<void> {
  try {
    const { files } = await Filesystem.readdir({
      path: CACHE_SUBDIR,
      directory: Directory.Cache,
    });
    await Promise.all(
      files.map((f) =>
        Filesystem.deleteFile({
          path: `${CACHE_SUBDIR}/${f}`,
          directory: Directory.Cache,
        }).catch(() => undefined),
      ),
    );
  } catch {
    /* 目录不存在 */
  }
}
