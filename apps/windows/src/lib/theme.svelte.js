import { getCurrentWindow } from '@tauri-apps/api/window';
import { accentTokens } from './accent.js';
import { settings } from './settings.svelte.js';

export const presets = [
  ['pine', '#24694C'],
  ['blue', '#007AFF'],
  ['indigo', '#5856D6'],
  ['purple', '#AF52DE'],
  ['pink', '#FF2D55'],
  ['orange', '#FF9500'],
  ['green', '#34C759'],
  ['teal', '#30B0C7'],
  ['graphite', '#8E8E93'],
];

export const toHex = (argb) => `#${(argb & 0xffffff).toString(16).padStart(6, '0').toUpperCase()}`;
export const toArgb = (hex) => (0xff000000 | parseInt(hex.slice(1), 16)) >>> 0;

const systemDark = matchMedia('(prefers-color-scheme: dark)');
let prefersDark = $state(systemDark.matches);
systemDark.addEventListener('change', (event) => (prefersDark = event.matches));

const ACCENT_PROPERTIES = { accent: '--accent', hover: '--accent-hover', press: '--accent-press', onAccent: '--on-accent' };

function applyAccent(root, tokens) {
  for (const [key, property] of Object.entries(ACCENT_PROPERTIES)) {
    if (tokens) root.style.setProperty(property, tokens[key]);
    else root.style.removeProperty(property);
  }
}

// The window is opaque, so a resize or a slow first paint shows this colour rather than white.
function syncWindowBackground(root) {
  const page = getComputedStyle(root).getPropertyValue('--bg').trim();
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(page.slice(i, i + 2), 16));
  getCurrentWindow().setBackgroundColor([r, g, b, 255]).catch(() => {});
}

export function watchAppearance() {
  $effect.root(() => {
    let look = null;
    let fade;
    $effect(() => {
      const s = settings.value;
      if (!s) return;
      const root = document.documentElement;
      const dark = s.themeMode === 'dark' || (s.themeMode === 'system' && prefersDark);
      const next = [dark, s.pureBlack, s.themeColor, s.schemeVariant].join();
      if (look !== null && look !== next) {
        root.classList.add('theming');
        clearTimeout(fade);
        fade = setTimeout(() => root.classList.remove('theming'), 240);
      }
      look = next;
      root.toggleAttribute('data-dark', dark);
      root.toggleAttribute('data-black', s.pureBlack);
      applyAccent(root, accentTokens(s.themeColor, { dark, variant: s.schemeVariant }));
      root.style.zoom = s.textScale ? String(s.textScale / 100) : '';
      syncWindowBackground(root);
    });
  });
}
