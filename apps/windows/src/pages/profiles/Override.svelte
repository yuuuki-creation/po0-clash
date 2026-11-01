<script>
  import { invoke } from '@tauri-apps/api/core';
  import { act, app, notify } from '../../lib/core.svelte.js';
  import { engine, fromLines, loadOptions, toLines } from '../../lib/engine.svelte.js';
  import { t } from '../../lib/i18n.js';
  import Dialog from '../../lib/Dialog.svelte';
  import Choice from '../../lib/form/Choice.svelte';
  import { navigate } from '../../lib/motion.svelte.js';
  import Page from '../../lib/Page.svelte';
  import ScriptEditor from '../../lib/ScriptEditor.svelte';
  import Segmented from '../../lib/Segmented.svelte';
  import Switch from '../../lib/Switch.svelte';
  import { loadScripts, scripts } from '../../lib/scripts.svelte.js';

  let { profile, onback } = $props();
  const id = $derived(profile.id);
  let saved = $state(null);
  let draft = $state(null);
  let editor = $state(null);
  let replacing = $state(false);

  const modes = ['standard', 'script', 'custom'];
  const globalRules = $derived(engine.options?.addedRules ?? []);
  const dirty = $derived(draft && JSON.stringify(draft) !== JSON.stringify(saved));
  const script = $derived(scripts.list.find((s) => s.id === draft?.scriptId));
  const crumbs = $derived([
    { label: t('page.profiles'), onclick: onback },
    { label: profile.title, onclick: onback },
  ]);

  $effect(() => {
    Promise.all([invoke('profile_override', { id }), loadOptions(), loadScripts()])
      .then(([overrides]) => {
        saved = overrides;
        draft = structuredClone(overrides);
      })
      .catch((e) => notify(e));
  });

  function toggleGlobal(rule, enabled) {
    const disabled = draft.disabledGlobalRules.filter((r) => r !== rule);
    draft.disabledGlobalRules = enabled ? disabled : [...disabled, rule];
  }

  async function save() {
    const overrides = $state.snapshot(draft);
    if ((await act('override:save', 'set_profile_override', { id, overrides })) === undefined) return;
    const fresh = await invoke('profile_override', { id });
    saved = fresh;
    draft = structuredClone(fresh);
    notify(t('override.saved'));
  }

  async function copyFromProfile() {
    replacing = false;
    const parts = await act('override:copy', 'profile_groups_and_rules', { id });
    if (!parts) return;
    draft.customGroups = parts.groups;
    draft.customRules = parts.rules;
  }
</script>

<Page title={t('override.title')} {crumbs}>
  {#snippet actions()}
    <button type="button" class="btn" disabled={!dirty} onclick={() => (draft = $state.snapshot(saved))}>{t('override.revert')}</button>
    <button type="button" class="btn primary" disabled={!dirty || app.busy['override:save']} onclick={save}>{t('common.save')}</button>
  {/snippet}

  {#if draft}
    <div class="group">
      <div class="row">
        <span class="grow">{t('override.mode')}</span>
        <Segmented
          label={t('override.mode')}
          value={draft.mode}
          options={modes.map((value) => ({ value, label: t(`override.${value}`) }))}
          onchange={(mode) => (draft.mode = mode)}
        />
      </div>
    </div>

    {#if draft.mode === 'standard'}
      <section>
        <h2 class="section-title">{t('override.addedRules')}</h2>
        <div class="group">
          <label class="row block">
            <textarea
              class="in code"
              rows="8"
              value={toLines(draft.addedRules)}
              aria-label={t('override.addedRules')}
              spellcheck="false"
              placeholder="DOMAIN-SUFFIX,example.com,DIRECT"
              onchange={(event) => (draft.addedRules = fromLines(event.target.value))}
            ></textarea>
          </label>
          <label class="row">
            <span class="grow">{t('override.matchTarget')}</span>
            <input
              class="in"
              value={draft.matchTarget ?? ''}
              placeholder={t('override.matchTargetPlaceholder')}
              spellcheck="false"
              onchange={(event) => (draft.matchTarget = event.target.value.trim() || null)}
            />
          </label>
        </div>
      </section>

      <section>
        <h2 class="section-title">{t('override.globalRules')}</h2>
        <div class="group">
          {#each globalRules as rule (rule)}
            <div class="row">
              <span class="grow clip mono" title={rule}>{rule}</span>
              <Switch
                label={rule}
                checked={!draft.disabledGlobalRules.includes(rule)}
                onchange={(enabled) => toggleGlobal(rule, enabled)}
              />
            </div>
          {:else}
            <button type="button" class="row link-row" onclick={() => navigate('tools', 'advanced', 'drill')}
              >{t('override.noGlobalRules')}</button
            >
          {/each}
        </div>
      </section>
    {:else if draft.mode === 'script'}
      <div class="group">
        <Choice
          label={t('override.script')}
          value={draft.scriptId ?? ''}
          options={[
            { value: '', label: t('override.noScript') },
            ...scripts.list.map((s) => ({ value: s.id, label: s.name })),
          ]}
          onchange={(id) => (draft.scriptId = id || null)}
        />
        {#if script}
          <button type="button" class="row link-row" onclick={() => (editor = { script })}>{t('script.editEllipsis')}</button>
        {/if}
        <button type="button" class="row link-row" onclick={() => (editor = { script: null })}>{t('script.newEllipsis')}</button>
      </div>
    {:else}
      <section>
        <h2 class="section-title with-action">
          <span>{t('override.customGroups')}</span>
          <button
            type="button"
            class="text-link"
            disabled={app.busy['override:copy']}
            onclick={() => (draft.customGroups.trim() || draft.customRules.length ? (replacing = true) : copyFromProfile())}
            >{t('override.copyFromProfile')}</button
          >
        </h2>
        <div class="group">
          <label class="row block">
            <textarea
              class="in code"
              rows="14"
              bind:value={draft.customGroups}
              aria-label={t('override.customGroups')}
              spellcheck="false"
              placeholder={'- name: Proxy\n  type: select\n  proxies: [DIRECT]'}
            ></textarea>
          </label>
        </div>
      </section>
      <section>
        <h2 class="section-title">{t('override.customRules')}</h2>
        <div class="group">
          <label class="row block">
            <textarea
              class="in code"
              rows="10"
              value={toLines(draft.customRules)}
              aria-label={t('override.customRules')}
              spellcheck="false"
              placeholder="DOMAIN-SUFFIX,example.com,Proxy"
              onchange={(event) => (draft.customRules = fromLines(event.target.value))}
            ></textarea>
          </label>
        </div>
      </section>
    {/if}
  {/if}
</Page>

{#if editor}
  <ScriptEditor script={editor.script} onclose={() => (editor = null)} onsaved={(s) => (draft.scriptId = s.id)} />
{/if}

{#if replacing}
  <Dialog title={t('override.confirmCopy')} onclose={() => (replacing = false)}>
    {#snippet actions()}
      <button type="button" class="btn primary" onclick={copyFromProfile}>{t('override.replace')}</button>
    {/snippet}
  </Dialog>
{/if}
