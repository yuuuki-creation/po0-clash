import assert from 'node:assert/strict';
import test from 'node:test';
import { displayOrder, moveCard } from '../src/lib/dashboard-cards.js';

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

test('the untouched core default lays out as the Bento design order', () => {
  assert.deepEqual(displayOrder(CORE_DEFAULT), [
    'currentNode',
    'mode',
    'takeover',
    'whitelist',
    'subscription',
    'exitIp',
    'intranetIp',
    'speed',
    'traffic',
    'connections',
    'memory',
  ]);
});

test('an edited list is taken as written', () => {
  const cards = ['memory', 'speed', 'currentNode', 'traffic'];
  assert.deepEqual(displayOrder(cards), cards);
});

