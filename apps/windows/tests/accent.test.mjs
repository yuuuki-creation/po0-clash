import assert from 'node:assert/strict';
import test from 'node:test';
import { accentTokens, CARD_DARK, contrast, DEFAULT_ACCENT } from '../src/lib/accent.js';

const rgb = (hex) => parseInt(hex.slice(1), 16);
const presets = [0xff007aff, 0xff5856d6, 0xffaf52de, 0xffff2d55, 0xffff9500, 0xff34c759, 0xff30b0c7, 0xff8e8e93];

test('the default accent leaves the stylesheet pair in charge', () => {
  assert.equal(accentTokens(DEFAULT_ACCENT, { dark: false, variant: 'fidelity' }), null);
  assert.equal(accentTokens(DEFAULT_ACCENT, { dark: true, variant: 'tonalSpot' }), null);
});

test('any colour reads on a dark card, however dark it was chosen', () => {
  for (const color of [...presets, 0xff000000, 0xff101040, 0xff301010]) {
    const { accent } = accentTokens(color, { dark: true, variant: 'fidelity' });
    assert.ok(contrast(rgb(accent), CARD_DARK) >= 4.5, accent);
  }
});

test('text on the accent stays readable in both modes', () => {
  for (const color of presets) {
    for (const dark of [false, true]) {
      const { accent, onAccent } = accentTokens(color, { dark, variant: 'fidelity' });
      assert.ok(contrast(rgb(accent), rgb(onAccent)) >= 4.5, `${accent} ${onAccent}`);
    }
  }
});

test('a colour already readable on a dark card is left alone', () => {
  assert.equal(accentTokens(0xffff9500, { dark: true, variant: 'fidelity' }).accent, '#FF9500');
});

test('the scheme variant changes the saturation of the default accent too', () => {
  const { accent } = accentTokens(DEFAULT_ACCENT, { dark: false, variant: 'monochrome' });
  const [r, g, b] = [accent.slice(1, 3), accent.slice(3, 5), accent.slice(5, 7)];
  assert.ok(r === g && g === b, accent);
  assert.notEqual(accentTokens(DEFAULT_ACCENT, { dark: false, variant: 'vibrant' }).accent, accent);
});
