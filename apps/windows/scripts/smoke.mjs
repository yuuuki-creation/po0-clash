// Drives the installed app through WebView2's DevTools endpoint: import a node, connect through the system proxy and
// through TUN, check the traffic and the system proxy, then stop.
//
// SMOKE_DEVTOOLS  DevTools base URL (default http://127.0.0.1:9222), e.g. an ssh forward to the test machine
// SMOKE_REMOTE    command prefix that runs PowerShell on the test machine (default: run powershell locally)
// SMOKE_LINK      share link of the node to import (default: an unreachable placeholder, checks the direct mode only)
// SMOKE_PROBES    two URLs fetched through the node, one per route mode; the caller checks the node saw both hosts
import { execFileSync } from 'node:child_process';

const devtools = new URL(process.env.SMOKE_DEVTOOLS ?? 'http://127.0.0.1:9222');
const remote = process.env.SMOKE_REMOTE?.split(' ').filter(Boolean);
const link = process.env.SMOKE_LINK;
const probes = (process.env.SMOKE_PROBES ?? '').split(' ').filter(Boolean);
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function powershell(script) {
  const [command, ...args] = remote ?? ['powershell'];
  const encoded = Buffer.from(`$ProgressPreference = 'SilentlyContinue'; ${script}`, 'utf16le').toString('base64');
  return execFileSync(command, [...args, 'powershell', '-NoProfile', '-EncodedCommand', encoded], {
    encoding: 'utf8',
  }).trim();
}

async function pageTarget() {
  const deadline = Date.now() + 30_000;
  while (Date.now() < deadline) {
    try {
      const targets = await (await fetch(new URL('/json/list', devtools))).json();
      const page = targets.find((t) => t.type === 'page');
      if (page) return page;
    } catch {}
    await sleep(500);
  }
  throw new Error('no WebView2 DevTools target');
}

const target = new URL((await pageTarget()).webSocketDebuggerUrl);
target.host = devtools.host;
const ws = new WebSocket(target);
await new Promise((resolve, reject) => {
  ws.onopen = resolve;
  ws.onerror = reject;
});
const pending = new Map();
let nextId = 0;
ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  pending.get(message.id)?.(message);
  pending.delete(message.id);
};

function evaluate(expression) {
  return new Promise((resolve, reject) => {
    const id = ++nextId;
    pending.set(id, ({ error, result }) => {
      if (error) return reject(new Error(error.message));
      const thrown = result.exceptionDetails;
      if (thrown) return reject(new Error(thrown.exception?.value ?? thrown.exception?.description ?? thrown.text));
      resolve(result.result.value);
    });
    ws.send(
      JSON.stringify({
        id,
        method: 'Runtime.evaluate',
        params: { expression, awaitPromise: true, returnByValue: true },
      }),
    );
  });
}

const invoke = (command, args = {}) =>
  evaluate(`window.__TAURI_INTERNALS__.invoke(${JSON.stringify(command)}, ${JSON.stringify(args)})`);

async function waitFor(state) {
  const deadline = Date.now() + 45_000;
  while (Date.now() < deadline) {
    const { engine } = await invoke('status');
    if (engine.state === state) return;
    if (engine.state === 'failed') throw new Error(`engine failed: ${engine.message}`);
    await sleep(500);
  }
  throw new Error(`engine did not reach ${state}`);
}

const proxyEnabled = () =>
  powershell(
    "(Get-ItemProperty 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings').ProxyEnable",
  ) === '1';

const fetchThroughSystemProxy = (url) =>
  powershell(`(Invoke-WebRequest -UseBasicParsing -TimeoutSec 20 '${url}').StatusCode`);

const fetchDirectly = (url) => powershell(`curl.exe -s -o NUL -m 20 -w '%{http_code}' '${url}'`);

async function eventually(predicate) {
  for (let i = 0; i < 20 && !predicate(); i++) await sleep(500);
  return predicate();
}

function check(condition, message) {
  if (!condition) throw new Error(`not ok - ${message}`);
  console.log(`ok - ${message}`);
}

console.log('status', JSON.stringify(await invoke('status')));

const imported = await invoke('import_links', { text: link ?? 'ss://YWVzLTI1Ni1nY206c21va2U@127.0.0.1:8388#smoke' });
check(imported.profile.kind === 'links', `imported ${imported.added} new node(s) into the links profile`);
check((await invoke('profiles')).some((p) => p.kind === 'links' && p.selected), 'links profile selected');
// Without a real node only the direct mode keeps the machine's own traffic flowing.
await invoke('set_mode', { mode: link ? 'rule' : 'direct' });

console.log('# system proxy');
await invoke('set_route_mode', { routeMode: 'systemProxy' });
await invoke('start');
await waitFor('running');
check(proxyEnabled(), 'system proxy set while running');
const groups = await invoke('groups');
check(groups.length > 0, `engine reports ${groups.length} groups`);
if (probes[0]) check(fetchThroughSystemProxy(probes[0]) === '200', `fetched ${probes[0]} through the system proxy`);
console.log('traffic', JSON.stringify(await invoke('traffic')));

console.log('# tun');
await invoke('set_route_mode', { routeMode: 'tun' });
await waitFor('running');
check(!proxyEnabled(), 'system proxy cleared in tun mode');
check(await eventually(() => /po0-clash/.test(powershell('(Get-NetAdapter).Name -join " "'))), 'tun adapter po0-clash is up');
if (probes[1]) check(fetchDirectly(probes[1]) === '200', `fetched ${probes[1]} through tun`);
if (link) console.log('exit ip', JSON.stringify(await invoke('exit_ip')));

console.log('# stop');
await invoke('stop');
await waitFor('stopped');
check(!proxyEnabled(), 'system proxy clear after stop');
check(
  await eventually(() => !/po0-clash/.test(powershell('(Get-NetAdapter).Name -join " "'))),
  'tun adapter removed',
);
check(
  await eventually(() => powershell('@(Get-Process mihomo -ErrorAction SilentlyContinue).Count') === '0'),
  'no mihomo.exe left',
);

console.log('whitelist', JSON.stringify(await invoke('whitelist')));
ws.close();
