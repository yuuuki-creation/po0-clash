// Card layout follows Clash Verge Rev (GPL-3.0): src/pages/home.tsx and src/components/home.
import {
  ArrowDownwardRounded,
  ArrowUpwardRounded,
  ChevronRight,
  CloudDownloadRounded,
  CloudUploadRounded,
  ComputerRounded,
  DirectionsRounded,
  DnsOutlined,
  EventOutlined,
  InfoOutlined,
  LanguageRounded,
  LinkRounded,
  LocationOnOutlined,
  MemoryRounded,
  MultipleStopRounded,
  PublicRounded,
  Refresh,
  RouterOutlined,
  SignalWifi4Bar as SignalStrong,
  SpeedOutlined,
  TroubleshootRounded,
  UpdateOutlined,
  VerifiedUserOutlined,
} from '@mui/icons-material';
import {
  alpha,
  Box,
  Button,
  Chip,
  CircularProgress,
  Grid,
  IconButton,
  LinearProgress,
  MenuItem,
  Paper,
  Stack,
  TextField,
  Tooltip,
  Typography,
  useTheme,
} from '@mui/material';
import { type ReactNode, useEffect, useRef, useState } from 'react';
import { useSnapshot } from 'valtio';
import { BaseEmpty, EnhancedCard, Switch } from '../base';
import { formatAgo, formatBytes, formatDate, formatDelay, formatElapsed, formatRate, formatUsage, t } from '../lib/i18n.js';
import { act, app, refreshExitIp, resolvedDelay, setMode, setRouteMode, testDelay, toggleEngine } from '../state/core';
import { engine, loadOptions } from '../state/settings';
import { BasePage } from '../base';

const delayColor = (delay: number | null) =>
  delay == null ? 'text.secondary' : delay === 0 ? 'error.main' : delay < 300 ? 'success.main' : delay < 800 ? 'warning.main' : 'error.main';

function useNow(active: boolean) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    if (!active) return;
    setNow(Date.now());
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, [active]);
  return now;
}

function ProfileCard() {
  const { profiles, busy } = useSnapshot(app);
  const profile = profiles.find((p) => p.selected);
  const name = profile ? (profile.kind === 'links' ? t('profiles.links') : profile.name) : t('home.profile');
  const usage = profile?.usage;
  const used = usage ? usage.upload + usage.download : 0;
  const percent = usage?.total ? Math.min(100, (used / usage.total) * 100) : 0;
  return (
    <EnhancedCard
      title={name}
      icon={<CloudUploadRounded />}
      iconColor="info"
      action={
        <Button size="small" variant="outlined" endIcon={<ChevronRight fontSize="small" />} sx={{ borderRadius: 1.5 }} onClick={() => (app.page = 'profiles')}>
          {t('nav.profiles')}
        </Button>
      }
    >
      {!profile ? (
        <BaseEmpty
          text={t('profiles.empty')}
          extra={
            <Button sx={{ mt: 1 }} variant="contained" onClick={() => (app.page = 'profiles')}>
              {t('profiles.add')}
            </Button>
          }
        />
      ) : (
        <Stack spacing={1.25}>
          {profile.url && (
            <Stack direction="row" spacing={1} sx={{ alignItems: 'center', minWidth: 0 }}>
              <LinkRounded fontSize="small" color="action" />
              <Typography variant="body2" color="text.secondary" noWrap>
                {new URL(profile.url).host}
              </Typography>
            </Stack>
          )}
          {profile.updatedAt && (
            <Stack direction="row" spacing={1} sx={{ alignItems: 'center' }}>
              <UpdateOutlined fontSize="small" color="action" />
              <Typography variant="body2" color="text.secondary" sx={{ flex: 1 }}>
                {t('home.updated', { ago: formatAgo(profile.updatedAt) })}
              </Typography>
              {profile.kind === 'subscription' && (
                <Tooltip title={t('home.update')}>
                  <IconButton size="small" disabled={!!busy[`update:${profile.id}`]} onClick={() => act(`update:${profile.id}`, 'update_profile', { id: profile.id })}>
                    {busy[`update:${profile.id}`] ? <CircularProgress size={16} /> : <Refresh fontSize="small" />}
                  </IconButton>
                </Tooltip>
              )}
            </Stack>
          )}
          {usage && (
            <>
              <Stack direction="row" spacing={1} sx={{ alignItems: 'center' }}>
                <SpeedOutlined fontSize="small" color="action" />
                <Typography variant="body2" color="text.secondary">
                  {formatUsage(used, usage.total)}
                </Typography>
              </Stack>
              {usage.expire && (
                <Stack direction="row" spacing={1} sx={{ alignItems: 'center' }}>
                  <EventOutlined fontSize="small" color="action" />
                  <Typography variant="body2" color="text.secondary">
                    {t('profiles.expire', { date: formatDate(usage.expire) })}
                  </Typography>
                </Stack>
              )}
              <LinearProgress variant="determinate" value={percent} color={percent > 90 ? 'error' : percent > 70 ? 'warning' : 'primary'} sx={{ height: 8, borderRadius: 4 }} />
            </>
          )}
        </Stack>
      )}
    </EnhancedCard>
  );
}

let chosenGroup: string | null = null;

function CurrentProxyCard() {
  const { groups, status, busy } = useSnapshot(app);
  const [, redraw] = useState(0);
  const running = status?.engine.state === 'running';
  const selectable = groups.filter((g) => g.selectable);
  const group = selectable.find((g) => g.name === chosenGroup) ?? selectable.find((g) => g.now === status?.currentNode) ?? selectable[0];
  const node = group?.nodes.find((n: any) => n.name === group.now);
  const delay = node ? resolvedDelay(node, groups) : null;
  const testing = group && !!busy[`delay:${group.name}`];
  const fieldSx = { '& .MuiInputBase-root': { borderRadius: 1.5 } };
  return (
    <EnhancedCard
      title={t('home.node')}
      icon={<SignalStrong />}
      iconColor="primary"
      action={
        <Stack direction="row" spacing={1} sx={{ alignItems: 'center' }}>
          {group && (
            <Tooltip title={t('home.test')}>
              <IconButton size="small" color="inherit" disabled={testing} onClick={() => testDelay(group.name)}>
                {testing ? <CircularProgress size={18} /> : <SpeedOutlined />}
              </IconButton>
            </Tooltip>
          )}
          <Button size="small" variant="outlined" endIcon={<ChevronRight fontSize="small" />} sx={{ borderRadius: 1.5 }} onClick={() => (app.page = 'proxies')}>
            {t('nav.proxies')}
          </Button>
        </Stack>
      }
    >
      {!running || !group ? (
        <BaseEmpty text={running ? t('proxies.empty') : t('status.stopped')} />
      ) : (
        <Stack spacing={1.5}>
          <Box
            sx={({ palette }) => ({
              display: 'flex',
              alignItems: 'center',
              gap: 1,
              p: 1.25,
              borderRadius: 1.5,
              bgcolor: alpha(palette.primary.main, 0.05),
              border: `1px solid ${alpha(palette.primary.main, 0.2)}`,
            })}
          >
            <Box sx={{ flex: 1, minWidth: 0 }}>
              <Typography sx={{ fontWeight: 600 }} noWrap>
                {node?.name ?? group.now ?? '—'}
              </Typography>
              <Stack direction="row" spacing={0.75} sx={{ mt: 0.5 }}>
                <Chip size="small" variant="outlined" label={group.kind} sx={{ height: 20, fontSize: 11 }} />
                {node && <Chip size="small" variant="outlined" label={node.kind} sx={{ height: 20, fontSize: 11 }} />}
              </Stack>
            </Box>
            {delay != null && (
              <Typography sx={{ color: delayColor(delay), fontSize: 14, fontWeight: 600, whiteSpace: 'nowrap' }}>{formatDelay(delay)}</Typography>
            )}
          </Box>
          <TextField
            select
            size="small"
            fullWidth
            label={t('home.group')}
            value={group.name}
            sx={fieldSx}
            onChange={(event) => {
              chosenGroup = event.target.value;
              redraw((n) => n + 1);
            }}
          >
            {selectable.map((g) => (
              <MenuItem key={g.name} value={g.name}>
                {g.name}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            select
            size="small"
            fullWidth
            label={t('home.switchTo')}
            value={group.now ?? ''}
            sx={fieldSx}
            slotProps={{ select: { MenuProps: { slotProps: { paper: { sx: { maxHeight: 360 } } } } } }}
            onChange={(event) => act(`select:${group.name}`, 'select_node', { group: group.name, node: event.target.value })}
          >
            {group.nodes.map((n: any) => {
              const d = resolvedDelay(n, groups);
              return (
                <MenuItem key={n.name} value={n.name} sx={{ justifyContent: 'space-between', gap: 2 }}>
                  <Typography noWrap sx={{ fontSize: 14 }}>
                    {n.name}
                  </Typography>
                  {d != null && <Typography sx={{ color: delayColor(d), fontSize: 12 }}>{formatDelay(d)}</Typography>}
                </MenuItem>
              );
            })}
          </TextField>
        </Stack>
      )}
    </EnhancedCard>
  );
}

function TabButton({ active, on, icon, label, onClick }: { active: boolean; on?: boolean; icon: ReactNode; label: string; onClick: () => void }) {
  return (
    <Paper
      elevation={0}
      onClick={onClick}
      sx={{
        cursor: 'pointer',
        px: 2,
        py: 1.2,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 1,
        bgcolor: active ? 'primary.main' : 'background.paper',
        color: active ? 'primary.contrastText' : 'text.primary',
        borderRadius: 1.5,
        flex: 1,
        maxWidth: 160,
        transition: 'all 0.2s ease-in-out',
        position: 'relative',
        '&:hover': { transform: 'translateY(-1px)' },
        '&:active': { transform: 'translateY(1px)' },
        '&::after': active
          ? { content: '""', position: 'absolute', bottom: -9, left: '50%', width: 2, height: 9, bgcolor: 'primary.main', transform: 'translateX(-50%)' }
          : {},
      }}
    >
      {icon}
      <Typography variant="body2" sx={{ fontWeight: active ? 600 : 400 }} noWrap>
        {label}
      </Typography>
      {on && <Box sx={{ width: 8, height: 8, borderRadius: '50%', bgcolor: active ? '#fff' : 'success.main', position: 'absolute', top: 6, right: 6 }} />}
    </Paper>
  );
}

function Description({ children }: { children: ReactNode }) {
  return (
    <Typography
      variant="caption"
      component="div"
      sx={{
        width: '95%',
        mx: 'auto',
        my: 1,
        textAlign: 'center',
        color: 'text.secondary',
        p: 0.8,
        borderRadius: 1,
        border: 1,
        borderColor: 'primary.main',
        bgcolor: 'background.paper',
        wordBreak: 'break-word',
      }}
    >
      {children}
    </Typography>
  );
}

function NetworkCard() {
  const { status, busy, connectedAt } = useSnapshot(app);
  const theme = useTheme();
  const state = status?.engine.state ?? 'stopped';
  const running = state === 'running';
  const connecting = state === 'starting' || (!!busy.engine && !running);
  const now = useNow(!!connectedAt);
  const route = status?.routeMode ?? 'systemProxy';
  const text = running
    ? `${t('status.running')} · ${formatElapsed(now - (connectedAt ?? now))}`
    : connecting
      ? t('status.starting')
      : state === 'failed'
        ? `${t('status.failed')}: ${status.engine.message}`
        : t('status.stopped');
  return (
    <EnhancedCard title={t('home.route')} icon={<DnsOutlined />} iconColor="primary">
      <Stack direction="row" spacing={1} sx={{ justifyContent: 'center' }}>
        <TabButton active={route === 'systemProxy'} on={running && route === 'systemProxy'} icon={<ComputerRounded fontSize="small" />} label={t('route.systemProxy')} onClick={() => route !== 'systemProxy' && setRouteMode('systemProxy')} />
        <TabButton active={route === 'tun'} on={running && route === 'tun'} icon={<TroubleshootRounded fontSize="small" />} label={t('route.tun')} onClick={() => route !== 'tun' && setRouteMode('tun')} />
      </Stack>
      <Description>
        <span className="selectable">{text}</span>
      </Description>
      <Box sx={{ p: 1, pl: 1.5, bgcolor: alpha(theme.palette.primary.main, 0.04), borderRadius: 2, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Stack direction="row" spacing={1} sx={{ alignItems: 'center' }}>
          {route === 'tun' ? <TroubleshootRounded color={running ? 'primary' : 'disabled'} /> : <ComputerRounded color={running ? 'primary' : 'disabled'} />}
          <Typography sx={{ fontSize: 15 }}>{running || connecting ? t('home.disconnect') : state === 'failed' ? t('home.reconnect') : t('home.connect')}</Typography>
        </Stack>
        <Stack direction="row" spacing={1} sx={{ alignItems: 'center' }}>
          {connecting && <CircularProgress size={16} />}
          <Switch edge="end" checked={running || connecting} disabled={connecting} onChange={toggleEngine} />
        </Stack>
      </Box>
    </EnhancedCard>
  );
}

const MODES = [
  ['rule', <MultipleStopRounded fontSize="small" />],
  ['global', <LanguageRounded fontSize="small" />],
  ['direct', <DirectionsRounded fontSize="small" />],
] as const;

function ModeCard() {
  const { status } = useSnapshot(app);
  const mode = status?.mode ?? 'rule';
  return (
    <EnhancedCard title={t('home.mode')} icon={<RouterOutlined />} iconColor="info">
      <Stack direction="row" spacing={1} sx={{ justifyContent: 'center', py: 1 }}>
        {MODES.map(([id, icon]) => (
          <TabButton key={id} active={mode === id} icon={icon} label={t(`mode.${id}`)} onClick={() => mode !== id && setMode(id)} />
        ))}
      </Stack>
      <Description>{t(`modeHint.${mode}`)}</Description>
    </EnhancedCard>
  );
}

function StatBox({ icon, label, value, unit, color, onClick }: { icon: ReactNode; label: string; value: string; unit: string; color: 'primary' | 'secondary' | 'error' | 'warning' | 'info' | 'success'; onClick?: () => void }) {
  return (
    <Paper
      elevation={0}
      onClick={onClick}
      sx={({ palette }) => ({
        display: 'flex',
        alignItems: 'center',
        borderRadius: 2,
        bgcolor: alpha(palette[color].main, 0.05),
        border: `1px solid ${alpha(palette[color].main, 0.15)}`,
        p: 1,
        cursor: onClick ? 'pointer' : 'default',
        transition: 'all 0.2s ease-in-out',
        '&:hover': onClick ? { bgcolor: alpha(palette[color].main, 0.1) } : {},
      })}
    >
      <Box sx={{ mr: 1, ml: 0.5, display: 'flex', color: `${color}.main` }}>{icon}</Box>
      <Box sx={{ flexGrow: 1, minWidth: 0 }}>
        <Typography variant="caption" color="text.secondary" noWrap component="div">
          {label}
        </Typography>
        <Box sx={{ display: 'flex', alignItems: 'baseline' }}>
          <Typography variant="body1" sx={{ fontWeight: 'bold', mr: 0.5 }} noWrap>
            {value}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            {unit}
          </Typography>
        </Box>
      </Box>
    </Paper>
  );
}

const CHART_POINTS = 60;

function TrafficChart() {
  const { history } = useSnapshot(app);
  const theme = useTheme();
  const canvas = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const el = canvas.current;
    if (!el) return;
    const ratio = window.devicePixelRatio || 1;
    const [width, height] = [el.clientWidth, el.clientHeight];
    el.width = width * ratio;
    el.height = height * ratio;
    const ctx = el.getContext('2d')!;
    ctx.scale(ratio, ratio);
    ctx.clearRect(0, 0, width, height);
    const points = history.slice(-CHART_POINTS);
    const peak = Math.max(64 * 1024, ...points.map((p) => Math.max(p.up, p.down))) * 1.15;
    ctx.strokeStyle = theme.palette.divider;
    ctx.lineWidth = 1;
    for (let i = 1; i < 4; i++) {
      const y = Math.round((height * i) / 4) + 0.5;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    }
    ctx.fillStyle = theme.palette.text.secondary;
    ctx.font = `11px ${theme.typography.fontFamily}`;
    ctx.fillText(formatRate(peak), 6, 13);
    const draw = (key: 'up' | 'down', color: string) => {
      const at = (i: number) => {
        const value = points[i - (CHART_POINTS - points.length)]?.[key] ?? 0;
        return [(i / (CHART_POINTS - 1)) * width, height - 1 - (value / peak) * (height - 4)] as const;
      };
      ctx.beginPath();
      for (let i = 0; i < CHART_POINTS; i++) {
        const [x, y] = at(i);
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.lineWidth = 2;
      ctx.lineJoin = 'round';
      ctx.strokeStyle = color;
      ctx.stroke();
      ctx.lineTo(width, height);
      ctx.lineTo(0, height);
      ctx.closePath();
      const fill = ctx.createLinearGradient(0, 0, 0, height);
      fill.addColorStop(0, alpha(color, 0.3));
      fill.addColorStop(1, alpha(color, 0.02));
      ctx.fillStyle = fill;
      ctx.fill();
    };
    draw('up', theme.palette.secondary.main);
    draw('down', theme.palette.primary.main);
  }, [history, theme]);
  return (
    <Box sx={{ height: 130, borderRadius: 2, border: 1, borderColor: 'divider', overflow: 'hidden', bgcolor: 'surface.card' }}>
      <canvas ref={canvas} style={{ width: '100%', height: '100%', display: 'block' }} />
    </Box>
  );
}

function TrafficCard() {
  const { traffic, totals, memory } = useSnapshot(app);
  const split = (text: string) => text.split(' ') as [string, string];
  const [up, upUnit] = split(formatBytes(traffic.up));
  const [down, downUnit] = split(formatBytes(traffic.down));
  const [upTotal, upTotalUnit] = split(formatBytes(totals?.uploadTotal ?? 0));
  const [downTotal, downTotalUnit] = split(formatBytes(totals?.downloadTotal ?? 0));
  const [used, usedUnit] = split(formatBytes(memory));
  return (
    <EnhancedCard title={t('home.traffic')} icon={<SpeedOutlined />} iconColor="secondary">
      <Grid container spacing={1} columns={{ xs: 8, sm: 8, md: 12 }}>
        <Grid size={12}>
          <TrafficChart />
        </Grid>
        <Grid size={4}>
          <StatBox icon={<ArrowUpwardRounded fontSize="small" />} label={t('traffic.upload')} value={up} unit={`${upUnit}/s`} color="secondary" />
        </Grid>
        <Grid size={4}>
          <StatBox icon={<ArrowDownwardRounded fontSize="small" />} label={t('traffic.download')} value={down} unit={`${downUnit}/s`} color="primary" />
        </Grid>
        <Grid size={4}>
          <StatBox icon={<LinkRounded fontSize="small" />} label={t('home.connections')} value={String(totals?.items.length ?? 0)} unit="" color="success" onClick={() => (app.page = 'connections')} />
        </Grid>
        <Grid size={4}>
          <StatBox icon={<CloudUploadRounded fontSize="small" />} label={t('home.uploaded')} value={upTotal} unit={upTotalUnit} color="secondary" />
        </Grid>
        <Grid size={4}>
          <StatBox icon={<CloudDownloadRounded fontSize="small" />} label={t('home.downloaded')} value={downTotal} unit={downTotalUnit} color="primary" />
        </Grid>
        <Grid size={4}>
          <StatBox icon={<MemoryRounded fontSize="small" />} label={t('traffic.memory')} value={used} unit={usedUnit} color="error" />
        </Grid>
      </Grid>
    </EnhancedCard>
  );
}

function InfoRow({ label, children }: { label: string; children: ReactNode }) {
  return (
    <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center', gap: 2, minHeight: 24 }}>
      <Typography variant="body2" color="text.secondary" noWrap>
        {label}
      </Typography>
      <Typography variant="body2" component="div" className="selectable" noWrap sx={{ fontWeight: 500, minWidth: 0 }}>
        {children}
      </Typography>
    </Stack>
  );
}

function IpCard() {
  const { exitIp, exitIpLoading, lan } = useSnapshot(app);
  return (
    <EnhancedCard
      title={t('home.exitIp')}
      icon={<LocationOnOutlined />}
      iconColor="info"
      action={
        <Tooltip title={t('home.refresh')}>
          <IconButton size="small" disabled={exitIpLoading} onClick={() => refreshExitIp()}>
            {exitIpLoading ? <CircularProgress size={18} /> : <Refresh />}
          </IconButton>
        </Tooltip>
      }
    >
      <Stack spacing={1}>
        <Stack direction="row" spacing={1} sx={{ alignItems: 'center' }}>
          <PublicRounded color="primary" />
          <Typography className="selectable" sx={{ fontSize: 18, fontWeight: 600, fontFamily: 'monospace' }}>
            {exitIp?.ip ?? '—'}
          </Typography>
          {exitIp?.country && <Chip size="small" label={exitIp.country} sx={{ height: 22 }} />}
        </Stack>
        <InfoRow label={t('home.lan')}>{lan ? lan.ip : '—'}</InfoRow>
        {lan?.interface && <InfoRow label={t('home.interface')}>{lan.interface}</InfoRow>}
      </Stack>
    </EnhancedCard>
  );
}

function WhitelistCard() {
  const { whitelist, busy } = useSnapshot(app);
  const checked = whitelist.entries.filter((e) => e.result);
  const applied = checked.filter((e) => e.result.outcome === 'applied').length;
  const issues = checked.length - applied;
  const summary = !whitelist.enabled
    ? t('home.whitelistOff')
    : !whitelist.entries.length
      ? t('home.noEntries')
      : !checked.length
        ? t('home.pending')
        : issues
          ? t('home.issues', { count: issues })
          : t('whitelist.summary', { applied, total: whitelist.entries.length });
  return (
    <EnhancedCard
      title={t('home.whitelist')}
      icon={<VerifiedUserOutlined />}
      iconColor={whitelist.enabled && issues ? 'warning' : 'success'}
      action={
        <Button size="small" variant="outlined" endIcon={<ChevronRight fontSize="small" />} sx={{ borderRadius: 1.5 }} onClick={() => (app.page = 'whitelist')}>
          {t('nav.whitelist')}
        </Button>
      }
    >
      <Stack spacing={1}>
        <Stack direction="row" sx={{ alignItems: 'center', justifyContent: 'space-between' }}>
          <Typography sx={{ fontSize: 15 }}>{t('whitelist.enabled')}</Typography>
          <Switch edge="end" checked={whitelist.enabled} disabled={!!busy['wl:enabled']} onChange={(_, enabled) => act('wl:enabled', 'set_whitelist_enabled', { enabled })} />
        </Stack>
        <Typography variant="body2" color={whitelist.enabled && issues ? 'warning.main' : 'text.secondary'}>
          {summary}
        </Typography>
      </Stack>
    </EnhancedCard>
  );
}

function AppInfoCard() {
  const { version, requestCount, connectedAt } = useSnapshot(app);
  const { options } = useSnapshot(engine);
  const now = useNow(!!connectedAt);
  useEffect(() => {
    if (!engine.options) loadOptions().catch(() => {});
  }, []);
  return (
    <EnhancedCard title={t('home.info')} icon={<InfoOutlined />} iconColor="warning">
      <Stack spacing={1}>
        <InfoRow label={t('tools.version')}>{version}</InfoRow>
        <InfoRow label={t('home.mixedPort')}>{options?.mixedPort ?? '—'}</InfoRow>
        <InfoRow label={t('home.uptime')}>{connectedAt ? formatElapsed(now - connectedAt) : '—'}</InfoRow>
        <InfoRow label={t('activity.requests')}>{requestCount}</InfoRow>
      </Stack>
    </EnhancedCard>
  );
}

export default function Home() {
  return (
    <BasePage title={t('nav.home')} contentStyle={{ padding: 2 }}>
      <Grid container spacing={1.5} columns={{ xs: 6, sm: 6, md: 12 }}>
        <Grid size={6}>
          <ProfileCard />
        </Grid>
        <Grid size={6}>
          <CurrentProxyCard />
        </Grid>
        <Grid size={6}>
          <NetworkCard />
        </Grid>
        <Grid size={6}>
          <ModeCard />
        </Grid>
        <Grid size={12}>
          <TrafficCard />
        </Grid>
        <Grid size={6}>
          <WhitelistCard />
        </Grid>
        <Grid size={6}>
          <IpCard />
        </Grid>
        <Grid size={6}>
          <AppInfoCard />
        </Grid>
      </Grid>
    </BasePage>
  );
}
