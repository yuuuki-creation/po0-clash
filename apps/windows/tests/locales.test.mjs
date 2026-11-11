import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { pathToFileURL } from 'node:url';
import en from '../src/lib/locales/en.js';
import ja from '../src/lib/locales/ja.js';
import ru from '../src/lib/locales/ru.js';
import zh from '../src/lib/locales/zh.js';

const tables = { en: { ...en }, zh: { ...zh }, ja: { ...ja }, ru: { ...ru } };
const partsDir = 'src/lib/locales/parts';
for (const name of readdirSync(partsDir)) {
  const part = (await import(pathToFileURL(join(partsDir, name)).href)).default;
  assert.deepEqual(Object.keys(part).sort(), Object.keys(tables).sort(), `${name} languages`);
  for (const [code, strings] of Object.entries(part)) Object.assign(tables[code], strings);
}

function sources(dir) {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return name === 'locales' ? [] : sources(path);
    return /\.(tsx?|js)$/.test(name) ? [readFileSync(path, 'utf-8')] : [];
  });
}

test('every language defines the same strings', () => {
  const keys = Object.keys(tables.en).sort();
  for (const name of ['zh', 'ja', 'ru']) {
    assert.deepEqual(Object.keys(tables[name]).sort(), keys, name);
  }
});

test('every literal t() key in the interface exists', () => {
  const used = sources('src').flatMap((text) => [...text.matchAll(/\bt\(\s*'([^']+)'/g)].map((m) => m[1]));
  assert.ok(used.length > 100);
  assert.deepEqual([...new Set(used)].filter((key) => !(key in tables.en)), []);
});

test('no string is defined but unused', () => {
  const text = sources('src').join('\n');
  const unused = Object.keys(tables.en).filter((key) => {
    const prefix = key.slice(0, key.lastIndexOf('.') + 1);
    return !text.includes(`'${key}'`) && !text.includes(`\`${prefix}\${`);
  });
  assert.deepEqual(unused, []);
});
