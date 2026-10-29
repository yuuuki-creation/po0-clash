// Drives the installed app through WebView2's DevTools port: start the real engine in both route modes, then stop.
// Expects the app to have been launched with WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=--remote-debugging-port=<port>.
import { execSync } from 'node:child_process';

const port = process.env.SMOKE_DEVTOOLS_PORT ?? '9222';
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function pageTarget() {
  const deadline = Date.now() + 30_000;
  while (Date.now() < deadline) {
    try {
      const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      const page = targets.find((t) => t.type === 'page');
      if (page) return page;
    } catch {}
    await sleep(500);
  }
  throw new Error('no WebView2 DevTools target');
}

const ws = new WebSocket((await pageTarget()).webSocketDebuggerUrl);
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
  /ProxyEnable\s+REG_DWORD\s+0x1/.test(
    execSync('reg query "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyEnable', {
      encoding: 'utf8',
    }),
  );

function check(condition, message) {
  if (!condition) throw new Error(message);
  console.log(`ok - ${message}`);
}

const step = async (name, fn) => {
  console.log(`# ${name}`);
  return fn();
};

console.log('status', JSON.stringify(await invoke('status')));

const imported = await step('import a share link', () =>
  invoke('import_links', { text: 'ss://YWVzLTI1Ni1nY206c21va2U@127.0.0.1:8388#smoke' }),
);
check(imported.added === 1, 'one node imported');
const profiles = await invoke('profiles');
check(profiles.some((p) => p.kind === 'links' && p.selected), 'links profile selected');

// Direct mode keeps the runner's own traffic flowing while the engine owns the route.
await invoke('set_mode', { mode: 'direct' });

await step('system proxy', async () => {
  await invoke('set_route_mode', { routeMode: 'systemProxy' });
  await invoke('start');
  await waitFor('running');
  check(proxyEnabled(), 'system proxy set while running');
  const groups = await invoke('groups');
  check(groups.length > 0, `engine reports ${groups.length} groups`);
  console.log('traffic', JSON.stringify(await invoke('traffic')));
});

await step('tun', async () => {
  await invoke('set_route_mode', { routeMode: 'tun' });
  await waitFor('running');
  check(!proxyEnabled(), 'system proxy cleared in tun mode');
  const adapters = execSync('powershell -NoProfile -Command "(Get-NetAdapter).Name"', { encoding: 'utf8' });
  check(/po0-clash/.test(adapters), 'tun adapter po0-clash is up');
});

await step('stop', async () => {
  await invoke('stop');
  await waitFor('stopped');
  check(!proxyEnabled(), 'system proxy clear after stop');
});

console.log('whitelist', JSON.stringify(await invoke('whitelist')));
ws.close();
