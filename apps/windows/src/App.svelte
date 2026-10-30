<script>
  import { app } from './lib/core.svelte.js';
  import { t } from './lib/i18n.js';
  import Icon from './lib/Icon.svelte';
  import Dashboard from './pages/Dashboard.svelte';
  import Profiles from './pages/Profiles.svelte';
  import Proxies from './pages/Proxies.svelte';
  import Settings from './pages/Settings.svelte';
  import Whitelist from './pages/Whitelist.svelte';

  const pages = [
    { id: 'dashboard', icon: 'grid', page: Dashboard },
    { id: 'proxies', icon: 'globe', page: Proxies },
    { id: 'profiles', icon: 'tray', page: Profiles },
    { id: 'whitelist', icon: 'shield', page: Whitelist },
    { id: 'settings', icon: 'gear', page: Settings },
  ];
  const Page = $derived(pages.find((page) => page.id === app.page).page);
  let content;

  $effect(() => {
    app.page;
    content?.scrollTo(0, 0);
  });
</script>

<nav class="sidebar glass" aria-label="po0-clash">
  <div class="brand">po0-clash</div>
  {#each pages as page (page.id)}
    <button
      type="button"
      class:active={app.page === page.id}
      aria-current={app.page === page.id ? 'page' : undefined}
      onclick={() => (app.page = page.id)}
    >
      <Icon name={page.icon} />
      <span>{t(`page.${page.id}`)}</span>
    </button>
  {/each}
</nav>

<main bind:this={content}>
  <Page />
</main>

{#if app.notice}
  <div class="notice glass" class:error={app.notice.error} role="status">
    <span>{app.notice.text}</span>
    <button type="button" class="icon-button" aria-label={t('common.dismiss')} onclick={() => (app.notice = null)}
      ><Icon name="close" /></button
    >
  </div>
{/if}
