// Card contents follow Clash Verge Rev (GPL-3.0): src/components/setting/setting-{system,clash,verge-basic,verge-advanced}.tsx.
import { Button, ButtonGroup, Typography } from '@mui/material';
import { type ComponentType, useEffect, useRef, useState } from 'react';
import { useSnapshot } from 'valtio';
import { Switch } from '../../base';
import { invoke, os } from '../../ipc';
import { t } from '../../lib/i18n.js';
import { act, app, applyLanguage, isRunning, notify, setRouteMode } from '../../state/core';
import { patchOptions, updateSettings } from '../../state/settings';
import { checkUpdate, update } from '../../state/update';
import { BackupDialog, DeveloperDialog, LicensesDialog, LoopbackDialog } from './AdvancedDialogs';
import { HotkeysDialog, ThemeDialog } from './AppDialogs';
import { AppSwitchItem, Choice, OptionSwitchItem, run, saveSettings, SettingItem, SettingList, useAppSettings, useEngineOptions } from './common';
import { AddedRulesDialog, BypassDialog, type DialogProps, DnsDialog, MiscDialog, PortsDialog, TunDialog } from './EngineDialogs';
import { GeoDialog, ScriptsDialog } from './ResourceDialogs';

function useDialogs<K extends string>(dialogs: Record<K, ComponentType<DialogProps>>) {
  const [open, setOpen] = useState<K | null>(null);
  const Dialog = open ? (dialogs[open] as ComponentType<DialogProps>) : null;
  return [Dialog ? <Dialog onClose={() => setOpen(null)} /> : null, (name: K) => () => setOpen(name)] as const;
}

export function SystemCard() {
  const { status, busy } = useSnapshot(app);
  const ready = !!useEngineOptions();
  const [autostart, setAutostart] = useState(false);
  const [dialog, show] = useDialogs({ tun: TunDialog, bypass: BypassDialog });

  useEffect(() => {
    invoke<boolean>('autostart_enabled').then(setAutostart, () => {});
  }, []);

  async function toggleAutostart(enabled: boolean) {
    setAutostart(enabled);
    if (!(await run('autostart', 'set_autostart', { enabled }))) setAutostart(!enabled);
  }

  return (
    <SettingList title={t('settings.system')}>
      {dialog}
      <SettingItem label={t('home.route')}>
        <Choice
          width={140}
          value={status?.routeMode ?? 'systemProxy'}
          disabled={!status || !!busy.route}
          options={['systemProxy', 'tun'].map((value) => ({ value, label: t(`route.${value}`) }))}
          onChange={setRouteMode}
        />
      </SettingItem>
      <SettingItem label={t('settings.tun')} disabled={!ready} onClick={show('tun')} />
      <SettingItem label={t('settings.bypass')} disabled={!ready} onClick={show('bypass')} />
      <SettingItem label={t('tools.autostart')}>
        <Switch edge="end" checked={autostart} disabled={!!busy.autostart} onChange={(_, on) => toggleAutostart(on)} />
      </SettingItem>
      <AppSwitchItem label={t('app.silentLaunch')} name="silentLaunch" />
      <AppSwitchItem label={t('app.autoConnect')} name="autoConnect" />
    </SettingList>
  );
}

const logLevels = ['debug', 'info', 'warning', 'error', 'silent'];

export function ClashCard() {
  const { status, busy } = useSnapshot(app);
  const o = useEngineOptions();
  const [dialog, show] = useDialogs({
    ports: PortsDialog,
    misc: MiscDialog,
    dns: DnsDialog,
    geo: GeoDialog,
    rules: AddedRulesDialog,
    scripts: ScriptsDialog,
  });

  async function flushDns() {
    if (await run('flush', 'flush_dns_cache')) notify(t('opt.flushed'), '', 'success');
  }

  return (
    <SettingList title={t('settings.clash')}>
      {dialog}
      <OptionSwitchItem label={t('opt.allowLan')} name="allowLan" />
      <OptionSwitchItem label={t('opt.ipv6')} name="ipv6" />
      <OptionSwitchItem label={t('opt.unifiedDelay')} name="unifiedDelay" />
      <OptionSwitchItem label={t('opt.tcpConcurrent')} name="tcpConcurrent" />
      <OptionSwitchItem label={t('opt.externalController')} name="externalController" />
      <AppSwitchItem label={t('app.closeOnSwitch')} name="closeConnectionsOnSwitch" />
      <SettingItem label={t('opt.logLevel')}>
        <Choice
          width={110}
          value={o?.logLevel ?? 'warning'}
          disabled={!o}
          options={logLevels.map((value) => ({ value, label: value }))}
          onChange={(logLevel) => patchOptions({ logLevel })}
        />
      </SettingItem>
      <SettingItem label={t('opt.findProcess')}>
        <Choice
          width={110}
          value={o?.findProcessMode ?? 'strict'}
          disabled={!o}
          options={['off', 'strict', 'always'].map((value) => ({ value, label: t(`find.${value}`) }))}
          onChange={(findProcessMode) => patchOptions({ findProcessMode })}
        />
      </SettingItem>
      <SettingItem
        label={t('opt.ports')}
        disabled={!o}
        onClick={show('ports')}
        trailing={
          <Typography variant="body2" color="text.secondary">
            {o?.mixedPort}
          </Typography>
        }
      />
      <SettingItem label={t('settings.misc')} disabled={!o} onClick={show('misc')} />
      <SettingItem label={t('settings.dns')} disabled={!o} onClick={show('dns')} />
      <SettingItem label={t('opt.geo')} disabled={!o} onClick={show('geo')} />
      <SettingItem label={t('opt.addedRules')} disabled={!o} onClick={show('rules')} />
      <SettingItem label={t('script.library')} onClick={show('scripts')} />
      <SettingItem label={t('opt.flushDns')} disabled={!isRunning(status)} loading={!!busy.flush} onClick={flushDns} trailing={<span />} />
    </SettingList>
  );
}

const languages: [string, string][] = [
  ['system', ''],
  ['zh_CN', '简体中文'],
  ['en', 'English'],
  ['ja', '日本語'],
  ['ru', 'Русский'],
];

export function BasicCard() {
  const s = useAppSettings();
  const [dialog, show] = useDialogs({ theme: ThemeDialog, hotkeys: HotkeysDialog });

  async function setLanguage(value: string) {
    const language = value === 'system' ? null : value;
    if (language === s.language || !(await saveSettings({ language }))) return;
    applyLanguage((await invoke('app_info')).language);
  }

  return (
    <SettingList title={t('settings.basic')}>
      {dialog}
      <SettingItem label={t('tools.language')}>
        <Choice
          width={120}
          value={s?.language ?? 'system'}
          disabled={!s}
          options={languages.map(([value, label]) => ({ value, label: label || t('lang.system') }))}
          onChange={setLanguage}
        />
      </SettingItem>
      <SettingItem label={t('ap.mode')}>
        <ButtonGroup size="small" sx={{ my: '4px' }}>
          {['light', 'dark', 'system'].map((mode) => (
            <Button key={mode} variant={mode === s?.themeMode ? 'contained' : 'outlined'} onClick={() => updateSettings({ themeMode: mode })}>
              {t(`ap.${mode}`)}
            </Button>
          ))}
        </ButtonGroup>
      </SettingItem>
      <SettingItem label={t('settings.theme')} disabled={!s} onClick={show('theme')} />
      <AppSwitchItem label={t('app.showNavLabels')} name="showNavLabels" />
      <AppSwitchItem label={t('app.pageAnimation')} name="pageAnimation" />
      <AppSwitchItem label={t(os === 'macos' ? 'settings.keepRunning' : 'app.minimizeOnClose')} name="minimizeOnClose" />
      {os === 'macos' && <AppSwitchItem label={t('settings.traySpeed')} name="traySpeed" />}
      {os === 'macos' && <AppSwitchItem label={t('settings.onlyProxyTraffic')} name="onlyProxyTraffic" />}
      <AppSwitchItem label={t('app.captureLogs')} name="captureLogs" />
      <SettingItem label={t('tools.hotkeys')} disabled={!s} onClick={show('hotkeys')} />
    </SettingList>
  );
}

export function AdvancedCard() {
  const s = useAppSettings();
  const { version, busy } = useSnapshot(app);
  const { checking } = useSnapshot(update);
  const versionClicks = useRef(0);
  const [dialog, show] = useDialogs({ backup: BackupDialog, loopback: LoopbackDialog, licenses: LicensesDialog, developer: DeveloperDialog });

  async function exportDiagnostics() {
    const path = await act('diagnostics', 'export_diagnostics');
    if (path) notify(t('tools.exported', { path }), '', 'success');
  }

  // FlClash turns developer mode on after five clicks on the version.
  async function clickVersion() {
    if (++versionClicks.current !== 5 || s?.developerMode) return;
    if (!(await saveSettings({ developerMode: true }))) {
      versionClicks.current = 0;
      return;
    }
    notify(t('dev.enabled'), '', 'success');
  }

  return (
    <SettingList title={t('settings.advanced')}>
      {dialog}
      <SettingItem label={t('tools.backup')} disabled={!s} onClick={show('backup')} />
      {os === 'windows' && <SettingItem label={t('tools.loopback')} onClick={show('loopback')} />}
      <SettingItem label={t('tools.diagnostics')} loading={!!busy.diagnostics} onClick={exportDiagnostics} />
      <AppSwitchItem label={t('app.checkCertificate')} name="checkCertificate" />
      <AppSwitchItem label={t('settings.autoCheckUpdate')} name="autoCheckUpdate" />
      <SettingItem label={t('update.check')} loading={checking} onClick={() => checkUpdate(true)} />
      <SettingItem label={t('licenses.title')} onClick={show('licenses')} />
      {s?.developerMode && <SettingItem label={t('tools.developer')} onClick={show('developer')} />}
      <SettingItem
        label={t('tools.version')}
        onClick={clickVersion}
        trailing={
          <Typography variant="body2" color="text.secondary" className="selectable">
            {version}
          </Typography>
        }
      />
    </SettingList>
  );
}
