import { settings } from './settings.svelte.js';

export const presets = [
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

const softness = { vibrant: '22%', expressive: '22%', rainbow: '22%', fruitSalad: '22%', monochrome: '6%', neutral: '6%' };

const systemDark = matchMedia('(prefers-color-scheme: dark)');
let prefersDark = $state(systemDark.matches);
systemDark.addEventListener('change', (event) => (prefersDark = event.matches));

export function watchAppearance() {
  $effect.root(() => {
    $effect(() => {
      const s = settings.value;
      if (!s) return;
      const root = document.documentElement;
      root.toggleAttribute('data-dark', s.themeMode === 'dark' || (s.themeMode === 'system' && prefersDark));
      root.toggleAttribute('data-black', s.pureBlack);
      root.classList.toggle('nav-icons', !s.showNavLabels);
      const accent = toHex(s.themeColor);
      for (const name of ['--accent', '--accent-text', '--accent-solid']) {
        if (accent !== '#007AFF') root.style.setProperty(name, accent);
        else root.style.removeProperty(name);
      }
      if (softness[s.schemeVariant]) root.style.setProperty('--soft', softness[s.schemeVariant]);
      else root.style.removeProperty('--soft');
      root.style.zoom = s.textScale ? String(s.textScale / 100) : '';
    });
  });
}
