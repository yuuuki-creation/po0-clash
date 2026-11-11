// Dialog layout follows Clash Verge Rev (GPL-3.0): src/components/setting/mods/{tun,sysproxy,clash-port,misc,dns}-viewer.tsx.
import { Button, ButtonGroup, List } from '@mui/material';
import { useState } from 'react';
import { snapshot } from 'valtio';
import { BaseDialog, Switch } from '../../base';
import { os } from '../../ipc';
import { t } from '../../lib/i18n.js';
import { engine, fromLines, fromPairs, patchOptions, toLines, toPairs } from '../../state/settings';
import { Choice, DialogRow, DialogSection, LinesField, PlainField } from './common';

export interface DialogProps {
  onClose: () => void;
}

function useDraft<T>(pick: (options: any) => T) {
  const [draft, setDraft] = useState<T>(() => pick(JSON.parse(JSON.stringify(snapshot(engine.options)))));
  const set = (patch: Partial<T>) => setDraft((old) => ({ ...old, ...patch }));
  return [draft, set] as const;
}

function saveProps(onClose: () => void, patch: () => Record<string, unknown>) {
  return {
    open: true,
    okBtn: t('common.save'),
    onClose,
    onCancel: onClose,
    onOk: () => {
      patchOptions(patch());
      onClose();
    },
  };
}

function NumberField({ value, onChange, error }: { value: number; onChange: (value: number) => void; error?: boolean }) {
  const [text, setText] = useState(String(value));
  return (
    <PlainField
      type="number"
      error={error}
      sx={{ width: 135 }}
      value={text}
      onChange={(event) => {
        setText(event.target.value);
        onChange(Number(event.target.value) || 0);
      }}
    />
  );
}

const stacks = ['default', 'system', 'gvisor', 'mixed'];
const stackLabels: Record<string, string> = { system: 'System', gvisor: 'gVisor', mixed: 'Mixed' };

export function TunDialog({ onClose }: DialogProps) {
  const [draft, set] = useDraft((o) => ({
    stack: (o.tunStack ?? 'default') as string,
    route: toLines(o.tunRouteAddress),
    hijack: toLines(o.tunDnsHijack),
    systemDns: !!o.autoSetSystemDns,
  }));
  const patch = () => ({
    tunStack: draft.stack === 'default' ? null : draft.stack,
    tunRouteAddress: fromLines(draft.route),
    tunDnsHijack: fromLines(draft.hijack),
    ...(os === 'macos' ? { autoSetSystemDns: draft.systemDns } : {}),
  });
  return (
    <BaseDialog title={t('settings.tun')} contentSx={{ width: 450 }} {...saveProps(onClose, patch)}>
      <List>
        <DialogRow label={t('opt.tunStack')}>
          <ButtonGroup size="small" sx={{ my: '4px' }}>
            {stacks.map((stack) => (
              <Button key={stack} variant={stack === draft.stack ? 'contained' : 'outlined'} onClick={() => set({ stack })}>
                {stackLabels[stack] ?? t('stack.default')}
              </Button>
            ))}
          </ButtonGroup>
        </DialogRow>
        {os === 'macos' && (
          <DialogRow label={t('settings.autoSetSystemDns')}>
            <Switch edge="end" checked={draft.systemDns} onChange={(_, systemDns) => set({ systemDns })} />
          </DialogRow>
        )}
      </List>
      <LinesField label={t('opt.routeAddress')} placeholder="0.0.0.0/1" value={draft.route} onChange={(route) => set({ route })} />
      <LinesField label={t('opt.dnsHijack')} rows={2} placeholder="any:53" value={draft.hijack} onChange={(hijack) => set({ hijack })} />
    </BaseDialog>
  );
}

export function BypassDialog({ onClose }: DialogProps) {
  const [draft, set] = useDraft((o) => ({ text: toLines(o.bypassDomains) }));
  return (
    <BaseDialog title={t('settings.bypass')} contentSx={{ width: 450 }} {...saveProps(onClose, () => ({ bypassDomains: fromLines(draft.text) }))}>
      <LinesField
        label={t('settings.bypassDomains')}
        rows={8}
        placeholder={os === 'macos' ? '192.168.0.0/16' : '192.168.*'}
        value={draft.text}
        onChange={(text) => set({ text })}
      />
    </BaseDialog>
  );
}

const validPort = (port: number, min: number) => Number.isInteger(port) && port >= min && port <= 65535;

export function PortsDialog({ onClose }: DialogProps) {
  const [draft, set] = useDraft((o) => ({ mixedPort: o.mixedPort as number, socksPort: o.socksPort as number, httpPort: o.httpPort as number }));
  const valid = validPort(draft.mixedPort, 1) && validPort(draft.socksPort, 0) && validPort(draft.httpPort, 0);
  return (
    <BaseDialog title={t('opt.ports')} contentSx={{ width: 400 }} okDisabled={!valid} {...saveProps(onClose, () => draft)}>
      <List>
        <DialogRow label={t('opt.mixedPort')}>
          <NumberField value={draft.mixedPort} error={!validPort(draft.mixedPort, 1)} onChange={(mixedPort) => set({ mixedPort })} />
        </DialogRow>
        <DialogRow label={t('opt.socksPort')}>
          <NumberField value={draft.socksPort} error={!validPort(draft.socksPort, 0)} onChange={(socksPort) => set({ socksPort })} />
        </DialogRow>
        <DialogRow label={t('opt.httpPort')}>
          <NumberField value={draft.httpPort} error={!validPort(draft.httpPort, 0)} onChange={(httpPort) => set({ httpPort })} />
        </DialogRow>
      </List>
    </BaseDialog>
  );
}

export function MiscDialog({ onClose }: DialogProps) {
  const [draft, set] = useDraft((o) => ({
    keepAliveInterval: o.keepAliveInterval as number,
    interfaceName: o.interfaceName as string,
    testUrl: o.testUrl as string,
    userAgent: o.userAgent as string,
    auth: toLines(o.authentication),
    hosts: toPairs(o.hosts),
  }));
  const patch = () => ({
    keepAliveInterval: Math.max(0, Math.floor(draft.keepAliveInterval)),
    interfaceName: draft.interfaceName.trim(),
    testUrl: draft.testUrl.trim(),
    userAgent: draft.userAgent.trim(),
    authentication: fromLines(draft.auth),
    hosts: fromPairs(draft.hosts),
  });
  return (
    <BaseDialog title={t('settings.misc')} contentSx={{ width: 450 }} {...saveProps(onClose, patch)}>
      <List>
        <DialogRow label={t('opt.keepAlive')}>
          <NumberField value={draft.keepAliveInterval} onChange={(keepAliveInterval) => set({ keepAliveInterval })} />
        </DialogRow>
        <DialogRow label={t('opt.interfaceName')}>
          <PlainField sx={{ width: 250 }} value={draft.interfaceName} onChange={(event) => set({ interfaceName: event.target.value })} />
        </DialogRow>
        <DialogRow label={t('opt.testUrl')}>
          <PlainField sx={{ width: 250 }} value={draft.testUrl} onChange={(event) => set({ testUrl: event.target.value })} />
        </DialogRow>
        <DialogRow label={t('opt.userAgent')}>
          <PlainField sx={{ width: 250 }} value={draft.userAgent} onChange={(event) => set({ userAgent: event.target.value })} />
        </DialogRow>
      </List>
      <LinesField label={t('opt.auth')} rows={2} placeholder="user:password" value={draft.auth} onChange={(auth) => set({ auth })} />
      <LinesField label={t('opt.hosts')} placeholder="example.com=192.0.2.1" value={draft.hosts} onChange={(hosts) => set({ hosts })} />
    </BaseDialog>
  );
}

export function AddedRulesDialog({ onClose }: DialogProps) {
  const [draft, set] = useDraft((o) => ({ text: toLines(o.addedRules) }));
  return (
    <BaseDialog title={t('opt.addedRules')} contentSx={{ width: 520 }} {...saveProps(onClose, () => ({ addedRules: fromLines(draft.text) }))}>
      <LinesField
        label={t('settings.addedRules')}
        rows={10}
        placeholder="DOMAIN-SUFFIX,example.com,DIRECT"
        value={draft.text}
        onChange={(text) => set({ text })}
      />
    </BaseDialog>
  );
}

const dnsModes = [
  { value: 'fakeIp', label: 'fake-ip' },
  { value: 'redirHost', label: 'redir-host' },
  { value: 'normal', label: 'normal' },
];
const dnsLists = ['fakeIpFilter', 'defaultNameserver', 'nameserver', 'fallback', 'proxyServerNameserver'] as const;
const filterLists = ['geosite', 'ipcidr', 'domain'] as const;
const dnsToggles = ['preferH3', 'useHosts', 'useSystemHosts', 'respectRules', 'ipv6'] as const;

export function DnsDialog({ onClose }: DialogProps) {
  const [draft, set] = useDraft((o) => ({
    overrideDns: !!o.overrideDns,
    appendSystemDns: !!o.appendSystemDns,
    dns: {
      ...o.dns,
      ...Object.fromEntries(dnsLists.map((key) => [key, toLines(o.dns[key])])),
      nameserverPolicy: toPairs(o.dns.nameserverPolicy),
      fallbackFilter: { ...o.dns.fallbackFilter, ...Object.fromEntries(filterLists.map((key) => [key, toLines(o.dns.fallbackFilter?.[key])])) },
    } as any,
  }));
  const d = draft.dns;
  const setDns = (patch: Record<string, unknown>) => set({ dns: { ...d, ...patch } });
  const setFilter = (patch: Record<string, unknown>) => setDns({ fallbackFilter: { ...d.fallbackFilter, ...patch } });
  const patch = () => ({
    overrideDns: draft.overrideDns,
    appendSystemDns: draft.appendSystemDns,
    dns: {
      ...d,
      listen: d.listen.trim(),
      fakeIpRange: d.fakeIpRange.trim(),
      ...Object.fromEntries(dnsLists.map((key) => [key, fromLines(d[key])])),
      nameserverPolicy: fromPairs(d.nameserverPolicy),
      fallbackFilter: {
        ...d.fallbackFilter,
        geoipCode: d.fallbackFilter.geoipCode.trim(),
        ...Object.fromEntries(filterLists.map((key) => [key, fromLines(d.fallbackFilter[key])])),
      },
    },
  });
  const toggleLabels: Record<string, string> = {
    preferH3: t('opt.preferH3'),
    useHosts: t('opt.useHosts'),
    useSystemHosts: t('opt.useSystemHosts'),
    respectRules: t('opt.respectRules'),
    ipv6: t('opt.dnsIpv6'),
  };
  return (
    <BaseDialog title={t('settings.dns')} contentSx={{ width: 550 }} {...saveProps(onClose, patch)}>
      <List>
        <DialogRow label={t('opt.overrideDns')}>
          <Switch edge="end" checked={draft.overrideDns} onChange={(_, overrideDns) => set({ overrideDns })} />
        </DialogRow>
        <DialogRow label={t('settings.appendSystemDns')}>
          <Switch edge="end" checked={draft.appendSystemDns} onChange={(_, appendSystemDns) => set({ appendSystemDns })} />
        </DialogRow>
      </List>
      {draft.overrideDns && (
        <>
          <DialogSection title="DNS" />
          <List disablePadding>
            <DialogRow label={t('opt.dnsEnable')}>
              <Switch edge="end" checked={d.enable} onChange={(_, enable) => setDns({ enable })} />
            </DialogRow>
            <DialogRow label={t('opt.dnsListen')}>
              <PlainField sx={{ width: 200 }} placeholder="0.0.0.0:1053" value={d.listen} onChange={(event) => setDns({ listen: event.target.value })} />
            </DialogRow>
            <DialogRow label={t('opt.enhancedMode')}>
              <Choice width={150} value={d.enhancedMode} options={dnsModes} onChange={(enhancedMode) => setDns({ enhancedMode })} />
            </DialogRow>
            <DialogRow label={t('opt.fakeIpRange')}>
              <PlainField sx={{ width: 200 }} value={d.fakeIpRange} onChange={(event) => setDns({ fakeIpRange: event.target.value })} />
            </DialogRow>
          </List>
          <LinesField label={t('opt.fakeIpFilter')} rows={4} value={d.fakeIpFilter} onChange={(fakeIpFilter) => setDns({ fakeIpFilter })} />

          <DialogSection title={t('opt.servers')} />
          <LinesField label={t('opt.defaultNameserver')} rows={2} value={d.defaultNameserver} onChange={(defaultNameserver) => setDns({ defaultNameserver })} />
          <LinesField label={t('opt.nameserver')} value={d.nameserver} onChange={(nameserver) => setDns({ nameserver })} />
          <LinesField label={t('opt.fallback')} rows={2} value={d.fallback} onChange={(fallback) => setDns({ fallback })} />
          <LinesField
            label={t('opt.proxyNameserver')}
            rows={2}
            value={d.proxyServerNameserver}
            onChange={(proxyServerNameserver) => setDns({ proxyServerNameserver })}
          />
          <LinesField
            label={t('opt.policy')}
            placeholder="+.example.com=https://dns.example/dns-query"
            value={d.nameserverPolicy}
            onChange={(nameserverPolicy) => setDns({ nameserverPolicy })}
          />

          <DialogSection title={t('opt.dnsBehavior')} />
          <List disablePadding>
            {dnsToggles.map((key) => (
              <DialogRow key={key} label={toggleLabels[key]}>
                <Switch edge="end" checked={!!d[key]} onChange={(_, on) => setDns({ [key]: on })} />
              </DialogRow>
            ))}
          </List>

          <DialogSection title={t('opt.fallbackFilter')} />
          <List disablePadding>
            <DialogRow label={t('opt.geoip')}>
              <Switch edge="end" checked={!!d.fallbackFilter.geoip} onChange={(_, geoip) => setFilter({ geoip })} />
            </DialogRow>
            <DialogRow label={t('opt.geoipCode')}>
              <PlainField sx={{ width: 150 }} value={d.fallbackFilter.geoipCode} onChange={(event) => setFilter({ geoipCode: event.target.value })} />
            </DialogRow>
          </List>
          <LinesField label={t('opt.geosite')} rows={2} value={d.fallbackFilter.geosite} onChange={(geosite) => setFilter({ geosite })} />
          <LinesField label={t('opt.ipcidr')} rows={2} value={d.fallbackFilter.ipcidr} onChange={(ipcidr) => setFilter({ ipcidr })} />
          <LinesField label={t('opt.domain')} value={d.fallbackFilter.domain} onChange={(domain) => setFilter({ domain })} />
        </>
      )}
    </BaseDialog>
  );
}
