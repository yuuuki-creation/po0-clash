import assert from 'node:assert/strict';
import test from 'node:test';
import { formatUsage } from '../src/lib/i18n.js';

const GB = 1024 ** 3;
const MB = 1024 ** 2;

test('usage shares the unit when both sides have the same one', () => {
  assert.equal(formatUsage(185 * GB, 500 * GB), '185 / 500 GB');
});

test('usage keeps both units when they differ', () => {
  assert.equal(formatUsage(512 * MB, 100 * GB), '512 MB / 100 GB');
});
