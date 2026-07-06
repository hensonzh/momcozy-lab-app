import { describe, expect, it } from 'vitest';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { inflateSync } from 'node:zlib';

const legacyWebRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const androidSourceDir = resolve(legacyWebRoot, 'android/app/src/main/java/com/momcozymai/app');

const notificationSources = [
  'NotifyAlarmReceiver.java',
  'BackgroundNotifyPlugin.java',
  'NotifyPeriodicSyncNotifier.java',
  'PumpCompletionNotice.java',
  'PumpAutoEndNotice.java',
  'PumpSessionForegroundService.java',
];

const pngSignature = '89504e470d0a1a0a';

function decodeRgbaPng(path: string) {
  const png = readFileSync(path);
  expect(png.subarray(0, 8).toString('hex')).toBe(pngSignature);

  let offset = 8;
  let width = 0;
  let height = 0;
  const idatChunks: Buffer[] = [];

  while (offset < png.length) {
    const length = png.readUInt32BE(offset);
    const type = png.subarray(offset + 4, offset + 8).toString('ascii');
    const data = png.subarray(offset + 8, offset + 8 + length);
    offset += length + 12;

    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      expect(data[8]).toBe(8);
      expect(data[9]).toBe(6);
    } else if (type === 'IDAT') {
      idatChunks.push(Buffer.from(data));
    } else if (type === 'IEND') {
      break;
    }
  }

  const bytesPerPixel = 4;
  const stride = width * bytesPerPixel;
  const raw = inflateSync(Buffer.concat(idatChunks));
  const rgba = Buffer.alloc(width * height * bytesPerPixel);
  let rawOffset = 0;

  for (let y = 0; y < height; y += 1) {
    const filter = raw[rawOffset];
    rawOffset += 1;

    for (let x = 0; x < stride; x += 1) {
      const rawValue = raw[rawOffset + x];
      const left = x >= bytesPerPixel ? rgba[(y * stride) + x - bytesPerPixel] : 0;
      const up = y > 0 ? rgba[((y - 1) * stride) + x] : 0;
      const upperLeft = y > 0 && x >= bytesPerPixel ? rgba[((y - 1) * stride) + x - bytesPerPixel] : 0;
      let value = rawValue;

      if (filter === 1) {
        value = rawValue + left;
      } else if (filter === 2) {
        value = rawValue + up;
      } else if (filter === 3) {
        value = rawValue + Math.floor((left + up) / 2);
      } else if (filter === 4) {
        const pa = Math.abs(up - upperLeft);
        const pb = Math.abs(left - upperLeft);
        const pc = Math.abs(left + up - (2 * upperLeft));
        value = rawValue + (pa <= pb && pa <= pc ? left : pb <= pc ? up : upperLeft);
      }

      rgba[(y * stride) + x] = value & 0xff;
    }

    rawOffset += stride;
  }

  return { width, height, rgba };
}

function launcherBackgroundColor() {
    const backgroundXml = readFileSync(
    resolve(legacyWebRoot, 'android/app/src/main/res/values/ic_launcher_background.xml'),
    'utf8',
  );
  const uncommentedXml = backgroundXml.replace(/<!--[\s\S]*?-->/g, '');
  const match = uncommentedXml.match(/<color\s+name="ic_launcher_background">#([0-9A-Fa-f]{6})<\/color>/);
  expect(match).not.toBeNull();
  const hex = match?.[1] ?? '000000';
  return [
    Number.parseInt(hex.slice(0, 2), 16),
    Number.parseInt(hex.slice(2, 4), 16),
    Number.parseInt(hex.slice(4, 6), 16),
  ];
}

function nonBackgroundBoundsRatio(path: string) {
  const { width, height, rgba } = decodeRgbaPng(path);
  const background = launcherBackgroundColor();
  let minX = width;
  let minY = height;
  let maxX = -1;
  let maxY = -1;

  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const i = ((y * width) + x) * 4;
      const alpha = rgba[i + 3];
      const isBackground = alpha > 245
        && Math.abs(rgba[i] - background[0]) <= 3
        && Math.abs(rgba[i + 1] - background[1]) <= 3
        && Math.abs(rgba[i + 2] - background[2]) <= 3;
      if (!isBackground) {
        minX = Math.min(minX, x);
        minY = Math.min(minY, y);
        maxX = Math.max(maxX, x);
        maxY = Math.max(maxY, y);
      }
    }
  }

  return Math.max((maxX - minX + 1) / width, (maxY - minY + 1) / height);
}

describe('Android notification icons', () => {
  it('uses the Mai notification small and large icons for every notification builder', () => {
    for (const fileName of notificationSources) {
      const source = readFileSync(resolve(androidSourceDir, fileName), 'utf8');
      expect(source, fileName).toContain('NotificationIconHelper.applyMaiIcons(');
    }

    const helperSource = readFileSync(resolve(androidSourceDir, 'NotificationIconHelper.java'), 'utf8');
    expect(helperSource).toContain('.setSmallIcon(R.drawable.ic_stat_pump)');
    expect(helperSource).toContain('.setLargeIcon(');
    expect(helperSource).toContain('R.drawable.ic_mai_notification_large');
  });

  it('ships generated launcher and notification image resources', () => {
    const requiredResources = [
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      'android/app/src/main/res/drawable-xxxhdpi/ic_mai_notification_large.png',
      'android/app/src/main/res/drawable-xxxhdpi/ic_stat_pump.png',
    ];

    for (const resource of requiredResources) {
      expect(existsSync(resolve(legacyWebRoot, resource)), resource).toBe(true);
    }
  });

  it('uses an off-white launcher background color', () => {
    const backgroundXml = readFileSync(
      resolve(legacyWebRoot, 'android/app/src/main/res/values/ic_launcher_background.xml'),
      'utf8',
    );

    expect(backgroundXml).toContain('<color name="ic_launcher_background">#F1DACE</color>');
  });

  it('keeps the launcher portrait at about 57 percent of the icon', () => {
    const ratio = nonBackgroundBoundsRatio(
      resolve(legacyWebRoot, 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'),
    );

    expect(ratio).toBeGreaterThanOrEqual(0.56);
    expect(ratio).toBeLessThanOrEqual(0.58);
  });
});
