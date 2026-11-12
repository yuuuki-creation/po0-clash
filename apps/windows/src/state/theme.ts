import { alpha, createTheme, type Shadows, type Theme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import { useSnapshot } from 'valtio';
import { platform, win } from '../ipc';
import { settings } from './settings';

/** The core's built-in accent; it stands for "no choice made", which shows the default palette below. */
export const DEFAULT_ACCENT = 0xff0064e0;

export const presets: [string, string][] = [
  ['blue', '#007AFF'],
  ['indigo', '#5856D6'],
  ['purple', '#AF52DE'],
  ['pink', '#FF2D55'],
  ['orange', '#FF9500'],
  ['green', '#34C759'],
  ['pine', '#24694C'],
  ['teal', '#30B0C7'],
  ['graphite', '#8E8E93'],
];

export const toHex = (argb: number) => `#${(argb & 0xffffff).toString(16).padStart(6, '0').toUpperCase()}`;
export const toArgb = (hex: string) => (0xff000000 | parseInt(hex.slice(1), 16)) >>> 0;

const FONT =
  '-apple-system, BlinkMacSystemFont, "Microsoft YaHei UI", "Microsoft YaHei", Roboto, "Helvetica Neue", Arial, sans-serif, "Apple Color Emoji"' +
  (platform === 'windows' ? ', "Segoe UI Emoji"' : '');

const light = {
  primary: '#007AFF',
  secondary: '#FC9B76',
  text: '#000000',
  textSecondary: '#3C3C4399',
  error: '#FF3B30',
  warning: '#FF9500',
  success: '#06943D',
  paper: '#F5F5F5',
  page: '#ECECEC',
  card: '#FFFFFF',
  divider: 'rgba(0, 0, 0, 0.06)',
  scroller: '#90939980',
};

const dark = {
  ...light,
  primary: '#0A84FF',
  secondary: '#FF9F0A',
  text: '#FFFFFF',
  textSecondary: '#EBEBF599',
  error: '#FF453A',
  warning: '#FF9F0A',
  success: '#30D158',
  paper: '#2E303D',
  page: '#1E1F27',
  card: '#282A36',
  divider: 'rgba(255, 255, 255, 0.06)',
  scroller: '#555555',
};

const black = { ...dark, paper: '#0A0A0A', page: '#000000', card: '#141414' };

declare module '@mui/material/styles' {
  interface Palette {
    surface: { page: string; card: string };
  }
  interface PaletteOptions {
    surface?: { page: string; card: string };
  }
}

function useSystemDark() {
  const [prefersDark, setPrefersDark] = useState(() => matchMedia('(prefers-color-scheme: dark)').matches);
  useEffect(() => {
    const query = matchMedia('(prefers-color-scheme: dark)');
    const onChange = (event: MediaQueryListEvent) => setPrefersDark(event.matches);
    query.addEventListener('change', onChange);
    return () => query.removeEventListener('change', onChange);
  }, []);
  return prefersDark;
}

export function useAppTheme(): Theme {
  const s = useSnapshot(settings).value;
  const systemDark = useSystemDark();
  const isDark = s?.themeMode === 'dark' || (s?.themeMode !== 'light' && systemDark);
  const tone = isDark ? (s?.pureBlack ? black : dark) : light;
  const custom = s && s.themeColor !== DEFAULT_ACCENT ? toHex(s.themeColor) : null;
  const primary = custom ?? tone.primary;

  const theme = useMemo(
    () =>
      createTheme({
        breakpoints: { values: { xs: 0, sm: 650, md: 900, lg: 1200, xl: 1536 } },
        palette: {
          mode: isDark ? 'dark' : 'light',
          primary: { main: primary },
          secondary: { main: tone.secondary },
          info: { main: primary },
          error: { main: tone.error },
          warning: { main: tone.warning },
          success: { main: tone.success },
          text: { primary: tone.text, secondary: tone.textSecondary },
          background: { paper: tone.paper, default: tone.paper },
          divider: tone.divider,
          surface: { page: tone.page, card: tone.card },
        },
        shadows: Array(25).fill('none') as Shadows,
        typography: { fontFamily: FONT },
        shape: { borderRadius: 4 },
        components: {
          MuiButton: { defaultProps: { disableElevation: true }, styleOverrides: { root: {} } },
          MuiTab: { styleOverrides: { root: { textTransform: 'none' } } },
          MuiDialog: { styleOverrides: { paper: { backgroundColor: tone.card, backgroundImage: 'none' } } },
          MuiMenu: {
            styleOverrides: {
              paper: {
                backgroundColor: tone.card,
                backgroundImage: 'none',
                boxShadow: '0 4px 20px rgba(0, 0, 0, 0.18)',
                border: `1px solid ${tone.divider}`,
              },
            },
          },
          MuiPopover: { styleOverrides: { paper: { backgroundImage: 'none' } } },
          MuiTooltip: { defaultProps: { arrow: true, enterDelay: 400 } },
        },
      }),
    [isDark, primary, tone],
  );

  useEffect(() => {
    const root = document.documentElement;
    root.style.setProperty('--divider-color', tone.divider);
    root.style.setProperty('--background-color', tone.page);
    root.style.setProperty('--card-color', tone.card);
    root.style.setProperty('--paper-color', tone.paper);
    root.style.setProperty('--selection-color', isDark ? '#3E3E3E' : '#f5f5f5');
    root.style.setProperty('--scroller-color', tone.scroller);
    root.style.setProperty('--primary-main', primary);
    root.style.setProperty('--secondary-main', tone.secondary);
    root.style.setProperty('--background-color-alpha', alpha(primary, 0.1));
    root.style.setProperty('--text-primary', tone.text);
    root.style.colorScheme = isDark ? 'dark' : 'light';
    root.style.zoom = s?.textScale ? String(s.textScale / 100) : '';
    const [r, g, b] = [1, 3, 5].map((i) => parseInt(tone.paper.slice(i, i + 2), 16));
    win.setBackground(r, g, b).catch(() => {});
  }, [tone, primary, isDark, s?.textScale]);

  return theme;
}
