import assert from 'node:assert/strict';
import test from 'node:test';
import { createUpdateChecker } from '../src/lib/update-checker.js';

test('a failed direct check is retried as soon as the proxy connects', async () => {
  let calls = 0;
  const releases = [];
  const checker = createUpdateChecker({
    enabled: () => true,
    fetchRelease: async () => { if (++calls === 1) throw Error('offline'); return { version: '8.1.1' }; },
    publish: (release) => releases.push(release), failure: assert.fail,
  });
  await checker.check();
  await checker.check();
  assert.equal(calls, 1);
  await checker.check(false, true);
  assert.equal(calls, 2);
  assert.equal(releases[0].version, '8.1.1');
});

test('connecting during a direct request schedules one retry after it fails', async () => {
  let fail;
  let calls = 0;
  const releases = [];
  const checker = createUpdateChecker({
    enabled: () => true,
    fetchRelease: () => ++calls === 1 ? new Promise((_, reject) => { fail = reject; }) : Promise.resolve(null),
    publish: (release) => releases.push(release), failure: assert.fail,
  });
  const pending = checker.check();
  const connected = checker.check(false, true);
  checker.check(false, true);
  fail(Error('direct request failed'));
  await Promise.all([pending, connected]);
  await new Promise(setImmediate);
  assert.equal(calls, 2);
  assert.deepEqual(releases, [null]);
});

test('successful checks are quiet for six hours and manual checks remain available', async () => {
  let calls = 0;
  let time = 0;
  let enabled = false;
  const checker = createUpdateChecker({
    now: () => time, enabled: () => enabled,
    fetchRelease: async () => { calls++; return null; }, publish: () => {}, failure: assert.fail,
  });
  await checker.check();
  assert.equal(calls, 0);
  await checker.check(true);
  assert.equal(calls, 1);
  enabled = true;
  await checker.check(false, true);
  assert.equal(calls, 1);
  time = 6 * 60 * 60 * 1000;
  await checker.check();
  assert.equal(calls, 2);
});
