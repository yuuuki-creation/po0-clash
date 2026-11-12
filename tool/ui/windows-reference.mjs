import { chromium } from '../../apps/windows/node_modules/playwright/index.mjs';
import { createServer } from 'node:http';
import { mkdir, writeFile } from 'node:fs/promises';

const out = 'reference-shots';
await mkdir(out, { recursive: true });
const config = `proxies:
  - name: Local Test Node
    type: socks5
    server: 127.0.0.1
    port: 18616
proxy-groups:
  - name: Proxy
    type: select
    proxies: [DIRECT, Local Test Node]
  - name: Streaming
    type: select
    proxies: [DIRECT, Local Test Node]
rules:
  - MATCH,Proxy
`;
const server = createServer((_, response) => {
  response.writeHead(200, { 'content-type': 'text/yaml', 'subscription-userinfo': 'upload=1024; download=2097152; total=10737418240; expire=1893456000' });
  response.end(config);
});
await new Promise((resolve) => server.listen(18615, '127.0.0.1', resolve));
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function attach(port) {
  for (let attempt = 0; attempt < 90; attempt++) {
    try {
      const browser = await chromium.connectOverCDP(`http://127.0.0.1:${port}`);
      const page = browser.contexts()[0].pages()[0];
      await page.waitForFunction(() => typeof window.__TAURI_INTERNALS__?.invoke === 'function' && document.querySelector('.base-page'), { timeout: 45_000 });
      return { browser, page };
    } catch (error) {
      if (attempt === 89) throw error;
      await sleep(500);
    }
  }
}
const call = (page, cmd, args = {}) => page.evaluate(({ cmd, args }) => window.__TAURI_INTERNALS__.invoke(cmd, args), { cmd, args });

async function capture(page, app) {
  await page.reload();
  await page.locator('.base-page').waitFor();
  await page.waitForTimeout(1500);
  const items = page.locator('.the-menu .MuiListItemButton-root');
  const labels = await items.allTextContents();
  console.log(app, 'pages:', JSON.stringify(labels));
  for (let i = 0; i < labels.length; i++) {
    const label = labels[i].trim().replace(/[^a-zA-Z0-9\u4e00-\u9fff]+/g, '-');
    await items.nth(i).click();
    await page.waitForTimeout(900);
    await page.screenshot({ path: `${out}/${app}-${i}-${label}.png` });
    await writeFile(`${out}/${app}-${i}-${label}.txt`, await page.locator('body').innerText());
  }
}

try {
  const official = await attach(9223);
  await call(official.page, 'patch_verge_config', { payload: { language: 'en', theme_mode: 'light', enable_system_proxy: false } });
  await call(official.page, 'import_profile', { url: 'http://127.0.0.1:18615/config.yaml', option: null });
  const profiles = await call(official.page, 'get_profiles');
  const profile = profiles.items.find((item) => item.url?.includes('127.0.0.1:18615'));
  if (profile) await call(official.page, 'patch_profiles_config', { profiles: { current: profile.uid } });
  await capture(official.page, 'official-verge');
  await official.browser.close();

  const po0 = await attach(9222);
  const settings = await call(po0.page, 'app_settings');
  await call(po0.page, 'set_app_settings', { settings: { ...settings, language: 'en', themeMode: 'light', autoCheckUpdate: false } });
  await call(po0.page, 'add_subscription', { url: 'http://127.0.0.1:18615/config.yaml' });
  const ours = await call(po0.page, 'profiles');
  if (!ours.some((item) => item.selected)) await call(po0.page, 'select_profile', { id: ours[0].id });
  await call(po0.page, 'set_mode', { mode: 'rule' });
  await call(po0.page, 'start');
  try { await capture(po0.page, 'po0'); } finally { await call(po0.page, 'stop'); }
  await po0.browser.close();
} finally {
  server.close();
}
