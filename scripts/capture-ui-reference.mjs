#!/usr/bin/env node
// Read-only design rendering in a fresh browser. No request may reach an API.
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const app = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const design = process.env.MOMCOZY_DESIGN_ROOT || path.resolve(app, '../../momcozy-lab产品设计');
const base = process.env.MOMCOZY_DESIGN_URL || 'http://127.0.0.1:4181';
if (!['127.0.0.1', 'localhost'].includes(new URL(base).hostname)) throw Error('Use a local design preview.');
const { chromium } = await import(pathToFileURL(path.join(design, 'node_modules/playwright-core/index.mjs')));
const output = path.join(app, 'docs/ui-reference');
const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
const context = await browser.newContext({ viewport: { width: 390, height: 844 }, reducedMotion: 'reduce', timezoneId: 'Asia/Shanghai' });
const blocked = [], errors = [], captures = [];
await context.route('**/*', route => {
  const url = new URL(route.request().url());
  if (url.origin !== new URL(base).origin || url.pathname.startsWith('/api/')) {
    blocked.push({ path: url.pathname, method: route.request().method() });
    return route.abort();
  }
  return route.continue();
});
const page = await context.newPage();
page.on('pageerror', error => errors.push(error.message));
try {
  for (const [id, route] of [
    ['mom/home', '/app/home'], ['baby/home', '/app/baby'],
    ['agent/home', '/app/agent'], ['schedule/home', '/app/plan'],
    ['profile/more', '/app/more'], ['profile/privacy', '/app/privacy'],
    ['mom/records', '/app/records'], ['services/catalog', '/app/services'],
    ['auth/design-login', '/auth'],
  ]) {
    await page.goto(base + route);
    await page.evaluate(async () => {
      await document.fonts.ready;
      await Promise.all([...document.images].map(image => image.decode().catch(() => {})));
      await new Promise(done => requestAnimationFrame(() => requestAnimationFrame(done)));
    });
    mkdirSync(path.dirname(path.join(output, id)), { recursive: true });
    await page.screenshot({ path: path.join(output, id + '-viewport.png') });
    const metrics = await page.evaluate(() => {
      const properties = ['fontFamily', 'fontSize', 'fontWeight', 'lineHeight', 'letterSpacing', 'color', 'backgroundColor', 'padding', 'gap', 'borderRadius', 'borderTop', 'boxShadow', 'height'];
      return Object.fromEntries([':root', 'body', '.user-shell', '.user-content', '.page', '.bottom-nav', '.nav-item', '.nav-item.active', '.nav-asset', '.nav-agent-avatar', '.home-greeting', '.baby-knowledge-banner', '.my-status-card', '.btn', '.card', 'h1', 'h2', 'h3'].map(selector => {
        const element = document.querySelector(selector);
        if (!element) return [selector, null];
        const style = getComputedStyle(element);
        return [selector, { ...Object.fromEntries(properties.map(key => [key, style[key]])), bounds: element.getBoundingClientRect().toJSON() }];
      }));
    });
    // Expand only the scroll frame for a complete reference; keep the unmodified viewport above.
    await page.addStyleTag({ content: '.user-viewport,.user-shell{height:auto!important;max-height:none!important;min-height:844px}.user-content{height:auto!important;max-height:none!important;overflow:visible!important;flex:none!important}.bottom-nav{position:relative!important;bottom:auto!important;flex-shrink:0!important}' });
    await page.screenshot({ path: path.join(output, id + '-full.png'), fullPage: true });
    captures.push({ id, route, viewport: { width: 390, height: 844 }, metrics, fullPageMethod: 'Expand scroll frame only; original viewport retained', capturedAt: new Date().toISOString() });
  }
  writeFileSync(path.join(output, 'capture-manifest.json'), JSON.stringify({ base, design, captures, errors, blocked }, null, 2) + '\n');
  console.log(JSON.stringify({ captures: captures.length, errors, blockedRequests: blocked.length }));
} finally {
  await browser.close();
}
