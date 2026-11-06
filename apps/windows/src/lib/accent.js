export const DEFAULT_ACCENT = 0xff0064e0;

export const CARD_DARK = 0x2b2b2b;
const ON_ACCENT_LIGHT = 0xffffff;
const ON_ACCENT_DARK = 0x0a1317;
const READABLE = 4.5;
const NEARLY_READABLE = 3;

const SATURATION = { monochrome: 0, neutral: 0.35, vibrant: 1.25, expressive: 1.25, rainbow: 1.25, fruitSalad: 1.25 };

const channels = (rgb) => [(rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255];
const fromChannels = ([r, g, b]) => (Math.round(r) << 16) | (Math.round(g) << 8) | Math.round(b);
const hex = (rgb) => `#${rgb.toString(16).padStart(6, '0').toUpperCase()}`;

function luminance(rgb) {
  const linear = channels(rgb).map((c) => {
    const v = c / 255;
    return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
}

export function contrast(a, b) {
  const [high, low] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (high + 0.05) / (low + 0.05);
}

function toHsl(rgb) {
  const [r, g, b] = channels(rgb).map((c) => c / 255);
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  const d = max - min;
  if (!d) return [0, 0, l];
  const s = d / (1 - Math.abs(2 * l - 1));
  const h = max === r ? ((g - b) / d + 6) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
  return [h * 60, s, l];
}

function fromHsl([h, s, l]) {
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = l - c / 2;
  const [r, g, b] = [[c, x, 0], [x, c, 0], [0, c, x], [0, x, c], [x, 0, c], [c, 0, x]][Math.floor(h / 60) % 6];
  return fromChannels([r, g, b].map((v) => (v + m) * 255));
}

const mix = (rgb, target, amount) => fromChannels(channels(rgb).map((c, i) => c + (channels(target)[i] - c) * amount));

function shiftUntilReadable(rgb, background, step) {
  let [h, s, l] = toHsl(rgb);
  let result = rgb;
  while (contrast(result, background) < READABLE && l + step > 0 && l + step < 1) {
    l += step;
    result = fromHsl([h, s, l]);
  }
  return result;
}

// Mid tones that nearly carry white text are nudged darker; light ones keep their colour and take dark text.
const forLightMode = (rgb) => (contrast(rgb, ON_ACCENT_LIGHT) >= NEARLY_READABLE ? shiftUntilReadable(rgb, ON_ACCENT_LIGHT, -0.01) : rgb);

const onAccent = (rgb) =>
  contrast(rgb, ON_ACCENT_LIGHT) >= contrast(rgb, ON_ACCENT_DARK) ? ON_ACCENT_LIGHT : ON_ACCENT_DARK;

/**
 * The accent tokens for a chosen colour, or null when the stylesheet's own default pair applies.
 * In dark mode a colour is lightened only as far as it takes to read on a dark card.
 */
export function accentTokens(argb, { dark, variant }) {
  const factor = SATURATION[variant] ?? 1;
  if (argb === DEFAULT_ACCENT && factor === 1) return null;
  const [h, s, l] = toHsl(argb & 0xffffff);
  const tinted = fromHsl([h, Math.min(1, s * factor), l]);
  const accent = dark ? shiftUntilReadable(tinted, CARD_DARK, 0.01) : forLightMode(tinted);
  const shift = dark ? 0 : ON_ACCENT_LIGHT;
  return {
    accent: hex(accent),
    hover: hex(mix(accent, shift, 0.08)),
    press: hex(mix(accent, shift, 0.16)),
    onAccent: hex(onAccent(accent)),
  };
}
