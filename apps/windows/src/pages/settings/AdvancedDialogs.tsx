// Dialog layout follows Clash Verge Rev (GPL-3.0): src/components/setting/mods/backup-viewer.tsx and backup-webdav-dialog.tsx.
import { RefreshRounded } from '@mui/icons-material';
import { Box, Button, ButtonGroup, CircularProgress, IconButton, Link, List, ListItemButton, ListItemText, Stack, Typography } from '@mui/material';
import { useEffect, useState } from 'react';
import { useSnapshot } from 'valtio';
import { BaseDialog, Switch } from '../../base';
import { t } from '../../lib/i18n.js';
import { act, app, isRunning, notify } from '../../state/core';
import { loadSettings, updateSettings } from '../../state/settings';
import { Choice, DialogRow, DialogSection, openUrl, PlainField, run, saveSettings, useAppSettings, VirtualRows } from './common';
import type { DialogProps } from './EngineDialogs';

const closeProps = (onClose: () => void) => ({ open: true, disableOk: true, cancelBtn: t('common.close'), onClose, onCancel: onClose });

const emptyDav = { url: '', user: '', password: '', fileName: '' };

export function BackupDialog({ onClose }: DialogProps) {
  const s = useAppSettings();
  const busyKeys = useSnapshot(app).busy;
  const [scope, setScope] = useState('all');
  const [confirming, setConfirming] = useState<'file' | 'dav' | null>(null);
  const [dav, setDav] = useState({ ...emptyDav, ...s.webdav });

  useEffect(() => {
    if (s.webdav) setDav({ ...s.webdav });
  }, [JSON.stringify(s.webdav)]);

  const davFilled = /^https?:\/\//.test(dav.url.trim());
  const davChanged = JSON.stringify(dav) !== JSON.stringify(s.webdav ?? emptyDav);
  const busy = Object.keys(busyKeys).some((key) => /^(backup|restore|dav):/.test(key));
  const davReady = !!s.webdav && !davChanged && !busy;

  async function backupToFile() {
    const path = await act('backup:file', 'backup_to_file');
    if (path) notify(t('backup.saved', { path }), '', 'success');
  }

  async function restore() {
    const source = confirming;
    setConfirming(null);
    const ok =
      source === 'file'
        ? await act('restore:file', 'restore_from_file', { scopeName: scope })
        : await run('restore:dav', 'restore_from_webdav', { scopeName: scope });
    if (!ok) return;
    await loadSettings();
    notify(t('backup.restored'), '', 'success');
  }

  async function checkDav() {
    if (await run('dav:check', 'check_webdav', { dav })) notify(t('backup.davOk'), '', 'success');
  }

  async function backupToDav() {
    if (await run('backup:dav', 'backup_to_webdav')) notify(t('backup.davSaved'), '', 'success');
  }

  const field = (key: keyof typeof emptyDav, label: string, extra: Record<string, unknown> = {}) => (
    <DialogRow label={label}>
      <PlainField sx={{ width: 300 }} value={dav[key]} onChange={(event) => setDav({ ...dav, [key]: event.target.value })} {...extra} />
    </DialogRow>
  );

  return (
    <BaseDialog title={t('tools.backup')} contentSx={{ width: 520 }} {...closeProps(onClose)}>
      <DialogSection title={t('backup.local')} />
      <List disablePadding>
        <DialogRow label={t('backup.toFile')}>
          <Button variant="outlined" size="small" disabled={busy} onClick={backupToFile}>
            {t('backup.backup')}
          </Button>
        </DialogRow>
        <DialogRow label={t('backup.fromFile')}>
          <Button variant="outlined" size="small" disabled={busy} onClick={() => setConfirming('file')}>
            {t('backup.restore')}
          </Button>
        </DialogRow>
      </List>

      <DialogSection title={t('backup.restoring')} />
      <List disablePadding>
        <DialogRow label={t('backup.scope')}>
          <ButtonGroup size="small" sx={{ my: '4px' }}>
            {['all', 'profiles'].map((value) => (
              <Button key={value} variant={value === scope ? 'contained' : 'outlined'} onClick={() => setScope(value)}>
                {t(`backup.scope.${value}`)}
              </Button>
            ))}
          </ButtonGroup>
        </DialogRow>
        <DialogRow label={t('backup.strategy')}>
          <Choice
            width={150}
            value={s.restoreStrategy}
            options={['compatible', 'override'].map((value) => ({ value, label: t(`backup.strategy.${value}`) }))}
            onChange={(restoreStrategy) => updateSettings({ restoreStrategy })}
          />
        </DialogRow>
      </List>

      <DialogSection title="WebDAV" />
      <List disablePadding>
        {field('url', t('backup.davUrl'), { placeholder: 'https://dav.example.com/' })}
        {field('user', t('backup.davUser'))}
        {field('password', t('backup.davPassword'), { type: 'password' })}
        {field('fileName', t('backup.davFile'), { placeholder: 'backup.zip' })}
      </List>
      <Stack direction="row" spacing={1} sx={{ justifyContent: 'flex-end', py: 1, px: '2px' }}>
        <Button variant="outlined" size="small" disabled={!davFilled || busy} loading={!!busyKeys['dav:check']} onClick={checkDav}>
          {t('backup.davCheck')}
        </Button>
        <Button
          variant="contained"
          size="small"
          disabled={!davFilled || !davChanged}
          onClick={() => updateSettings({ webdav: { ...dav, url: dav.url.trim() } })}
        >
          {t('backup.davSave')}
        </Button>
      </Stack>
      <List disablePadding>
        <DialogRow label={t('backup.toDav')}>
          <Button variant="outlined" size="small" disabled={!davReady} loading={!!busyKeys['backup:dav']} onClick={backupToDav}>
            {t('backup.backup')}
          </Button>
        </DialogRow>
        <DialogRow label={t('backup.fromDav')}>
          <Button variant="outlined" size="small" disabled={!davReady} onClick={() => setConfirming('dav')}>
            {t('backup.restore')}
          </Button>
        </DialogRow>
      </List>

      {confirming && (
        <BaseDialog
          open
          title={t('backup.confirm')}
          contentSx={{ width: 400 }}
          okBtn={t('backup.restore')}
          onClose={() => setConfirming(null)}
          onCancel={() => setConfirming(null)}
          onOk={restore}
        >
          <Typography variant="body2">
            {t(`backup.confirm.${scope}`)} {t(`backup.strategy.${s.restoreStrategy}Hint`)}
          </Typography>
        </BaseDialog>
      )}
    </BaseDialog>
  );
}

export function LoopbackDialog({ onClose }: DialogProps) {
  const { busy } = useSnapshot(app);
  const [apps, setApps] = useState<any[] | null>(null);
  const [query, setQuery] = useState('');

  const load = () => act('loopback:load', 'loopback_apps').then((list) => list && setApps(list));
  useEffect(() => {
    load();
  }, []);

  const needle = query.trim().toLowerCase();
  const shown = (apps ?? []).filter((a) => !needle || a.displayName.toLowerCase().includes(needle) || a.name.toLowerCase().includes(needle));
  const exempted = (apps ?? []).filter((a) => a.exempt).length;

  async function apply(exempt: (item: any) => boolean) {
    const sids = (apps ?? []).filter(exempt).map((a) => a.sid);
    if (await run('loopback', 'set_loopback', { sids })) await load();
  }

  return (
    <BaseDialog title={t('tools.loopback')} contentSx={{ width: 520 }} {...closeProps(onClose)}>
      <Stack direction="row" spacing={1} sx={{ alignItems: 'center', pt: 0.5, pb: 1 }}>
        <PlainField sx={{ flex: 1 }} placeholder={t('loopback.search')} value={query} onChange={(event) => setQuery(event.target.value)} />
        <Button variant="outlined" size="small" disabled={!apps?.length || !!busy.loopback} onClick={() => apply(() => true)}>
          {t('loopback.all')}
        </Button>
        <Button variant="outlined" size="small" disabled={!exempted || !!busy.loopback} onClick={() => apply(() => false)}>
          {t('loopback.none')}
        </Button>
        <IconButton size="small" color="inherit" title={t('loopback.refresh')} disabled={!!busy['loopback:load']} onClick={load}>
          {busy['loopback:load'] ? <CircularProgress size={16} color="inherit" /> : <RefreshRounded fontSize="inherit" />}
        </IconButton>
      </Stack>
      {apps && !shown.length ? (
        <Typography variant="body2" color="text.secondary" sx={{ textAlign: 'center', height: 360, pt: 4 }}>
          {t(apps.length ? 'loopback.noMatch' : 'loopback.empty')}
        </Typography>
      ) : (
        <VirtualRows items={shown} rowHeight={40} height={360} itemKey={(item) => item.sid}>
          {(item) => (
            <Box sx={{ display: 'flex', alignItems: 'center', height: 40, px: '2px', pr: 1.5 }}>
              <Typography noWrap title={item.name} sx={{ flex: 1, fontSize: 14 }}>
                {item.displayName}
              </Typography>
              <Switch
                edge="end"
                checked={item.exempt}
                disabled={!!busy.loopback}
                onChange={(_, on) => apply((a) => (a.sid === item.sid ? on : a.exempt))}
              />
            </Box>
          )}
        </VirtualRows>
      )}
    </BaseDialog>
  );
}

const credits = [
  ['Clash Verge Rev', 'https://github.com/clash-verge-rev/clash-verge-rev', 'settings.creditVerge'],
  ['FlClash', 'https://github.com/chen08209/FlClash', 'settings.creditFlClash'],
  ['mihomo', 'https://github.com/MetaCubeX/mihomo', 'settings.creditMihomo'],
] as const;

export function LicensesDialog({ onClose }: DialogProps) {
  const [licenses, setLicenses] = useState<any[]>([]);
  const [query, setQuery] = useState('');

  useEffect(() => {
    act('licenses', 'licenses').then((list) => list && setLicenses(list));
  }, []);

  const needle = query.trim().toLowerCase();
  const shown = licenses.filter((l) => !needle || `${l.name} ${l.license}`.toLowerCase().includes(needle));

  return (
    <BaseDialog title={t('licenses.title')} contentSx={{ width: 560 }} {...closeProps(onClose)}>
      <DialogSection title={t('settings.acknowledgements')} />
      <Box sx={{ px: '2px', pb: 1 }}>
        {credits.map(([name, url, key]) => (
          <Typography key={name} variant="body2" sx={{ py: 0.25 }}>
            <Link component="button" type="button" underline="hover" sx={{ fontWeight: 700, verticalAlign: 'baseline' }} title={url} onClick={() => openUrl(url)}>
              {name}
            </Link>
            {' (GPL-3.0) — '}
            {t(key)}
          </Typography>
        ))}
      </Box>
      <PlainField fullWidth sx={{ my: 1 }} placeholder={t('licenses.search')} value={query} onChange={(event) => setQuery(event.target.value)} />
      {licenses.length > 0 && !shown.length ? (
        <Typography variant="body2" color="text.secondary" sx={{ textAlign: 'center', height: 280, pt: 4 }}>
          {t('licenses.noMatch')}
        </Typography>
      ) : (
        <VirtualRows items={shown} rowHeight={36} height={280} itemKey={(item) => `${item.name}@${item.version}`}>
          {(item) => (
            <ListItemButton dense title={item.url} sx={{ height: 36, px: 1, gap: 1.5, borderRadius: 1 }} onClick={() => openUrl(item.url)}>
              <ListItemText primary={item.name} slotProps={{ primary: { noWrap: true, sx: { fontSize: 14 } } }} />
              <Typography variant="body2" color="text.secondary" noWrap sx={{ flexShrink: 0 }}>
                {item.version}
              </Typography>
              <Typography variant="body2" color="text.secondary" noWrap sx={{ flexShrink: 0, maxWidth: 190 }}>
                {item.license}
              </Typography>
            </ListItemButton>
          )}
        </VirtualRows>
      )}
    </BaseDialog>
  );
}

export function DeveloperDialog({ onClose }: DialogProps) {
  const s = useAppSettings();
  const { busy, status } = useSnapshot(app);
  const [confirming, setConfirming] = useState<'crash' | 'clear' | null>(null);
  const running = isRunning(status);

  async function prune() {
    const removed = await act('dev:prune', 'prune_cache');
    if (removed !== undefined) notify(t('dev.pruned', { count: removed }), '', 'success');
  }

  async function addLogs() {
    if (await run('dev:logs', 'add_test_logs')) notify(t('dev.logsAdded'), '', 'success');
  }

  async function confirm() {
    const what = confirming;
    setConfirming(null);
    if (what === 'crash') await run('dev:crash', 'crash_engine');
    else await run('dev:clear', 'clear_data');
  }

  const rows = [
    { label: t('dev.message'), button: t('dev.show'), run: () => notify(t('dev.sample'), '', 'info') },
    { label: t('dev.logs'), tip: s.captureLogs ? '' : t('dev.logsOff'), button: t('dev.add'), disabled: !s.captureLogs || !!busy['dev:logs'], run: addLogs },
    { label: t('dev.crash'), tip: running ? '' : t('dev.crashOff'), button: t('dev.crashButton'), disabled: !running || !!busy['dev:crash'], run: () => setConfirming('crash') },
    { label: t('dev.clear'), button: t('dev.clearButton'), disabled: !!busy['dev:clear'], run: () => setConfirming('clear') },
    { label: t('dev.prune'), button: t('dev.pruneButton'), disabled: !!busy['dev:prune'], run: prune },
  ];

  return (
    <BaseDialog title={t('tools.developer')} contentSx={{ width: 450 }} {...closeProps(onClose)}>
      <List>
        <DialogRow label={t('dev.mode')}>
          <Switch
            edge="end"
            checked={!!s.developerMode}
            onChange={async (_, on) => {
              if ((await saveSettings({ developerMode: on })) && !on) onClose();
            }}
          />
        </DialogRow>
        {rows.map((row) => (
          <DialogRow key={row.label} label={row.label}>
            <span title={row.tip}>
              <Button variant="outlined" size="small" disabled={row.disabled} onClick={row.run}>
                {row.button}
              </Button>
            </span>
          </DialogRow>
        ))}
      </List>
      {confirming && (
        <BaseDialog
          open
          title={t(confirming === 'crash' ? 'dev.confirmCrash' : 'dev.confirmClear')}
          contentSx={{ width: 400 }}
          okBtn={t(confirming === 'crash' ? 'dev.crashConfirm' : 'dev.clearConfirm')}
          onClose={() => setConfirming(null)}
          onCancel={() => setConfirming(null)}
          onOk={confirm}
        >
          <Typography variant="body2">{t(confirming === 'crash' ? 'dev.confirmCrashHint' : 'dev.confirmClearHint')}</Typography>
        </BaseDialog>
      )}
    </BaseDialog>
  );
}
