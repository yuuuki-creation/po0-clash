import assert from 'node:assert/strict';
import test from 'node:test';
import { compareVersions, newestAbove, parseVersion } from '../src/lib/version.js';

const releases = [
  { tag_name: 'native-v7.1.0-beta.1', html_url: 'https://example.com/7.1b1', body: '', draft: false },
  { tag_name: 'native-v7.0.0', html_url: 'https://example.com/7.0', body: 'Notes', draft: false },
  { tag_name: 'native-v7.0.0-beta.10', html_url: 'https://example.com/7.0b10', body: '', draft: false },
  { tag_name: 'native-v9.0.0', html_url: 'https://example.com/9', body: '', draft: true },
  { tag_name: 'v8.0.0', html_url: 'https://example.com/flutter', body: '', draft: false },
];

test('offers the newest native release', () => {
  assert.deepEqual(newestAbove('6.9.0', releases), {
    version: '7.0.0',
    url: 'https://example.com/7.0',
    notes: 'Notes',
  });
  assert.equal(newestAbove('7.0.0-beta.2', releases).version, '7.1.0-beta.1');
  assert.equal(newestAbove('7.0.0', releases), null);
  assert.equal(newestAbove('7.1.0-beta.1', releases), null);
  assert.equal(newestAbove('7.0.0', { message: 'rate limited' }), null);
});

test('orders pre-releases by semver', () => {
  const above = (a, b) => compareVersions(parseVersion(a), parseVersion(b)) > 0;
  assert.ok(above('7.0.0-beta.10', '7.0.0-beta.2'));
  assert.ok(above('7.0.0', '7.0.0-rc.1'));
  assert.ok(above('7.0.0-rc.1', '7.0.0-beta.9'));
  assert.ok(above('7.0.0-beta.a', '7.0.0-beta.9'));
  assert.equal(parseVersion('7.0'), null);
});
