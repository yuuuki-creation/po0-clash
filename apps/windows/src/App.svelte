<script>
  import { MediaQuery } from 'svelte/reactivity';
  import { app } from './lib/core.svelte.js';
  import { t } from './lib/i18n.js';
  import Dialog from './lib/Dialog.svelte';
  import Icon from './lib/Icon.svelte';
  import { navigate } from './lib/motion.svelte.js';
  import { settings } from './lib/settings.svelte.js';
  import WindowControls from './lib/WindowControls.svelte';
  import Activity from './pages/Activity.svelte';
  import Dashboard from './pages/Dashboard.svelte';
  import Profiles from './pages/Profiles.svelte';
  import Proxies from './pages/Proxies.svelte';
  import Tools from './pages/Tools.svelte';
  import Whitelist from './pages/Whitelist.svelte';

  const pages = [
    { id: 'dashboard', icon: 'home', page: Dashboard },
    { id: 'proxies', icon: 'proxies', page: Proxies },
    { id: 'profiles', icon: 'profiles', page: Profiles },
    { id: 'whitelist', icon: 'whitelist', page: Whitelist },
    { id: 'activity', icon: 'activity', page: Activity },
    { id: 'tools', icon: 'tools', page: Tools },
  ];
  const Page = $derived(pages.find((page) => page.id === app.page).page);
  const index = $derived(pages.findIndex((page) => page.id === app.page));

  const narrow = new MediaQuery('(max-width: 1007px)');
  const rail = $derived(narrow.current || !settings.value.showNavLabels);

  $effect(() => {
    rail;
    app.pane = false;
  });

  function open(id) {
    if (rail) app.pane = false;
    if (app.page !== id || app.tool) navigate(id);
  }
</script>

<div class="shell" class:rail class:pane-toggled={app.pane} class:no-page-anim={!settings.value.pageAnimation}>
  <header class="titlebar" data-tauri-drag-region>
    <button
      type="button"
      class="icon-btn pane-btn"
      title={t('window.sidebar')}
      aria-label={t('window.sidebar')}
      aria-expanded={rail ? app.pane : !app.pane}
      onclick={() => (app.pane = !app.pane)}><Icon name="pane" /></button
    >
    <svg class="app-icon" viewBox="0 0 1024 1024" aria-hidden="true" data-tauri-drag-region>
      <rect class="bg" width="1024" height="1024" rx="200"></rect>
      <path
        class="fg"
        transform="translate(512 512) scale(1.15) translate(-484 -512)"
        d="M304 800C273 800 248 775 248 744V280C248 249 273 224 304 224H496C620 224 720 324 720 448C720 572 620 672 496 672H360V744C360 775 335 800 304 800Z M562.28 357.72A112 112 0 0 0 405.72 514.28L562.28 357.72Z M586.28 381.72A112 112 0 0 1 429.72 538.28L586.28 381.72Z"
      ></path>
    </svg>
    <span data-tauri-drag-region>po0-clash</span>
    <WindowControls />
  </header>
  <div class="body">
    <div class="nav-slot">
      <nav class="nav" aria-label="po0-clash" style:--i={index}>
        <span class="nav-pill"></span>
        {#each pages as page (page.id)}
          <button
            type="button"
            class="nav-item"
            class:act={app.page === page.id}
            title={t(`page.${page.id}`)}
            aria-label={t(`page.${page.id}`)}
            aria-current={app.page === page.id ? 'page' : undefined}
            onclick={() => open(page.id)}
          >
            <Icon name={page.icon} />
            <span>{t(`page.${page.id}`)}</span>
          </button>
        {/each}
      </nav>
    </div>
    {#if rail && app.pane}
      <button type="button" class="nav-scrim" tabindex="-1" aria-label={t('window.sidebar')} onclick={() => (app.pane = false)}></button>
    {/if}
    <main class="main">
      <Page />
    </main>
  </div>
</div>

{#if app.notice}
  <Dialog title={app.notice.title} onclose={() => (app.notice = null)}>
    {#if app.notice.detail}<p class="selectable">{app.notice.detail}</p>{/if}
  </Dialog>
{/if}
