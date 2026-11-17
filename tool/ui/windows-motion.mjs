import { writeFile } from 'node:fs/promises';
import assert from 'node:assert/strict';

export async function auditMotion(page, app, directory) {
  await page.locator('.the-menu .MuiListItemButton-root').filter({ hasText: app === 'po0' ? /^Home$/ : /^Profiles$/ }).click();
  const trigger = page.getByRole('button', { name: app === 'po0' ? 'Home cards' : 'New', exact: true });
  await trigger.waitFor();
  await trigger.evaluate((element) => element.setAttribute('data-motion-trigger', 'new-profile'));
  const measurements = {};
  for (const mode of ['enter', 'exit', 'interrupted', 'menu-enter', 'menu-exit']) {
    if (mode === 'menu-enter') {
      await page.keyboard.press('Escape');
      await page.locator('.MuiDialog-paper').waitFor({ state: 'detached' });
    }
    measurements[mode] = await page.evaluate(async (mode) => {
      const menu = mode.startsWith('menu-');
      const root = menu ? '.MuiMenu-root' : '.MuiDialog-root';
      const surface = menu ? '.MuiMenu-paper' : '.MuiDialog-paper';
      const trigger = document.querySelector('[data-motion-trigger]');
      const escape = () => document.querySelector(root)?.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', bubbles: true }));
      const frames = [];
      const animations = new Map();
      const events = [];
      const start = performance.now();
      const event = (name, action) => { events.push({ name, time: performance.now() - start }); action(); };
      if (mode.endsWith('exit')) event('close', escape);
      else if (menu) event('open', () => document.querySelector('.the-menu').dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, clientX: 80, clientY: 180 })));
      else event('open', () => trigger.click());
      if (mode === 'interrupted') {
        setTimeout(() => event('close', escape), 70);
        setTimeout(() => event('reopen', () => trigger.click()), 140);
        setTimeout(() => event('close', escape), 210);
        setTimeout(() => event('reopen', () => trigger.click()), 280);
      }
      await new Promise((resolve) => {
        function sample(now) {
          const container = document.querySelector(menu ? surface : '.MuiDialog-container');
          const paper = document.querySelector(surface);
          const style = container && getComputedStyle(container);
          const box = paper?.getBoundingClientRect();
          frames.push({ time: now - start, count: document.querySelectorAll(surface).length, opacity: style ? +style.opacity : 0, transform: style?.transform, width: box?.width, height: box?.height });
          for (const animation of document.querySelector(root)?.getAnimations({ subtree: true }) ?? []) {
            const timing = animation.effect.getTiming();
            const data = { property: animation.transitionProperty, duration: timing.duration, easing: timing.easing, keyframes: animation.effect.getKeyframes() };
            animations.set(JSON.stringify(data), data);
          }
          if (now - start < 850) requestAnimationFrame(sample);
          else resolve();
        }
        requestAnimationFrame(sample);
      });
      return { events, frames, animations: [...animations.values()] };
    }, mode);
    await writeFile(`${directory}/${app}-motion.json`, JSON.stringify(measurements, null, 2));
    await page.screenshot({ path: `${directory}/${app}-dialog-${mode}.png` });
    assert.equal(await page.locator(mode.startsWith('menu-') ? '.MuiMenu-paper' : '.MuiDialog-paper').count(), mode.endsWith('exit') ? 0 : 1, `${app}: ${mode} final surface count`);
  }
  await page.keyboard.press('Escape');
  await page.locator('.MuiDialog-paper').waitFor({ state: 'detached' });
  await writeFile(`${directory}/${app}-motion.json`, JSON.stringify(measurements, null, 2));
  console.log(app, 'motion timings:', JSON.stringify(Object.fromEntries(Object.entries(measurements).map(([name, data]) => [name, data.animations]))));
}
