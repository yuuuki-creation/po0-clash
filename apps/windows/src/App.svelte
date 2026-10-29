<script>
  import { app } from './lib/core.svelte.js';
  import { t } from './lib/i18n.js';
  import Icon from './lib/Icon.svelte';
  import Home from './pages/Home.svelte';
  import Profiles from './pages/Profiles.svelte';
  import Proxies from './pages/Proxies.svelte';
  import Settings from './pages/Settings.svelte';
  import Whitelist from './pages/Whitelist.svelte';

  const tabs = [
    { id: 'home', icon: 'power', page: Home },
    { id: 'proxies', icon: 'globe', page: Proxies },
    { id: 'profiles', icon: 'list', page: Profiles },
    { id: 'whitelist', icon: 'shield', page: Whitelist },
    { id: 'settings', icon: 'sliders', page: Settings },
  ];
  let current = $state('home');
  const Page = $derived(tabs.find((tab) => tab.id === current).page);
</script>

<main>
  <Page />
</main>

{#if app.notice}
  <div class="notice glass" class:error={app.notice.error} role="status">
    <span>{app.notice.text}</span>
    <button type="button" class="text-button" aria-label={t('common.dismiss')} onclick={() => (app.notice = null)}
      >✕</button
    >
  </div>
{/if}

<div class="tabbar glass" role="tablist">
  {#each tabs as tab (tab.id)}
    <button
      type="button"
      role="tab"
      aria-selected={current === tab.id}
      class:active={current === tab.id}
      onclick={() => (current = tab.id)}
    >
      <Icon name={tab.icon} />
      <span>{t(`tab.${tab.id}`)}</span>
    </button>
  {/each}
</div>
