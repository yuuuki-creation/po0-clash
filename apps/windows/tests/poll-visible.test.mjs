import assert from 'node:assert/strict';
import test from 'node:test';
import { pollVisible } from '../src/lib/poll-visible.ts';

test('visible polling waits for slow calls, resumes on show, and stops on cleanup', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const doc = new EventTarget();
  doc.hidden = false;
  Object.defineProperty(globalThis, 'document', { value: doc, configurable: true });
  t.after(() => delete globalThis.document);

  const calls = [];
  const stop = pollVisible(() => new Promise((resolve, reject) => calls.push({ resolve, reject })));
  t.mock.timers.tick(0);
  assert.equal(calls.length, 1);
  t.mock.timers.tick(10_000);
  assert.equal(calls.length, 1);

  function setHidden(hidden) {
    doc.hidden = hidden;
    doc.dispatchEvent(new Event('visibilitychange'));
  }

  setHidden(true);
  setHidden(false);
  assert.equal(calls.length, 1);
  setHidden(true);
  calls[0].resolve();
  await Promise.resolve();
  t.mock.timers.tick(10_000);
  assert.equal(calls.length, 1);

  setHidden(false);
  assert.equal(calls.length, 2);
  calls[1].reject(new Error('temporary failure'));
  await Promise.resolve();
  t.mock.timers.tick(1_000);
  assert.equal(calls.length, 3);

  stop();
  calls[2].resolve();
  await Promise.resolve();
  setHidden(true);
  setHidden(false);
  t.mock.timers.tick(10_000);
  assert.equal(calls.length, 3);
});
