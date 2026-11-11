// Dialog layout follows Clash Verge Rev (GPL-3.0): src/components/setting/mods/{theme,hotkey}-viewer.tsx and hotkey-input.tsx.
import { AddRounded, CheckRounded, DeleteRounded, InfoRounded } from '@mui/icons-material';
import { alpha, Box, IconButton, List, Slider, Tooltip, Typography } from '@mui/material';
import { useEffect, useRef, useState } from 'react';
import { BaseDialog, Switch } from '../../base';
import { invoke, os } from '../../ipc';
import { t } from '../../lib/i18n.js';
import { updateSettings } from '../../state/settings';
import { DEFAULT_ACCENT, presets, toArgb, toHex } from '../../state/theme';
import { DialogRow, useAppSettings } from './common';
import type { DialogProps } from './EngineDialogs';

const presetHex = presets.map(([, hex]) => hex);

const closeProps = (onClose: () => void) => ({ open: true, disableOk: true, cancelBtn: t('common.close'), onClose, onCancel: onClose });

export function ThemeDialog({ onClose }: DialogProps) {
  const s = useAppSettings();
  const picker = useRef<HTMLInputElement>(null);
  const [lastScale, setLastScale] = useState<number>(s.textScale ?? 110);
  const [sliding, setSliding] = useState<number | null>(null);

  const current = toHex(s.themeColor);
  const custom = (s.themeColors as number[]).filter((argb) => argb !== DEFAULT_ACCENT && !presetHex.includes(toHex(argb))).map(toHex);
  const isOn = (name: string, hex: string) => (name === 'blue' ? s.themeColor === DEFAULT_ACCENT || current === hex : current === hex);
  const pick = (name: string, hex: string) => updateSettings({ themeColor: name === 'blue' ? DEFAULT_ACCENT : toArgb(hex) });

  function addColor(hex: string) {
    const argb = toArgb(hex);
    updateSettings({ themeColor: argb, themeColors: [...s.themeColors.filter((c: number) => c !== argb), argb] });
  }

  function removeColor(hex: string) {
    const argb = toArgb(hex);
    updateSettings({
      themeColors: s.themeColors.filter((c: number) => c !== argb),
      themeColor: s.themeColor === argb ? DEFAULT_ACCENT : s.themeColor,
    });
  }

  function setScaled(on: boolean) {
    if (!on) setLastScale(s.textScale ?? lastScale);
    updateSettings({ textScale: on ? lastScale : null });
  }

  const swatch = (hex: string, on: boolean, title: string, onClick: () => void, onContextMenu?: () => void) => (
    <Tooltip key={hex} title={title} placement="top">
      <Box
        component="button"
        type="button"
        aria-label={title}
        aria-pressed={on}
        onClick={onClick}
        onContextMenu={(event) => {
          event.preventDefault();
          onContextMenu?.();
        }}
        sx={{
          width: 24,
          height: 24,
          p: 0,
          border: 0,
          borderRadius: '18px',
          bgcolor: hex,
          color: '#fff',
          cursor: 'pointer',
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {on && <CheckRounded sx={{ fontSize: 16 }} />}
      </Box>
    </Tooltip>
  );

  return (
    <BaseDialog title={t('settings.theme')} contentSx={{ width: 450 }} {...closeProps(onClose)}>
      <List>
        <DialogRow label={t('ap.accent')}>
          <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1, maxWidth: 330, justifyContent: 'flex-end' }}>
            {presets.map(([name, hex]) => swatch(hex, isOn(name, hex), t(`color.${name}`), () => pick(name, hex)))}
            {custom.map((hex) =>
              swatch(
                hex,
                current === hex,
                t('color.custom', { hex }),
                () => updateSettings({ themeColor: toArgb(hex) }),
                () => removeColor(hex),
              ),
            )}
            <Tooltip title={t('ap.addColor')} placement="top">
              <IconButton size="small" sx={{ width: 24, height: 24, border: 1, borderColor: 'divider' }} onClick={() => picker.current?.click()}>
                <AddRounded sx={{ fontSize: 16 }} />
              </IconButton>
            </Tooltip>
            <input ref={picker} type="color" hidden value={current} onChange={(event) => addColor(event.target.value.toUpperCase())} />
          </Box>
        </DialogRow>
        <DialogRow label={t('ap.black')}>
          <Switch edge="end" checked={!!s.pureBlack} onChange={(_, pureBlack) => updateSettings({ pureBlack })} />
        </DialogRow>
        <DialogRow label={t('ap.scaled')}>
          <Switch edge="end" checked={s.textScale != null} onChange={(_, on) => setScaled(on)} />
        </DialogRow>
        <DialogRow label={t('ap.scale')}>
          <Slider
            size="small"
            sx={{ width: 200, mr: 2 }}
            min={80}
            max={150}
            step={5}
            disabled={s.textScale == null}
            value={sliding ?? s.textScale ?? lastScale}
            onChange={(_, value) => setSliding(value as number)}
            onChangeCommitted={(_, value) => {
              setSliding(null);
              updateSettings({ textScale: value as number });
            }}
          />
          <Typography variant="body2" color="text.secondary" sx={{ width: 44, textAlign: 'right' }}>
            {sliding ?? s.textScale ?? lastScale}%
          </Typography>
        </DialogRow>
      </List>
    </BaseDialog>
  );
}

const actions = ['connect', 'showWindow', 'mode', 'systemProxy', 'tun'];
const modifierOrder = ['control', 'alt', 'shift', 'meta'];
const modifierNames: Record<string, string> =
  os === 'macos' ? { control: '⌃', alt: '⌥', shift: '⇧', meta: '⌘' } : { control: 'Ctrl', alt: 'Alt', shift: 'Shift', meta: 'Win' };
const keyNames: Record<string, string> = {
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

const keyName = (code: string) => keyNames[code] ?? code.replace(/^(Key|Digit)/, '').replace(/^Numpad/, 'Num ');
const keysOf = (hotkey: any) => [...modifierOrder.filter((m) => hotkey.modifiers.includes(m)).map((m) => modifierNames[m]), keyName(hotkey.key)];

// Synthesized input, such as from remote desktop tools, can arrive without a scan code and so without `code`.
const codeOf = (key: string) => (/^[a-z]$/i.test(key) ? `Key${key.toUpperCase()}` : /^\d$/.test(key) ? `Digit${key}` : '');

const modifierFlags: Record<string, 'ctrlKey' | 'altKey' | 'shiftKey' | 'metaKey'> = {
  control: 'ctrlKey',
  alt: 'altKey',
  shift: 'shiftKey',
  meta: 'metaKey',
};

export function HotkeysDialog({ onClose }: DialogProps) {
  const s = useAppSettings();
  const hotkeys: any[] = s.hotkeys ?? [];
  const [recording, setRecording] = useState<string | null>(null);
  const [needsModifier, setNeedsModifier] = useState(false);
  const [failed, setFailed] = useState<string[]>([]);
  const live = useRef({ recording, hotkeys });
  live.current = { recording, hotkeys };

  const loadFailures = () =>
    invoke<string[]>('hotkey_failures').then(
      (list) => setFailed(list),
      () => {},
    );

  async function start(action: string) {
    setNeedsModifier(false);
    setRecording(action);
    live.current.recording = action;
    await invoke('pause_hotkeys', { paused: true }).catch(() => {});
  }

  // Recording ends before the save is awaited, so a row clicked meanwhile keeps its own recording.
  async function stop(action?: string, hotkey?: any | null) {
    setRecording(null);
    live.current.recording = null;
    if (action) await save(action, hotkey ?? null);
    if (live.current.recording) return;
    await invoke('pause_hotkeys', { paused: false }).catch(() => {});
    await loadFailures();
  }

  async function save(action: string, hotkey: any | null) {
    const others = live.current.hotkeys.filter(
      (h) => h.action !== action && !(hotkey && h.key === hotkey.key && h.modifiers.join() === hotkey.modifiers.join()),
    );
    await updateSettings({ hotkeys: hotkey ? [...others, hotkey] : others });
  }

  useEffect(() => {
    loadFailures();
    async function keydown(event: KeyboardEvent) {
      const action = live.current.recording;
      if (!action) return;
      event.preventDefault();
      event.stopPropagation();
      const code = event.code || codeOf(event.key);
      if (!code || ['Control', 'Alt', 'Shift', 'Meta', 'OS'].some((m) => code.startsWith(m))) return;
      const modifiers = modifierOrder.filter((m) => event[modifierFlags[m]]);
      if (!modifiers.length && code === 'Escape') return stop();
      if (!modifiers.length && (code === 'Backspace' || code === 'Delete')) return stop(action, null);
      if (!/^F\d+$/.test(code) && !modifiers.some((m) => m !== 'shift')) {
        setNeedsModifier(true);
        return;
      }
      await stop(action, { action, key: code, modifiers });
    }
    window.addEventListener('keydown', keydown, true);
    return () => {
      window.removeEventListener('keydown', keydown, true);
      if (live.current.recording) invoke('pause_hotkeys', { paused: false }).catch(() => {});
    };
  }, []);

  return (
    <BaseDialog
      title={
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
          <Typography variant="h6">{t('tools.hotkeys')}</Typography>
          <Tooltip title={t('hotkey.hint')} placement="top">
            <InfoRounded fontSize="small" sx={{ opacity: 0.6 }} />
          </Tooltip>
        </Box>
      }
      contentSx={{ width: 450 }}
      {...closeProps(onClose)}
    >
      <List>
        {actions.map((action) => {
          const hotkey = hotkeys.find((h) => h.action === action);
          const active = recording === action;
          const problem =
            active && needsModifier
              ? t(os === 'macos' ? 'settings.hotkeyNeedsModifierMac' : 'hotkey.needsModifier')
              : failed.includes(action)
                ? t('hotkey.failed')
                : '';
          return (
            <DialogRow
              key={action}
              label={
                <>
                  {t(`hotkey.${action}`)}
                  {problem && (
                    <Typography component="span" sx={{ display: 'block', fontSize: 12, color: 'error.main' }}>
                      {problem}
                    </Typography>
                  )}
                </>
              }
            >
              <Box
                component="button"
                type="button"
                onClick={() => (active ? stop() : start(action))}
                sx={(theme) => ({
                  width: 200,
                  minHeight: 36,
                  px: '4px',
                  display: 'flex',
                  alignItems: 'center',
                  flexWrap: 'wrap',
                  font: 'inherit',
                  fontSize: 14,
                  color: problem && !active ? 'error.main' : 'text.primary',
                  bgcolor: 'transparent',
                  cursor: 'pointer',
                  border: '1px solid',
                  borderRadius: '4px',
                  borderColor: active
                    ? alpha(theme.palette.primary.main, 0.75)
                    : problem
                      ? theme.palette.error.main
                      : alpha(theme.palette.text.secondary, 0.15),
                })}
              >
                {active ? (
                  <Box component="span" sx={{ px: '5px', color: 'primary.main' }}>
                    {t('hotkey.recording')}
                  </Box>
                ) : hotkey ? (
                  keysOf(hotkey).map((key, index) => (
                    <Box key={key} component="span" sx={{ display: 'flex', alignItems: 'center' }}>
                      {index > 0 && <Box component="span" sx={{ px: '2px' }}>+</Box>}
                      <Box component="span" sx={{ border: '1px solid', borderColor: 'divider', borderRadius: '2px', p: '1px 5px', my: '2px' }}>
                        {key}
                      </Box>
                    </Box>
                  ))
                ) : (
                  <Box component="span" sx={{ px: '5px', color: 'text.secondary' }}>
                    {t('hotkey.notSet')}
                  </Box>
                )}
              </Box>
              <IconButton size="small" color="inherit" title={t('script.delete')} disabled={!hotkey} onClick={() => save(action, null)}>
                <DeleteRounded fontSize="inherit" />
              </IconButton>
            </DialogRow>
          );
        })}
      </List>
    </BaseDialog>
  );
}
