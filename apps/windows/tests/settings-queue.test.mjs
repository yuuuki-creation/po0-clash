import assert from 'node:assert/strict';
import test from 'node:test';
import { createSettingsQueue } from '../src/lib/settings-queue.js';

const deferred = () => {
  let resolve;
  let reject;
  const promise = new Promise((done, fail) => { resolve = done; reject = fail; });
  return { promise, resolve, reject };
};

function harness({ read, write } = {}) {
  const state = {
    stored: { themeMode: 'system', pureBlack: false, dashboardCards: ['currentNode', 'speed', 'traffic'] },
    visible: null,
    errors: [],
    writes: [],
  };
  const queue = createSettingsQueue({
    read: () => read ? read(state) : structuredClone(state.stored),
    write: async (next) => {
      state.writes.push(structuredClone(next));
      if (write) await write(next, state);
      else state.stored = structuredClone(next);
    },
    publish: (value) => (state.visible = value),
    onError: (error) => state.errors.push(error),
  });
  return { queue, state };
}

test('writes complete snapshots in intent order while retaining newer optimistic choices', async () => {
  const started = deferred();
  const release = deferred();
  const { queue, state } = harness({
    write: async (next, state) => {
      if (state.writes.length === 1) { started.resolve(); await release.promise; }
      state.stored = structuredClone(next);
    },
  });
  await queue.load();
  const first = queue.update({ themeMode: 'dark' });
  await started.promise;
  const second = queue.update({ pureBlack: true });
  const third = queue.update({ themeMode: 'light' });
  assert.equal(state.writes.length, 1);
  assert.equal(state.visible.themeMode, 'light');
  assert.equal(state.visible.pureBlack, true);
  release.resolve();
  await Promise.all([first, second, third]);
  assert.deepEqual(state.writes.map(({ themeMode, pureBlack }) => ({ themeMode, pureBlack })), [
    { themeMode: 'dark', pureBlack: false },
    { themeMode: 'dark', pureBlack: true },
    { themeMode: 'light', pureBlack: true },
  ]);
  assert.deepEqual(state.visible, state.stored);
});

test('an old read cannot replace an update made while it was in flight', async () => {
  const started = deferred();
  const release = deferred();
  let reads = 0;
  const { queue, state } = harness({
    read: async (state) => {
      const value = structuredClone(state.stored);
      if (++reads === 1) { started.resolve(); await release.promise; }
      return value;
    },
  });
  const load = queue.load();
  await started.promise;
  const save = queue.update({ pureBlack: true });
  release.resolve();
  await load;
  assert.equal(state.visible.pureBlack, true);
  await save;
  assert.equal(state.stored.pureBlack, true);
});

test('failed choices roll back without discarding later choices or persisting failed fields', async () => {
  const { queue, state } = harness({
    write: async (next, state) => {
      if (state.writes.length === 1) throw new Error('cannot save theme');
      state.stored = structuredClone(next);
    },
  });
  await queue.load();
  const failed = queue.update({ themeMode: 'dark' });
  const saved = queue.update({ pureBlack: true });
  assert.equal(await failed, false);
  assert.equal(state.visible.pureBlack, true);
  assert.equal(await saved, true);
  assert.equal(state.stored.themeMode, 'system');
  assert.equal(state.stored.pureBlack, true);
  assert.equal(state.errors.length, 1);
});

test('failed reads do not poison the next operation and queued patches own their arrays', async () => {
  let reads = 0;
  const { queue, state } = harness({
    read: (state) => {
      if (++reads === 1) throw new Error('read unavailable');
      return structuredClone(state.stored);
    },
  });
  await assert.rejects(queue.load(), /read unavailable/);
  const dashboardCards = ['traffic', 'speed', 'currentNode'];
  const save = queue.update({ dashboardCards });
  dashboardCards.reverse();
  await save;
  assert.deepEqual(state.stored.dashboardCards, ['traffic', 'speed', 'currentNode']);
});

test('normalized snapshots are read before the next patch is merged', async () => {
  const { queue, state } = harness({
    write: (next, state) => {
      state.stored = { ...next, normalized: 'from core' };
    },
  });
  await queue.load();
  await Promise.all([queue.update({ themeMode: 'dark' }), queue.update({ pureBlack: true })]);
  assert.equal(state.writes[1].normalized, 'from core');
  assert.equal(state.visible.normalized, 'from core');
});

test('awaiting a save also waits for newer queued choices before a caller can reload the page', async () => {
  const secondStarted = deferred();
  const release = deferred();
  const { queue, state } = harness({
    write: async (next, state) => {
      if (state.writes.length === 2) { secondStarted.resolve(); await release.promise; }
      state.stored = structuredClone(next);
    },
  });
  await queue.load();
  let firstResolved = false;
  const first = queue.update({ language: 'en' }).then(() => (firstResolved = true));
  const second = queue.update({ language: 'ja' });
  await secondStarted.promise;
  await Promise.resolve();
  assert.equal(firstResolved, false);
  release.resolve();
  await first;
  assert.equal(state.stored.language, 'ja');
  await second;
});
