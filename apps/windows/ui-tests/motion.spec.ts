import { expect, test } from '@playwright/test';

test.beforeEach(async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.addInitScript(() => localStorage.setItem('po0-desktop-mock-settings-v1', JSON.stringify({ autoCheckUpdate: false, language: 'en' })));
  await page.goto('/');
});

test('dialog keeps its content through exit and restores focus after unmount', async ({ page }) => {
  const trigger = page.getByRole('button', { name: 'Home cards', exact: true });
  await trigger.click();
  const dialog = page.getByRole('dialog', { name: 'Home cards', exact: true });
  await expect(dialog).toBeVisible();
  await page.clock.install();
  await page.clock.pauseAt(new Date());
  await page.clock.runFor(300);
  await dialog.getByRole('button', { name: 'Cancel', exact: true }).evaluate((el: HTMLButtonElement) => el.click());
  await page.clock.runFor(16);
  await expect(dialog).toHaveCount(1);
  await expect(dialog.getByRole('checkbox', { name: 'Traffic', exact: true })).toHaveCount(1);
  await page.clock.runFor(300);
  await expect(dialog).toHaveCount(0);
  await expect(trigger).toBeFocused();
  await trigger.evaluate((el: HTMLButtonElement) => el.click());
  await page.clock.runFor(300);
  await expect(dialog).toBeVisible();
});

test('nested script dialog closes independently and keeps the library open', async ({ page }) => {
  await page.locator('.the-menu').getByText('Profiles', { exact: true }).click();
  await page.getByRole('button', { name: 'Override scripts', exact: true }).click();
  const library = page.getByRole('dialog').first();
  await library.getByRole('button', { name: 'New Script', exact: true }).click();
  await expect(page.locator('.MuiDialog-paper')).toHaveCount(2);
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toHaveCount(1);
  await expect(library).toContainText('Override scripts');
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toHaveCount(0);
});

test('desktop page switches keep the header stationary', async ({ page }) => {
  for (const name of ['Profiles', 'Proxies', 'Settings', 'Home']) {
    await page.locator('.the-menu').getByText(name, { exact: true }).click();
    const style = await page.locator('.base-page').evaluate((el) => ({ transform: getComputedStyle(el).transform, animation: getComputedStyle(el).animationName }));
    expect(style).toEqual({ transform: 'none', animation: 'none' });
  }
});

test('traffic graph animates samples and stops immediately for reduced motion', async ({ page }) => {
  const graph = page.locator('.traffic-graph canvas');
  await expect.poll(() => graph.evaluate((el) => el.getAnimations().some((a) => a.playState === 'running'))).toBe(true);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect.poll(() => graph.evaluate((el) => el.getAnimations().filter((a) => a.playState === 'running').length)).toBe(0);
  await page.setViewportSize({ width: 1180, height: 800 });
  await expect.poll(() => graph.evaluate((el: HTMLCanvasElement) => Math.abs(el.width - Math.round(el.clientWidth * devicePixelRatio)))).toBeLessThanOrEqual(1);
});

test('large text dialog content fits its paper and remains keyboard dismissible', async ({ page }) => {
  await page.setViewportSize({ width: 900, height: 700 });
  await page.evaluate(() => { document.documentElement.style.zoom = '1.5'; });
  await page.getByRole('button', { name: 'Home cards', exact: true }).click();
  const dialog = page.getByRole('dialog');
  expect(await dialog.evaluate((el) => el.scrollWidth - el.clientWidth)).toBeLessThanOrEqual(1);
  await page.keyboard.press('Escape');
  await expect(dialog).toHaveCount(0);
});
