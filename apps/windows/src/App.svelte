<script>
  import { app } from './lib/core.svelte.js';
  import { t } from './lib/i18n.js';
  import Dialog from './lib/Dialog.svelte';
  import Icon from './lib/Icon.svelte';
  import Activity from './pages/Activity.svelte';
  import Dashboard from './pages/Dashboard.svelte';
  import Profiles from './pages/Profiles.svelte';
  import Proxies from './pages/Proxies.svelte';
  import Tools from './pages/Tools.svelte';
  import Whitelist from './pages/Whitelist.svelte';

  const pages = [
    { id: 'dashboard', icon: 'grid', page: Dashboard },
    { id: 'proxies', icon: 'globe', page: Proxies },
    { id: 'profiles', icon: 'stack', page: Profiles },
    { id: 'whitelist', icon: 'shield', page: Whitelist },
    { id: 'activity', icon: 'activity', page: Activity },
    { id: 'tools', icon: 'tools', page: Tools },
  ];
  const Page = $derived(pages.find((page) => page.id === app.page).page);
  let content;

  $effect(() => {
    app.page;
    app.tool;
    content?.scrollTo(0, 0);
  });

  function open(id) {
    app.page = id;
    app.tool = null;
  }
</script>

<nav class="sidebar glass" class:hidden={!app.sidebar} aria-label="po0-clash" data-tauri-drag-region>
  <div class="brand" data-tauri-drag-region>po0-clash</div>
  {#each pages as page (page.id)}
    <button
      type="button"
      class:active={app.page === page.id}
      aria-current={app.page === page.id ? 'page' : undefined}
      onclick={() => open(page.id)}
    >
      <Icon name={page.icon} />
      <span>{t(`page.${page.id}`)}</span>
    </button>
  {/each}
</nav>

<main bind:this={content} class:wide={!app.sidebar}>
  <Page />
</main>

{#if app.notice}
  <Dialog title={app.notice} onclose={() => (app.notice = null)} />
{/if}
