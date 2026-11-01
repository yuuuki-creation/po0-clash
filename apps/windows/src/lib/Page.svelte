<script>
  import { app } from './core.svelte.js';
  import Icon from './Icon.svelte';

  let { title, crumbs = [], capped = true, scroll = true, actions, children } = $props();
</script>

<div class="page-head" class:capped>
  <h1 class="page-title">
    {#each crumbs as crumb, i (i)}
      <button type="button" class="crumb clip" onclick={crumb.onclick}>{crumb.label}</button>
      <Icon name="chevron" class="crumb-sep" />
    {/each}
    <span class="clip">{title}</span>
  </h1>
  {#if actions}<div class="actions">{@render actions()}</div>{/if}
</div>

<div class="content page {app.nav}" class:capped class:scroll>
  {@render children()}
</div>
