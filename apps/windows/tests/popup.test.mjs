import assert from 'node:assert/strict';
import test from 'node:test';
import { placePopup } from '../src/lib/popup.js';

const viewport = { width: 720, height: 560 };
const size = { width: 200, height: 240 };

test('opens under the anchor, aligned to its end by default', () => {
  const anchor = { left: 400, right: 500, top: 40, bottom: 72 };
  assert.deepEqual(placePopup(anchor, size, viewport), { left: 300, top: 76 });
  assert.deepEqual(placePopup(anchor, size, viewport, { align: 'start' }), { left: 400, top: 76 });
});

test('opens upward when only that fits', () => {
  const anchor = { left: 400, right: 500, top: 480, bottom: 512 };
  assert.equal(placePopup(anchor, size, viewport).top, 236);
});

test('stays inside the window when neither side has room', () => {
  const anchor = { left: 0, right: 100, top: 100, bottom: 132 };
  const tall = { width: 200, height: 520 };
  const { left, top } = placePopup(anchor, tall, viewport);
  assert.equal(left, 8);
  assert.equal(top, 32);
});
