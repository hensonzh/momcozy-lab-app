import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { join, resolve, sep } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(process.env.MOMCOZY_WEB_DEMO_BUILD ?? 'build/web-demo');
const base = process.env.MOMCOZY_WEB_DEMO_BASE_HREF ?? '/';
const mime = (path) => path.endsWith('.js') ? 'text/javascript'
  : path.endsWith('.wasm') ? 'application/wasm'
  : path.endsWith('.json') ? 'application/json'
  : path.endsWith('.svg') ? 'image/svg+xml'
  : path.endsWith('.png') ? 'image/png'
  : path.endsWith('.woff2') ? 'font/woff2'
  : path.endsWith('.ttf') ? 'font/ttf'
  : path.endsWith('.otf') ? 'font/otf'
  : 'text/html';

async function startServer(missingAssets) {
  const server = createServer(async (request, response) => {
    try {
      const url = new URL(request.url, 'http://localhost');
      if (url.pathname === '/favicon.ico') {
        response.writeHead(204);
        response.end();
        return;
      }
      if (!url.pathname.startsWith(base)) throw new Error('Outside demo site');
      const relative = decodeURIComponent(url.pathname.slice(base.length)) || 'index.html';
      const file = resolve(join(root, relative));
      if (!file.startsWith(root + sep) || !(await stat(file)).isFile()) {
        throw new Error('Missing or unsafe asset');
      }
      response.writeHead(200, {
        'Content-Type': mime(file),
        'Cache-Control': 'no-store',
      });
      response.end(await readFile(file));
    } catch {
      missingAssets.push(request.url);
      response.writeHead(404);
      response.end('Not found');
    }
  });
  await new Promise((ready) => server.listen(0, '127.0.0.1', ready));
  return { server, origin: `http://127.0.0.1:${server.address().port}` };
}

async function newPage(browser, site, blocked, errors, viewport) {
  const context = await browser.newContext({ viewport });
  // Abort ALL cross-origin traffic, not only the business domains we know today.
  await context.route('**/*', (route) => {
    const url = route.request().url();
    const target = new URL(url);
    const expected = new URL(site);
    if (target.origin !== expected.origin || !target.pathname.startsWith(expected.pathname)) {
      blocked.push(url);
      return route.abort();
    }
    return route.continue();
  });
  const page = await context.newPage();
  page.on('pageerror', (error) => errors.push(error.message));
  return { context, page };
}

async function ready(page) {
  await page.getByRole('button', { name: 'Reset demo' }).waitFor();
  await page.getByRole('group', { name: /Mia/ }).first().waitFor();
}

async function addScheduleItem(page, title) {
  await page.getByRole('button', { name: 'Schedule', exact: true }).click();
  await page.getByRole('button', { name: /Add to schedule/ }).click();
  const field = page.getByRole('textbox', { name: 'For example: baby checkup' });
  await field.click();
  // Wait for Flutter to attach the editable field; filling the initial
  // semantics-only input can otherwise lose keystrokes on CanvasKit.
  await page.waitForFunction(() =>
    document.activeElement?.getAttribute('aria-label') === 'For example: baby checkup'
    && document.activeElement?.getAttribute('autocorrect') === 'on');
  await field.fill(title);
  await page.locator('flt-semantics[role="button"]:not([aria-disabled])')
    .filter({ hasText: 'Add to schedule' }).last().click();
  await page.getByRole('dialog').waitFor({ state: 'hidden' });
  await page.getByRole('button', { name: `More options for ${title}` }).waitFor();
}

test('Web demo: fictional data, edit/reset/reload, isolated tabs and scripted chat; zero cross-origin requests',
  { timeout: 120_000 }, async () => {
    const missingAssets = [], blocked = [], errors = [];
    const { server, origin } = await startServer(missingAssets);
    const site = origin + base;
    let browser;
    try {
      browser = await chromium.launch({
        headless: true,
        executablePath: process.env.CHROME_BIN || undefined,
      });
      const { context, page } = await newPage(
        browser, site, blocked, errors, { width: 390, height: 844 });
      await page.goto(site);
      await ready(page);
      assert.equal(await page.getByRole('button', { name: 'Sign in' }).count(), 0);
      await page.getByRole('button', { name: 'Baby', exact: true }).click();
      await page.getByRole('button', { name: /Current baby: Luna/ }).waitFor();
      await addScheduleItem(page, 'Web demo walk');

      // Same browser context, different tab; no localStorage or shared state.
      const other = await context.newPage();
      other.on('pageerror', (error) => errors.push(error.message));
      await other.goto(site);
      await ready(other);
      await other.getByRole('button', { name: 'Schedule', exact: true }).click();
      assert.equal(await other.getByRole('button', { name: 'More options for Web demo walk' }).count(), 0);

      // Reload the *modified* tab before resetting it. It must lose the edit.
      await page.reload();
      await page.getByRole('button', { name: 'Reset demo' }).waitFor();
      await page.getByRole('button', { name: 'Schedule', exact: true }).click();
      assert.equal(await page.getByRole('button', { name: 'More options for Web demo walk' }).count(), 0);
      await addScheduleItem(page, 'Reset me');
      await page.getByRole('button', { name: 'Reset demo' }).click();
      await page.getByRole('button', { name: 'Schedule', exact: true }).click();
      assert.equal(await page.getByRole('button', { name: 'More options for Reset me' }).count(), 0);
      await page.reload();
      await page.getByRole('button', { name: 'Reset demo' }).waitFor();
      await page.getByRole('button', { name: 'Momcozy AI', exact: true }).click();
      const composer = page.getByRole('textbox', { name: 'Ask Momcozy AI anything...' });
      await composer.click();
      await page.waitForFunction(() =>
        document.activeElement?.getAttribute('aria-label') === 'Ask Momcozy AI anything...'
        && document.activeElement?.getAttribute('autocorrect') === 'on');
      await composer.fill('How is Luna feeding?');
      await page.locator('flt-semantics[role="button"]:not([aria-disabled])')
        .filter({ hasText: 'Send' }).last().click();
      await page.getByText(/In this demo, Luna has a sample feeding entry/).waitFor();
      await page.getByRole('button', { name: 'More', exact: true }).click();
      await page.getByText(/The AI chat is scripted/).waitFor();
      assert.equal(await page.getByRole('button', { name: 'Request account deletion' }).count(), 0);

      const desktop = await newPage(browser, site, blocked, errors, { width: 1280, height: 900 });
      await desktop.page.goto(site);
      await ready(desktop.page);
      assert.equal(await desktop.page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
      await desktop.context.close();
      await context.close();
      assert.deepEqual(blocked, [], `Unexpected outbound requests: ${blocked.join(', ')}`);
      assert.deepEqual(missingAssets, [], `Missing local assets: ${missingAssets.join(', ')}`);
      assert.deepEqual(errors, [], `Browser exceptions: ${errors.join(', ')}`);
    } finally {
      await browser?.close();
      await new Promise((done) => server.close(done));
    }
  });
