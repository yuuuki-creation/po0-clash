import { flushSync } from 'svelte';
import { prefersReducedMotion } from 'svelte/motion';
import { app } from './core.svelte.js';
import { settings } from './settings.svelte.js';

/** Milliseconds for a micro-animation, or 0 when Windows asks for less motion. */
export const motion = (ms) => (prefersReducedMotion.current ? 0 : ms);

/** `direction` is `forward` into a sub-page, `back` out of one, or `switch` between sidebar pages. */
export function navigate(page, tool = null, direction = 'switch') {
  const update = () => {
    app.page = page;
    app.tool = tool;
    flushSync();
  };
  const animate = settings.value?.pageAnimation && !prefersReducedMotion.current && document.startViewTransition;
  if (!animate || (app.page === page && app.tool === tool)) return update();
  document.documentElement.dataset.nav = direction;
  document.startViewTransition(update);
}

const ease = (t) => 1 - (1 - t) ** 3;

export function pop(node, { duration = 180, from = 0.96, y = -4 } = {}) {
  return {
    duration: motion(duration),
    easing: ease,
    css: (t) => `opacity: ${t}; transform: translateY(${(1 - t) * y}px) scale(${from + (1 - from) * t})`,
  };
}

export function rise(node, { duration = 220 } = {}) {
  const height = node.offsetHeight;
  return {
    duration: motion(duration),
    easing: ease,
    css: (t) =>
      `opacity: ${t}; transform: scale(${0.98 + 0.02 * t}); max-height: ${t * height}px; overflow: hidden`,
  };
}
