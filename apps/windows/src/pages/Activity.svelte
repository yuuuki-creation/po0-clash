<script module>
  let tab = $state('requests');
</script>

<script>
  import { t } from '../lib/i18n.js';
  import EmptyState from '../lib/EmptyState.svelte';
  import Page from '../lib/Page.svelte';

  const tabs = ['requests', 'connections', 'logs'];
</script>

<Page title={t('page.activity')} fill>
  {#snippet actions()}
    <div class="group glass segments" role="radiogroup" aria-label={t('page.activity')}>
      {#each tabs as id (id)}
        <button type="button" role="radio" aria-checked={tab === id} class:selected={tab === id} onclick={() => (tab = id)}
          >{t(`activity.${id}`)}</button
        >
      {/each}
    </div>
  {/snippet}

  <EmptyState icon="hourglass" title={t(`activity.${tab}`)} detail={t('tools.comingSoon')} />
</Page>
