<script>
  import { getCurrentWindow } from '@tauri-apps/api/window';
  import { t } from './i18n.js';
  import Icon from './Icon.svelte';

  const appWindow = getCurrentWindow();
  let maximized = $state(false);

  $effect(() => {
    const sync = () => appWindow.isMaximized().then((value) => (maximized = value));
    sync();
    const unlisten = appWindow.onResized(sync);
    return () => unlisten.then((stop) => stop());
  });
</script>

<div class="window-controls">
  <button type="button" title={t('window.minimize')} aria-label={t('window.minimize')} onclick={() => appWindow.minimize()}
    ><Icon name="minimize" /></button
  >
  <button
    type="button"
    title={maximized ? t('window.restore') : t('window.maximize')}
    aria-label={maximized ? t('window.restore') : t('window.maximize')}
    onclick={() => appWindow.toggleMaximize()}><Icon name={maximized ? 'restore' : 'maximize'} /></button
  >
  <button
    type="button"
    class="close"
    title={t('window.close')}
    aria-label={t('window.close')}
    onclick={() => appWindow.close()}><Icon name="close" /></button
  >
</div>
