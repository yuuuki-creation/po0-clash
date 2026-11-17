import { expect, test } from '@playwright/test';

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    localStorage.setItem('po0-desktop-mock-settings-v1', JSON.stringify({ autoCheckUpdate: false, language: 'en' }));
    let ready = false;
    let pending = 'proxies';
    const host = window as any;
    const startup = new Promise<void>((resolve) => { host.releaseStartup = resolve; });
    host.navigateFromShell = (page: string) => {
      if (ready) host.__po0Emit('navigate', page);
      else pending = page;
    };
    host.webkit = { messageHandlers: { po0: { async postMessage({ cmd, args }: any) {
      if (cmd === 'app_info') await startup;
      if (cmd === 'ui_ready') {
        ready = true;
        host.__po0Emit('navigate', pending);
        return 'null';
      }
      const mock = await import(`${location.origin}/src/mock.ts`);
      return JSON.stringify(await mock.invoke(cmd, args)) ?? 'null';
    } } } };
  });
  await page.goto('/');
});

test('cold launch waits for listeners and applies the latest requested page', async ({ page }) => {
  await expect(page.locator('.the-content')).toHaveCount(0);
  await page.evaluate(() => {
    (window as any).navigateFromShell('profiles');
    (window as any).navigateFromShell('whitelist');
    (window as any).releaseStartup();
  });
  await expect(page.locator('.the-content')).toHaveAttribute('data-page', 'whitelist');
  await expect(page.locator('.base-page')).toContainText('Whitelist');
});

test('ready navigation handles legacy names and registers again after reload', async ({ page }) => {
  await page.evaluate(() => (window as any).releaseStartup());
  await expect(page.locator('.the-content')).toHaveAttribute('data-page', 'proxies');
  for (const [requested, expected] of [['profiles', 'profiles'], ['activity', 'connections'], ['tools', 'settings'], ['dashboard', 'home']]) {
    await page.evaluate((name) => (window as any).navigateFromShell(name), requested);
    await expect(page.locator('.the-content')).toHaveAttribute('data-page', expected);
  }
  await page.reload();
  await page.evaluate(() => {
    (window as any).navigateFromShell('profiles');
    (window as any).releaseStartup();
  });
  await expect(page.locator('.the-content')).toHaveAttribute('data-page', 'profiles');
  await expect(page.locator('.base-page')).toContainText('Profiles');
});
