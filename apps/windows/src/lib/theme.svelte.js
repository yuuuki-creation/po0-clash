// Appearance is kept in this webview's storage until the core has an app settings model to hold it.
const KEY = 'po0.appearance';

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

const defaults = { mode: 'system', black: false, accent: '#007AFF', custom: [], scheme: 'standard', scaled: false, scale: 100 };
const softness = { vivid: '22%', muted: '6%' };

function load() {
  try {
    return { ...defaults, ...JSON.parse(localStorage.getItem(KEY) ?? '{}') };
  } catch {
    return { ...defaults };
  }
}

export const appearance = $state(load());

const systemDark = matchMedia('(prefers-color-scheme: dark)');
let prefersDark = $state(systemDark.matches);
systemDark.addEventListener('change', (event) => (prefersDark = event.matches));

export function watchAppearance() {
  $effect.root(() => {
    $effect(() => {
      const root = document.documentElement;
      const dark = appearance.mode === 'dark' || (appearance.mode === 'system' && prefersDark);
      root.toggleAttribute('data-dark', dark);
      root.toggleAttribute('data-black', appearance.black);
      const custom = appearance.accent.toUpperCase() !== '#007AFF';
      for (const name of ['--accent', '--accent-text', '--accent-solid']) {
        if (custom) root.style.setProperty(name, appearance.accent);
        else root.style.removeProperty(name);
      }
      if (softness[appearance.scheme]) root.style.setProperty('--soft', softness[appearance.scheme]);
      else root.style.removeProperty('--soft');
      root.style.zoom = appearance.scaled ? String(appearance.scale / 100) : '';
      try {
        localStorage.setItem(KEY, JSON.stringify(appearance));
      } catch {
        // Storage can be unavailable; the choice then lasts for this session.
      }
    });
  });
}
