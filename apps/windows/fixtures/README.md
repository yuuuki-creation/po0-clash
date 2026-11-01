# Verify the Windows layout

Run these commands on the build machine from `apps/windows`.

```sh
npm ci
npm test
npm run build
npm run dev -- --host 127.0.0.1
```

Open [the dashboard fixture](http://127.0.0.1:5173/fixtures/) or [the proxies fixture](http://127.0.0.1:5173/fixtures/?page=proxies).
The fixture mounts the production `App.svelte` and mocks only Tauri commands. Vite does not include this entry in the application build.

1. Resize the browser through 720, 900, 1200, and 1920 pixels. Check that cards and nodes use the available width without page overflow.
2. On the dashboard, click **Edit dashboard**. Drag a card by its handle. Reload and check that the order remains.
3. Focus a handle and press an arrow key. Check that the card moves, then reload to check persistence.
4. Remove a card and add it again. Leave edit mode and check the mode selector, current-node menu, and delay button.
5. On Proxies, choose a group. Search, change sorting and density, and locate the current node. A search with no matches must retain the group navigation and tools.
6. Select a node by its body. Click its delay separately and check that the selection does not change.
7. Test a group and then a single node. During the group test, each node shows a waiting indicator. During the single test, only that node waits. Results replace the waiting indicators.
8. Enable reduced motion in the browser. Repeat the tests and check that waiting indicators remain visible without rotation, progress movement, or result movement.
9. Change theme and pure black in quick succession under Tools. Reload and check that both choices remain.

The fixture stores settings under `po0-windows-ui-fixture-settings-v1` in browser local storage. Remove that key to reset it.
`window.fixture` exposes the real `app` and `settings` objects for browser assertions.

The browser fixture cannot prove WebView2 drag routing. In the Windows app, repeat the handle drag, reload the app, and verify the persisted order.
The main Tauri window sets `dragDropEnabled` to `false`, as required by [Tauri's Windows HTML5 drag documentation](https://v2.tauri.app/reference/config/#windowconfig).
