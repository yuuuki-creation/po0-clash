import assert from 'node:assert/strict';
import test from 'node:test';
import { HOME_CARDS, shownHomeCards } from '../src/lib/home-cards.js';

test('old settings show every desktop card', () => {
  assert.deepEqual(shownHomeCards(undefined), HOME_CARDS.map(({ id }) => id));
});

test('card visibility survives reload without duplicating cards or changing the layout order', () => {
  const saved = JSON.parse(JSON.stringify(['traffic', 'profile', 'traffic']));
  assert.deepEqual(shownHomeCards(saved), ['profile', 'traffic']);
});

test('all cards can be hidden and unknown ids do not create broken cards', () => {
  assert.deepEqual(shownHomeCards([]), []);
  assert.deepEqual(shownHomeCards(['future']), []);
});
