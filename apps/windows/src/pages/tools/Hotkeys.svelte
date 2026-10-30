<script>
  import { invoke } from '@tauri-apps/api/core';
  import { t } from '../../lib/i18n.js';
  import { settings, updateSettings } from '../../lib/settings.svelte.js';

  const actions = ['connect', 'showWindow', 'mode', 'systemProxy', 'tun'];
  const names = { control: 'Ctrl', alt: 'Alt', shift: 'Shift', meta: 'Win' };
  const keyNames = {
    Space: 'Space',
    Enter: 'Enter',
    Escape: 'Esc',
    Backspace: 'Backspace',
    ArrowLeft: '←',
    ArrowRight: '→',
    ArrowUp: '↑',
    ArrowDown: '↓',
    Minus: '-',
    Equal: '=',
    BracketLeft: '[',
    BracketRight: ']',
    Backslash: '\\',
    Semicolon: ';',
    Quote: "'",
    Comma: ',',
    Period: '.',
    Slash: '/',
    Backquote: '`',
  };

  let recording = $state(null);
  let needsModifier = $state(false);
  let failed = $state([]);

  const hotkeys = $derived(settings.value.hotkeys ?? []);
  const current = (action) => hotkeys.find((h) => h.action === action);
  const keyName = (code) => keyNames[code] ?? code.replace(/^(Key|Digit)/, '').replace(/^Numpad/, 'Num ');
  const display = (h) => [...['control', 'alt', 'shift', 'meta'].filter((m) => h.modifiers.includes(m)).map((m) => names[m]), keyName(h.key)].join(' + ');

  // Synthesized input, such as from remote desktop tools, can arrive without a scan code and so without `code`.
  const codeOf = (key) => (/^[a-z]$/i.test(key) ? `Key${key.toUpperCase()}` : /^\d$/.test(key) ? `Digit${key}` : '');
  const loadFailures = async () => (failed = await invoke('hotkey_failures'));

  $effect(() => {
    loadFailures();
    return () => recording && invoke('pause_hotkeys', { paused: false });
  });

  async function start(action) {
    needsModifier = false;
    recording = action;
    await invoke('pause_hotkeys', { paused: true });
  }

  async function stop() {
    recording = null;
    await invoke('pause_hotkeys', { paused: false });
    await loadFailures();
  }

  async function save(action, hotkey) {
    const others = hotkeys.filter(
      (h) => h.action !== action && !(hotkey && h.key === hotkey.key && h.modifiers.join() === hotkey.modifiers.join()),
    );
    await updateSettings({ hotkeys: hotkey ? [...others, hotkey] : others });
  }

  async function keydown(event) {
    if (!recording) return;
    event.preventDefault();
    event.stopPropagation();
    const code = event.code || codeOf(event.key);
    if (!code || ['Control', 'Alt', 'Shift', 'Meta', 'OS'].some((m) => code.startsWith(m))) return;
    const modifiers = ['control', 'alt', 'shift', 'meta'].filter((m) => event[`${m === 'control' ? 'ctrl' : m}Key`]);
    const action = recording;
    if (!modifiers.length && code === 'Escape') return stop();
    if (!modifiers.length && (code === 'Backspace' || code === 'Delete')) {
      await save(action, null);
      return stop();
    }
    const functionKey = /^F\d+$/.test(code);
    if (!functionKey && !modifiers.some((m) => m !== 'shift')) {
      needsModifier = true;
      return;
    }
    await save(action, { action, key: code, modifiers });
    await stop();
  }
</script>

<svelte:window onkeydowncapture={keydown} />

<div class="list">
  {#each actions as action (action)}
    {@const hotkey = current(action)}
    <div class="row tall">
      <div class="label">
        <span>{t(`hotkey.${action}`)}</span>
        {#if recording === action && needsModifier}
          <span class="sub">{t('hotkey.needsModifier')}</span>
        {:else if failed.includes(action)}
          <span class="sub bad">{t('hotkey.failed')}</span>
        {/if}
      </div>
      <button
        type="button"
        class="pill shortcut"
        class:recording={recording === action}
        onclick={() => (recording === action ? stop() : start(action))}
      >
        {#if recording === action}{t('hotkey.recording')}{:else if hotkey}<span class="mono">{display(hotkey)}</span
          >{:else}<span class="sub">{t('hotkey.notSet')}</span>{/if}
      </button>
    </div>
  {/each}
</div>
<p class="note">{t('hotkey.hint')}</p>
