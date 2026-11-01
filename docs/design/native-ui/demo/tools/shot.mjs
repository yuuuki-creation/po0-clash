// node shot.mjs <url> <w> <h> <step>...
// steps: click:<text> | sel:<css> | type:<text> | size:<w>x<h> | wait:<ms> | shot:<file> | eval:<js>
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [url, w, h, ...steps] = process.argv.slice(2);
const port = 9300 + Math.floor(Math.random() * 500);
const profile = mkdtempSync(join(tmpdir(), 'po0-shot-'));
const chrome = spawn(
  process.env.CHROME ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe',
  ['--headless=new', '--disable-gpu', '--hide-scrollbars', `--remote-debugging-port=${port}`,
    `--user-data-dir=${profile}`, 'about:blank'],
  { stdio: 'ignore' },
);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let target;
for (let i = 0; i < 40 && !target; i++) {
  await sleep(250);
  try {
    target = (await (await fetch(`http://127.0.0.1:${port}/json`)).json()).find((t) => t.type === 'page');
  } catch {}
}
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0;
const pending = new Map();
const errors = [];
ws.onmessage = ({ data }) => {
  const m = JSON.parse(data);
  if (m.id) pending.get(m.id)?.(m.result ?? m.error);
  if (m.method === 'Runtime.exceptionThrown') errors.push(m.params.exceptionDetails.exception?.description ?? m.params.exceptionDetails.text);
  if (m.method === 'Runtime.consoleAPICalled' && m.params.type === 'error') errors.push(m.params.args.map((a) => a.value ?? a.description).join(' '));
  if (m.method === 'Log.entryAdded' && m.params.entry.level === 'error' && !/attribute d|favicon/.test(m.params.entry.text + m.params.entry.url)) errors.push(`${m.params.entry.text} ${m.params.entry.url ?? ''}`);
};
const send = (method, params = {}) => new Promise((r) => {
  pending.set(++id, r);
  ws.send(JSON.stringify({ id, method, params }));
});
const evaluate = async (expression) => {
  const out = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  return out.exceptionDetails ? `EVAL ERROR ${out.exceptionDetails.exception?.description}` : out.result?.value;
};
const metrics = (width, height) => send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: false });

await send('Page.enable');
await send('Runtime.enable');
await send('Log.enable');
await metrics(+w, +h);
await send('Page.navigate', { url });
await sleep(3500);

for (const step of steps) {
  const at = step.indexOf(':');
  const [op, arg] = [step.slice(0, at), step.slice(at + 1)];
  if (op === 'wait') await sleep(+arg);
  if (op === 'eval') console.log(JSON.stringify(await evaluate(arg)));
  if (op === 'size') {
    const [width, height] = arg.split('x').map(Number);
    await metrics(width, height);
    await sleep(400);
  }
  if (op === 'type') await send('Input.insertText', { text: arg });
  if (op === 'fit') {
    const [width, height] = await evaluate('[document.documentElement.scrollWidth, document.documentElement.scrollHeight]');
    await metrics(width, height);
    await sleep(300);
  }
  if (op === 'probe') {
    const [label, how] = arg.split('=>');
    const find = how.startsWith('css ')
      ? `document.querySelector(${JSON.stringify(how.slice(4))})`
      : `[...document.querySelectorAll('button,a')].find(e=>e.textContent.trim()===${JSON.stringify(how)}||e.getAttribute('aria-label')===${JSON.stringify(how)})`;
    const found = await evaluate(`(async()=>{const b=${find};if(!b)return 'MISS';b.click();await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));const seen=document.getAnimations().map(a=>{const t=a.effect.getTiming();const n=a.animationName||a.transitionProperty||'waapi';return n+' '+Math.round(t.duration)+'ms'}).filter(x=>!/^pulse /.test(x));return [...new Set(seen)].join(', ')||'none'})()`);
    console.log(`${label}: ${found}`);
    await sleep(700);
  }
  if (op === 'click' || op === 'sel') {
    const find = op === 'sel'
      ? `document.querySelector(${JSON.stringify(arg)})`
      : `[...document.querySelectorAll('button,a,[role=tab]')].find(e=>e.textContent.trim()===${JSON.stringify(arg)}||e.getAttribute('aria-label')===${JSON.stringify(arg)})`;
    const hit = await evaluate(`(()=>{const b=${find};if(!b)return false;b.click();return true})()`);
    if (!hit) console.log(`MISS ${step}`);
    await sleep(120);
  }
  if (op === 'shot') {
    const { data } = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
    writeFileSync(arg, Buffer.from(data, 'base64'));
  }
}
console.log(errors.length ? `ERRORS:\n${errors.join('\n')}` : 'no console errors');
ws.close();
chrome.kill();
await sleep(500);
rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
process.exit(0);
