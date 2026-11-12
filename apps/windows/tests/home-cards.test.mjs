import assert from 'node:assert/strict';
import test from 'node:test';
import { HOME_CARDS, saveHomeCards, shownHomeCards } from '../src/lib/home-cards.js';

test('old settings show every desktop card', () => {
  assert.deepEqual(shownHomeCards(undefined), HOME_CARDS.map(({ id }) => id));
});

test('card visibility survives reload without duplicating cards or changing the layout order', () => {
  const saved = JSON.parse(JSON.stringify(['traffic', 'subscription', 'traffic']));
  assert.deepEqual(shownHomeCards(saved), ['subscription', 'traffic']);
});

test('all cards can be hidden and unrelated settings survive a desktop edit', () => {
  assert.deepEqual(shownHomeCards([]), []);
  assert.deepEqual(shownHomeCards(['future']), []);
  assert.deepEqual(saveHomeCards(['speed', 'currentNode', 'intranetIp'], ['traffic']), ['speed', 'intranetIp', 'traffic']);
});
