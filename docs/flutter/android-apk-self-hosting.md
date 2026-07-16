# Android APK 自建下载页

目标：把 Flutter 构建出的 APK 发布到一个 HTTPS 静态地址，同时生成带 “Momcozy Lab” 文本的二维码。用户扫码后会直接下载 APK，也可以打开下载页手动下载。

首次使用先安装锁定的 Node 构建依赖：

```bash
npm ci
```

## 生成下载包

默认生成 `staging release` APK，并输出静态站点到 `dist/android-apk/`：

```bash
MOMCOZY_DOWNLOAD_BASE_URL=https://download.momcozy.ai/app \
make flutter-apk-download-site
```

输出目录结构：

```text
dist/android-apk/
  index.html
  manifest.json
  assets/momcozy_logo.png
  assets/momcozy-lab-download-qr.svg
  releases/momcozy-android-staging-1.0.0-1.apk
  releases/momcozy-android-staging-1.0.0-1.apk.sha256
```

下载页地址是 `MOMCOZY_DOWNLOAD_BASE_URL`。二维码编码的是该地址下的绝对 APK URL，例如：

```text
https://download.momcozy.ai/app
https://download.momcozy.ai/app/releases/momcozy-android-staging-1.0.0-1.apk
```

后续每次发布只覆盖 `dist/android-apk/` 的静态内容，下载页地址可以不变。版本号或构建号变化后，APK URL 和二维码会随构建产物一起更新。

## 常用参数

```bash
# 生成 production release 下载页
MOMCOZY_APK_FLAVOR=production \
MOMCOZY_DOWNLOAD_BASE_URL=https://download.momcozy.ai/app \
make flutter-apk-download-site

# 用已有 APK 生成下载页，不重新构建
MOMCOZY_APK_INPUT=flutter_app/build/app/outputs/flutter-apk/app-staging-release.apk \
MOMCOZY_DOWNLOAD_BASE_URL=https://download.momcozy.ai/app \
make flutter-apk-download-site

# 强制要求 release 签名环境完整，否则失败
MOMCOZY_REQUIRE_RELEASE_SIGNING=1 \
MOMCOZY_DOWNLOAD_BASE_URL=https://download.momcozy.ai/app \
make flutter-apk-download-site
```

额外 Dart define 可以用逗号传入：

```bash
MOMCOZY_APK_DART_DEFINES='MOMCOZY_API_BASE_URL=https://api.example.com,MOMCOZY_FEATURE_X=1' \
MOMCOZY_DOWNLOAD_BASE_URL=https://download.momcozy.ai/app \
make flutter-apk-download-site
```

## 上传到服务器

Nginx 示例：

```nginx
server {
  listen 443 ssl http2;
  server_name download.momcozy.ai;

  location /app/ {
    alias /var/www/momcozy/android-apk/;
    index index.html;
    autoindex off;
  }

  location ~ ^/app/releases/(?<apk_file>[0-9A-Za-z._-]+\.apk)$ {
    alias /var/www/momcozy/android-apk/releases/$apk_file;
    types { application/vnd.android.package-archive apk; }
    default_type application/vnd.android.package-archive;
    add_header Content-Disposition 'attachment; filename="$apk_file"' always;
    add_header X-Content-Type-Options nosniff always;
  }
}
```

上传：

```bash
rsync -av --delete dist/android-apk/ deploy@download.momcozy.ai:/var/www/momcozy/android-apk/
```

对象存储 / CDN 也可以，关键配置：

- `index.html` 的 Content-Type：`text/html; charset=utf-8`
- `.apk` 的 Content-Type：`application/vnd.android.package-archive`
- 下载域名必须是 HTTPS

## 验证

```bash
curl -I https://download.momcozy.ai/app/
curl -I https://download.momcozy.ai/app/releases/momcozy-android-staging-1.0.0-1.apk
shasum -a 256 dist/android-apk/releases/*.apk
```

打开下载页后确认：

- 页面显示版本号、渠道、大小、SHA256。
- 页面显示带 “Momcozy Lab” 文本的二维码。
- 用另一台设备扫描二维码后，目标地址是当前 APK 的绝对 URL，并直接触发下载。
- 手机打开同一个页面。
- 点击下载按钮可以下载 APK。
- Android 安装时允许来自该浏览器的未知来源安装。

## 注意事项

- `dist/` 已在仓库根 `.gitignore` 中忽略，不提交 APK。
- 未配置 release signing 时，release APK 可能只是 smoke artifact，不应分发给外部用户。
- 下载域名必须使用受 Android 和浏览器信任的 TLS 证书；自签名证书不适合二维码分发。
- 如果用户已安装签名不同的旧包，Android 会提示安装失败，需要先卸载旧包。
- 对外长期使用前应接入正式签名、版本记录、发布审批和回滚保留策略。
