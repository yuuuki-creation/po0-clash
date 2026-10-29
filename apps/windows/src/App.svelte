<script>
  import { app } from './lib/core.svelte.js';
  import { t } from './lib/i18n.js';
  import Home from './pages/Home.svelte';
  import Profiles from './pages/Profiles.svelte';
  import Proxies from './pages/Proxies.svelte';
  import Settings from './pages/Settings.svelte';
  import Whitelist from './pages/Whitelist.svelte';

  const tabs = [
    { id: 'home', page: Home },
    { id: 'proxies', page: Proxies },
    { id: 'profiles', page: Profiles },
    { id: 'whitelist', page: Whitelist },
    { id: 'settings', page: Settings },
  ];
  let current = $state('home');
  const Page = $derived(tabs.find((tab) => tab.id === current).page);
</script>

<div class="tabs" role="tablist">
  {#each tabs as tab (tab.id)}
    <button
      type="button"
      role="tab"
      aria-selected={current === tab.id}
      class:active={current === tab.id}
      onclick={() => (current = tab.id)}>{t(`tab.${tab.id}`)}</button
    >
  {/each}
</div>

<main>
  <Page />
</main>

{#if app.notice}
  <div class="notice" class:error={app.notice.error} role="status">
    <span>{app.notice.text}</span>
    <button type="button" class="plain" aria-label={t('common.dismiss')} onclick={() => (app.notice = null)}>✕</button>
  </div>
{/if}
