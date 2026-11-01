import assert from 'node:assert/strict';
import test from 'node:test';
import { bezier, easeIn, easeOut, forOutro } from '../src/lib/easing.js';

test('a bezier starts at 0, ends at 1 and matches the linear curve', () => {
  const linear = bezier(0.25, 0.25, 0.75, 0.75);
  assert.equal(linear(0), 0);
  assert.equal(linear(1), 1);
  assert.ok(Math.abs(linear(0.5) - 0.5) < 1e-3);
});

test('the Fluent curves decelerate on the way in and accelerate on the way out', () => {
  assert.ok(easeIn(0.2) > 0.6);
  assert.ok(easeOut(0.2) < 0.1);
});

test('an outro plays the curve forward as its clock runs from 1 to 0', () => {
  const outro = forOutro(easeOut);
  const shownAtQuarterTime = outro(0.75);
  assert.ok(Math.abs(shownAtQuarterTime - (1 - easeOut(0.25))) < 1e-9);
  assert.ok(shownAtQuarterTime > 0.8);
});
