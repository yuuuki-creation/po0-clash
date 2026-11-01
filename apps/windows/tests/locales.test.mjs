import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import en from '../src/lib/locales/en.js';
import ja from '../src/lib/locales/ja.js';
import ru from '../src/lib/locales/ru.js';
import zh from '../src/lib/locales/zh.js';

function sources(dir) {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return name === 'locales' ? [] : sources(path);
    return /\.(svelte|js)$/.test(name) ? [readFileSync(path, 'utf-8')] : [];
  });
}

test('every language defines the same strings', () => {
  const keys = Object.keys(en).sort();
  for (const [name, table] of Object.entries({ zh, ja, ru })) {
    assert.deepEqual(Object.keys(table).sort(), keys, name);
  }
});

test('every literal t() key in the interface exists', () => {
  const used = sources('src').flatMap((text) => [...text.matchAll(/\bt\(\s*'([^']+)'/g)].map((m) => m[1]));
  assert.ok(used.length > 100);
  assert.deepEqual([...new Set(used)].filter((key) => !(key in en)), []);
});
