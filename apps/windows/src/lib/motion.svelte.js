import { prefersReducedMotion } from 'svelte/motion';
import { app } from './core.svelte.js';
import { easeIn, easeOut, forOutro } from './easing.js';

export const motion = (ms) => (prefersReducedMotion.current ? 0 : ms);

/** `direction` is `drill` into a sub-page, `back` out of one, or empty between sidebar pages. */
export function navigate(page, tool = null, direction = '') {
  app.nav = direction;
  app.page = page;
  app.tool = tool;
}

export const menuIn = () => ({
  duration: motion(167),
  easing: easeIn,
  css: (t, u) => `opacity: ${t}; transform: translateY(${-8 * u}px)`,
});
export const menuOut = () => ({ duration: motion(83), css: (t) => `opacity: ${t}` });

export const dialogIn = () => ({
  duration: motion(250),
  easing: easeIn,
  css: (t, u) => `opacity: ${t}; transform: scale(${1 + 0.05 * u})`,
});
export const dialogOut = () => ({
  duration: motion(83),
  css: (t, u) => `opacity: ${t}; transform: scale(${1 + 0.05 * u})`,
});

export const scrimIn = () => ({ duration: motion(250), css: (t) => `opacity: ${t}` });
export const scrimOut = () => ({ duration: motion(83), css: (t) => `opacity: ${t}` });

const collapse = (node, gap) => {
  const height = node.offsetHeight;
  return (t, u) =>
    `overflow: hidden; min-height: 0; max-height: ${t * height}px; margin-bottom: ${-gap * u}px; opacity: ${t}`;
};

export const rowIn = (node, { gap = 4 } = {}) => ({
  duration: motion(250),
  easing: easeIn,
  css: collapse(node, gap),
});
export const rowOut = (node, { gap = 4 } = {}) => ({
  duration: motion(200),
  easing: forOutro(easeOut),
  css: collapse(node, gap),
});
