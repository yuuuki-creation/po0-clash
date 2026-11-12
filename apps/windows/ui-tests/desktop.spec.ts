import { expect, test } from '@playwright/test';

const pages = ['Home', 'Proxies', 'Profiles', 'Whitelist', 'Connections', 'Rules', 'Logs', 'Settings'];

for (const os of ['windows', 'macos']) {
  for (const mode of ['light', 'dark']) {
    test(`${os} ${mode}: pages fit narrow and wide windows`, async ({ page }, info) => {
      const errors: string[] = [];
      page.on('pageerror', (error) => errors.push(error.message));
      await page.addInitScript(({ mode }) => {
        localStorage.setItem('po0-desktop-mock-settings-v1', JSON.stringify({ themeMode: mode, language: 'en', autoCheckUpdate: false }));
      }, { mode });
      await page.goto(`/?os=${os}`);
      for (const width of [900, 1180, 1600]) {
        await page.setViewportSize({ width, height: 800 });
        for (const name of pages) {
          await page.locator('.the-menu').getByText(name, { exact: true }).click();
          await expect(page.locator('.base-page > header')).toContainText(name === 'Proxies' ? 'Proxy Groups' : name);
          await expect(page.locator('.base-page')).toBeVisible();
          if (name === 'Home') {
            const overflow = await page.locator('.base-content').evaluate((el) => el.scrollWidth - el.clientWidth);
            expect(overflow, `home overflow at ${width}px`).toBeLessThanOrEqual(2);
          }
          if (width === 1180) {
            await page.mouse.move(0, 0);
            await page.waitForTimeout(350);
            await page.screenshot({ path: info.outputPath(`${os}-${mode}-${name.toLowerCase()}.png`) });
          }
        }
      }
      expect(errors).toEqual([]);
    });
  }
}

test('home card visibility is saved and restored without losing other card choices', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Home cards', exact: true }).click();
  await page.getByRole('checkbox', { name: 'Traffic', exact: true }).uncheck();
  await page.getByRole('button', { name: 'Save', exact: true }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(page.locator('.base-content').getByText('Traffic', { exact: true })).toHaveCount(0);
  await page.reload();
  await page.getByRole('button', { name: 'Home cards', exact: true }).click();
  await expect(page.getByRole('checkbox', { name: 'Traffic', exact: true })).not.toBeChecked();
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem('po0-desktop-mock-settings-v1')!));
  expect(saved.dashboardCards).toContain('speed');
  expect(saved.dashboardCards).not.toContain('traffic');
});

test('proxy search, selection and node tests work after resizing', async ({ page }) => {
  await page.goto('/');
  await page.locator('.the-menu').getByText('Proxies', { exact: true }).click();
  await page.getByRole('button', { name: 'View', exact: true }).click();
  await page.getByRole('menuitem', { name: 'Search', exact: true }).click();
  const search = page.getByRole('textbox', { name: 'Search groups and nodes' });
  await search.fill('Tokyo 01');
  const node = page.locator('[aria-pressed]').filter({ hasText: 'Tokyo 01' }).first();
  await expect(node).toBeVisible();
  await node.click();
  await expect(node).toHaveAttribute('aria-pressed', 'true');
  await node.getByRole('button', { name: 'Test this node', exact: true }).click();
  await expect(node.locator('.MuiCircularProgress-root')).toHaveCount(0);
  await page.setViewportSize({ width: 900, height: 650 });
  await search.clear();
  await page.getByRole('button', { name: 'View', exact: true }).click();
  await page.getByRole('menuitem', { name: 'Locate the current node', exact: true }).click();
  await expect(page.locator('[aria-pressed="true"]').first()).toBeVisible();
});

test('connection control reports stopped and running states', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('switch', { name: 'Disconnect', exact: true }).click();
  await expect(page.getByRole('switch', { name: 'Connect', exact: true })).not.toBeChecked();
  await page.getByRole('switch', { name: 'Connect', exact: true }).click();
  await expect(page.getByRole('switch', { name: 'Disconnect', exact: true })).toBeChecked();
});

test('both desktop shells show configured nodes while the proxy is stopped', async ({ page }) => {
  for (const os of ['windows', 'macos']) {
    await page.goto(`/?os=${os}`);
    await page.getByRole('switch', { name: 'Disconnect', exact: true }).click();
    await expect(page.getByRole('switch', { name: 'Connect', exact: true })).not.toBeChecked();
    await page.locator('.the-menu').getByText('Proxies', { exact: true }).click();
    await page.getByRole('button', { name: 'View', exact: true }).click();
    await page.getByRole('menuitem', { name: 'Search', exact: true }).click();
    await page.getByRole('textbox', { name: 'Search groups and nodes' }).fill('Tokyo 01');
    await expect(page.locator('[aria-pressed]').filter({ hasText: 'Tokyo 01' }).first()).toBeVisible();
    await expect(page.getByRole('button', { name: 'Test this node', exact: true })).toHaveCount(0);
    await page.getByRole('button', { name: 'View', exact: true }).click();
    await expect(page.getByRole('menuitem', { name: 'Test all', exact: true })).toBeDisabled();
  }
});

test('large text and reduced motion keep navigation and controls usable', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.setViewportSize({ width: 900, height: 700 });
  await page.addInitScript(() => localStorage.setItem('po0-desktop-mock-settings-v1', JSON.stringify({ textScale: 150, pageAnimation: false, autoCheckUpdate: false })));
  await page.goto('/');
  for (const name of ['Home', 'Proxies', 'Profiles', 'Whitelist', 'Settings']) {
    await page.locator('.the-menu').getByText(name, { exact: true }).click();
    await expect(page.locator('.base-page > header')).toContainText(name === 'Proxies' ? 'Proxy Groups' : name);
    const header = page.locator('.base-page > header');
    expect(await header.evaluate((el) => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(2);
  }
});
