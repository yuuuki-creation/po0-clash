import assert from 'node:assert/strict';
import test from 'node:test';
import { arrangeCards, displayOrder, moveCard } from '../src/lib/dashboard-cards.js';

const CORE_DEFAULT = ['currentNode', 'speed', 'mode', 'takeover', 'whitelist', 'traffic', 'connections', 'memory', 'intranetIp', 'subscription', 'exitIp'];

test('moves cards to the target position in either direction without changing the input', () => {
  const cards = ['currentNode', 'speed', 'traffic', 'connections'];
  assert.deepEqual(moveCard(cards, 'currentNode', 'traffic'), ['speed', 'traffic', 'currentNode', 'connections']);
  assert.deepEqual(moveCard(cards, 'connections', 'speed'), ['currentNode', 'connections', 'speed', 'traffic']);
  assert.deepEqual(cards, ['currentNode', 'speed', 'traffic', 'connections']);
});

test('stale or identical drop targets leave the card list intact', () => {
  const cards = ['currentNode', 'speed'];
  for (const [from, to] of [['unknown', 'speed'], ['speed', 'unknown'], ['speed', 'speed']]) {
    assert.deepEqual(moveCard(cards, from, to), cards);
  }
});

const ids = (column) => column.map((section) => section.cards);

test('the untouched core default lays out as the design: controls and info left, speed and stats right', () => {
  const [left, right] = arrangeCards(displayOrder(CORE_DEFAULT));
  assert.deepEqual(ids(left), [
    ['currentNode', 'mode', 'takeover'],
    ['whitelist', 'subscription', 'exitIp', 'intranetIp'],
  ]);
  assert.deepEqual(ids(right), [['speed'], ['traffic', 'connections', 'memory']]);
});

test('an edited list is taken as written and reads across the column break in order', () => {
  const cards = ['memory', 'speed', 'currentNode', 'traffic'];
  assert.deepEqual(displayOrder(cards), cards);
  const flat = arrangeCards(cards).flatMap((column) => column.flatMap((section) => section.cards));
  assert.deepEqual(flat, cards);
});

test('rows of one section stay together until the column breaks', () => {
  const columns = arrangeCards(['traffic', 'connections', 'memory']);
  assert.equal(columns.flat().length, 2);
});

test('no cards make no columns', () => {
  assert.deepEqual(arrangeCards([]), []);
});
