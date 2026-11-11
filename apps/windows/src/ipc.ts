declare global {
  interface Window {
    __TAURI_INTERNALS__?: unknown;
    __po0Emit?: (event: string, payload: unknown) => void;
    webkit?: { messageHandlers?: { po0?: { postMessage(message: unknown): Promise<string> } } };
  }
}

export type Platform = 'windows' | 'macos' | 'mock';

const webkit = window.webkit?.messageHandlers?.po0;

export const platform: Platform = window.__TAURI_INTERNALS__ ? 'windows' : webkit ? 'macos' : 'mock';

/** The look to draw: the browser mock shows the macOS chrome when asked with `?os=macos`. */
export const os: 'windows' | 'macos' =
  platform === 'macos' || (platform === 'mock' && new URLSearchParams(location.search).get('os') === 'macos')
    ? 'macos'
    : 'windows';

type Handler = (event: { payload: any }) => void;
const handlers = new Map<string, Set<Handler>>();

let tauri: Promise<{
  core: typeof import('@tauri-apps/api/core');
  event: typeof import('@tauri-apps/api/event');
  window: typeof import('@tauri-apps/api/window');
}> | null = null;

function loadTauri() {
  tauri ??= Promise.all([
    import('@tauri-apps/api/core'),
    import('@tauri-apps/api/event'),
    import('@tauri-apps/api/window'),
  ]).then(([core, event, window]) => ({ core, event, window }));
  return tauri;
}

let mock: Promise<typeof import('./mock')> | null = null;
const loadMock = () => (mock ??= import('./mock'));

export async function invoke<T = any>(command: string, args?: Record<string, unknown>): Promise<T> {
  if (platform === 'windows') return (await loadTauri()).core.invoke<T>(command, args);
  if (platform === 'macos') {
    try {
      return JSON.parse(await webkit!.postMessage({ cmd: command, args: args ?? {} })) as T;
    } catch (error) {
      throw error instanceof Error ? error.message : error;
    }
  }
  if (!import.meta.env.DEV) throw 'po0-clash must run inside its desktop shell';
  return (await loadMock()).invoke(command, args ?? {}) as T;
}

export async function listen(event: string, handler: Handler): Promise<() => void> {
  if (platform === 'windows') return (await loadTauri()).event.listen(event, handler);
  let set = handlers.get(event);
  if (!set) handlers.set(event, (set = new Set()));
  set.add(handler);
  return () => set!.delete(handler);
}

window.__po0Emit = (event, payload) => handlers.get(event)?.forEach((handler) => handler({ payload }));

export const win = {
  async minimize() {
    if (platform === 'windows') await (await loadTauri()).window.getCurrentWindow().minimize();
  },
  async toggleMaximize() {
    if (platform === 'windows') await (await loadTauri()).window.getCurrentWindow().toggleMaximize();
    else if (platform === 'macos') await invoke('window_zoom');
  },
  async close() {
    if (platform === 'windows') await (await loadTauri()).window.getCurrentWindow().close();
  },
  async isMaximized() {
    return platform === 'windows' ? (await loadTauri()).window.getCurrentWindow().isMaximized() : false;
  },
  async onResized(handler: () => void): Promise<() => void> {
    if (platform !== 'windows') return () => {};
    return (await loadTauri()).window.getCurrentWindow().onResized(handler);
  },
  async setBackground(r: number, g: number, b: number) {
    if (platform === 'windows') {
      await (await loadTauri()).window.getCurrentWindow().setBackgroundColor([r, g, b, 255]);
    } else if (platform === 'macos') {
      await invoke('set_window_background', { r, g, b });
    }
  },
};

// WKWebView has no drag-region CSS, so macOS moves the window from the same attribute Tauri reads on Windows.
if (platform === 'macos') {
  const onRegion = (event: MouseEvent) =>
    event.button === 0 && (event.target as Element | null)?.hasAttribute?.('data-tauri-drag-region');
  document.addEventListener('mousedown', (event) => {
    if (onRegion(event) && event.detail === 1) invoke('window_drag').catch(() => {});
  });
  document.addEventListener('dblclick', (event) => {
    if (onRegion(event)) invoke('window_zoom').catch(() => {});
  });
}
