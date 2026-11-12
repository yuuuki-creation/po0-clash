// The window layout follows Clash Verge Rev (GPL-3.0): src/pages/_layout.tsx and src/components/layout.
import {
  ArrowDownwardRounded,
  ArrowUpwardRounded,
  Close,
  CropSquare,
  DnsOutlined,
  FilterNone,
  ForkRightRounded,
  HomeOutlined,
  LanguageRounded,
  MemoryRounded,
  Minimize,
  SettingsOutlined,
  SubjectOutlined,
  VerifiedUserOutlined,
  WifiRounded,
} from '@mui/icons-material';
import {
  Alert,
  alpha,
  Box,
  Button,
  IconButton,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Menu,
  MenuItem,
  Paper,
  Snackbar,
  Typography,
} from '@mui/material';
import { type ReactNode, useEffect, useRef, useState } from 'react';
import { useSnapshot } from 'valtio';
import { BaseDialog } from '../base';
import { invoke, os, win } from '../ipc';
import { formatBytes, t } from '../lib/i18n.js';
import { app, dismissNotice, type PageId } from '../state/core';
import { settings, updateSettings } from '../state/settings';
import { update } from '../state/update';

export const navItems: { id: PageId; icon: ReactNode }[] = [
  { id: 'home', icon: <HomeOutlined /> },
  { id: 'proxies', icon: <WifiRounded /> },
  { id: 'profiles', icon: <DnsOutlined /> },
  { id: 'whitelist', icon: <VerifiedUserOutlined /> },
  { id: 'connections', icon: <LanguageRounded /> },
  { id: 'rules', icon: <ForkRightRounded /> },
  { id: 'logs', icon: <SubjectOutlined /> },
  { id: 'settings', icon: <SettingsOutlined /> },
];

function Logo() {
  return (
    <svg viewBox="0 0 1024 1024" aria-hidden="true">
      <clipPath id="logo-bowl">
        <circle cx="529" cy="430" r="206" />
      </clipPath>
      <rect width="1024" height="1024" rx="230" fill="#899BA6" />
      <g transform="translate(512 512) scale(1.12) translate(-508 -512)">
        <rect x="282" y="224" width="150" height="576" rx="75" fill="#F0EAE0" />
        <circle cx="529" cy="430" r="206" fill="#D6B2A8" />
        <rect x="282" y="224" width="150" height="576" rx="75" fill="#BE968E" clipPath="url(#logo-bowl)" />
      </g>
    </svg>
  );
}

function NavItem({ id, icon, selected }: { id: PageId; icon: ReactNode; selected: boolean }) {
  const label = t(`nav.${id}`);
  return (
    <ListItem sx={{ maxWidth: 250, mx: 'auto', padding: '4px 0px' }}>
      <ListItemButton
        aria-current={selected ? 'page' : undefined}
        selected={selected}
        title={label}
        onClick={() => (app.page = id)}
        sx={[
          {
            borderRadius: 2,
            mx: 1.25,
            px: 1,
            cursor: 'pointer',
            '& .MuiListItemText-primary': { color: 'text.primary', fontWeight: 700 },
          },
          ({ palette: { mode, primary } }) => {
            const bgcolor = alpha(primary.main, mode === 'light' ? 0.15 : 0.35);
            return { '&.Mui-selected': { bgcolor }, '&.Mui-selected:hover': { bgcolor } };
          },
        ]}
      >
        <ListItemIcon sx={{ color: 'text.primary', ml: '6px', cursor: 'inherit' }}>{icon}</ListItemIcon>
        <ListItemText sx={{ textAlign: 'center', ml: '-35px' }} primary={label} />
      </ListItemButton>
    </ListItem>
  );
}

const GRAPH_POINTS = 60;

function TrafficGraph() {
  const { history } = useSnapshot(app);
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
    const points = history.slice(-GRAPH_POINTS);
    const peak = Math.max(1024, ...points.map((p) => Math.max(p.up, p.down)));
    const style = getComputedStyle(document.documentElement);
    const draw = (key: 'up' | 'down', color: string) => {
      ctx.beginPath();
      for (let i = 0; i < GRAPH_POINTS; i++) {
        const value = points[i - (GRAPH_POINTS - points.length)]?.[key] ?? 0;
        const x = (i / (GRAPH_POINTS - 1)) * width;
        const y = height - 2 - (value / peak) * (height - 6);
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.lineWidth = 1.5;
      ctx.lineJoin = 'round';
      ctx.strokeStyle = color;
      ctx.stroke();
    };
    draw('up', style.getPropertyValue('--secondary-main').trim() || '#FC9B76');
    draw('down', style.getPropertyValue('--primary-main').trim());
  }, [history]);

  return <canvas ref={canvas} style={{ width: '100%', height: 60, marginBottom: 6, display: 'block' }} />;
}

function TrafficRow({ icon, value, unit, color, title }: { icon: ReactNode; value: string; unit: string; color?: string; title: string }) {
  return (
    <Box title={title} sx={{ display: 'flex', alignItems: 'center', whiteSpace: 'nowrap' }}>
      {icon}
      <Typography component="span" color={color} sx={{ flex: '1 1 56px', textAlign: 'center' }}>
        {value}
      </Typography>
      <Typography component="span" color="grey.500" sx={{ flex: '0 1 27px', fontSize: 12, textAlign: 'right' }}>
        {unit}
      </Typography>
    </Box>
  );
}

function LayoutTraffic() {
  const { traffic, memory } = useSnapshot(app);
  const [up, upUnit] = formatBytes(traffic.up).split(' ');
  const [down, downUnit] = formatBytes(traffic.down).split(' ');
  const [used, usedUnit] = formatBytes(memory).split(' ');
  const iconSx = { mr: '8px', fontSize: 16 };
  return (
    <Box>
      <TrafficGraph />
      <Box sx={{ display: 'flex', flexDirection: 'column', gap: 0.75 }}>
        <TrafficRow
          title={t('traffic.upload')}
          icon={<ArrowUpwardRounded sx={iconSx} color={traffic.up > 0 ? 'secondary' : 'disabled'} />}
          value={up}
          unit={`${upUnit}/s`}
          color="secondary"
        />
        <TrafficRow
          title={t('traffic.download')}
          icon={<ArrowDownwardRounded sx={iconSx} color={traffic.down > 0 ? 'primary' : 'disabled'} />}
          value={down}
          unit={`${downUnit}/s`}
          color="primary"
        />
        <TrafficRow title={t('traffic.memory')} icon={<MemoryRounded sx={iconSx} />} value={used} unit={usedUnit} />
      </Box>
    </Box>
  );
}

function WindowControls() {
  const [maximized, setMaximized] = useState(false);
  useEffect(() => {
    const sync = () => win.isMaximized().then(setMaximized);
    sync();
    const unlisten = win.onResized(sync);
    return () => void unlisten.then((stop) => stop());
  }, []);
  return (
    <Box sx={{ display: 'flex', gap: 1, alignItems: 'center', '> button': { cursor: 'default' } }}>
      <IconButton size="small" sx={{ fontSize: 16 }} title={t('window.minimize')} onClick={() => win.minimize()}>
        <Minimize fontSize="inherit" />
      </IconButton>
      <IconButton
        size="small"
        sx={{ fontSize: 16 }}
        title={maximized ? t('window.restore') : t('window.maximize')}
        onClick={() => win.toggleMaximize()}
      >
        {maximized ? <FilterNone fontSize="inherit" /> : <CropSquare fontSize="inherit" />}
      </IconButton>
      <IconButton
        size="small"
        sx={{ fontSize: 16, '&:hover': { bgcolor: 'error.main', color: '#fff' } }}
        title={t('window.close')}
        onClick={() => win.close()}
      >
        <Close fontSize="inherit" />
      </IconButton>
    </Box>
  );
}

function Notices() {
  const { notices } = useSnapshot(app);
  const notice = notices[0];
  return (
    <Snackbar
      key={notice?.id}
      open={!!notice}
      anchorOrigin={{ vertical: 'top', horizontal: 'right' }}
      autoHideDuration={notice?.kind === 'error' ? 8000 : 4000}
      onClose={(_, reason) => reason !== 'clickaway' && notice && dismissNotice(notice.id)}
      sx={{ mt: 4, maxWidth: 420 }}
    >
      {notice && (
        <Alert
          severity={notice.kind}
          variant="filled"
          onClose={() => dismissNotice(notice.id)}
          sx={{ alignItems: 'center', boxShadow: '0 4px 20px rgba(0, 0, 0, 0.25)' }}
        >
          <span className="selectable">{notice.title}</span>
          {notice.detail && (
            <Typography className="selectable" sx={{ fontSize: 13, opacity: 0.9, whiteSpace: 'pre-wrap' }}>
              {notice.detail}
            </Typography>
          )}
        </Alert>
      )}
    </Snackbar>
  );
}

function UpdateDialog() {
  const { release, open, automatic } = useSnapshot(update);
  const close = () => (update.open = false);
  if (!release) return null;
  const notes = release.notes.trim();
  return (
    <BaseDialog
      open={open}
      title={t('update.title', { version: release.version })}
      okBtn={t('update.download')}
      cancelBtn={t('update.later')}
      onOk={() => {
        invoke('open_url', { url: release.url });
        close();
      }}
      onCancel={close}
      contentSx={{ width: 420, maxHeight: 360 }}
    >
      {notes && (
        <Typography className="selectable" sx={{ fontSize: 14, whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
          {notes}
        </Typography>
      )}
      {automatic && (
        <Button
          size="small"
          color="inherit"
          sx={{ mt: 1, ml: -0.5, color: 'text.secondary' }}
          onClick={() => {
            updateSettings({ autoCheckUpdate: false });
            close();
          }}
        >
          {t('update.stop')}
        </Button>
      )}
    </BaseDialog>
  );
}

function Sidebar({ collapsed }: { collapsed: boolean }) {
  const { page } = useSnapshot(app);
  const { release } = useSnapshot(update);
  const [menu, setMenu] = useState<{ top: number; left: number } | null>(null);
  return (
    <div className="layout-content__left">
      <div className="the-logo" data-tauri-drag-region>
        <Logo />
        <span>po0-clash</span>
        {release && (
          <Button color="error" variant="contained" size="small" className="the-newbtn" onClick={() => (update.open = true)}>
            New
          </Button>
        )}
      </div>
      <List
        className="the-menu"
        onContextMenu={(event) => {
          event.preventDefault();
          setMenu({ top: event.clientY, left: event.clientX });
        }}
      >
        {navItems.map((item) => (
          <NavItem key={item.id} id={item.id} icon={item.icon} selected={page === item.id} />
        ))}
      </List>
      <Menu
        open={!!menu}
        onClose={() => setMenu(null)}
        anchorReference="anchorPosition"
        anchorPosition={menu ?? undefined}
        slotProps={{ list: { sx: { py: 0.5 } } }}
      >
        <MenuItem
          dense
          onClick={() => {
            setMenu(null);
            updateSettings({ showNavLabels: collapsed });
          }}
        >
          {collapsed ? t('layout.expandNav') : t('layout.collapseNav')}
        </MenuItem>
      </Menu>
      <div className="the-traffic">
        <LayoutTraffic />
      </div>
    </div>
  );
}

export function Layout({ children }: { children: ReactNode }) {
  const s = useSnapshot(settings).value;
  const collapsed = s?.showNavLabels === false;
  return (
    <>
      <Notices />
      <UpdateDialog />
      <Paper square elevation={0} className={`${os} layout${collapsed ? ' layout--nav-collapsed' : ''}`}>
        <div className="the_titlebar">
          <div className="the_titlebar-drag-region" data-tauri-drag-region />
          {os !== 'macos' && <WindowControls />}
        </div>
        <div className="layout-content">
          <Sidebar collapsed={collapsed} />
          <div className="layout-content__right">
            <div className={`the-content${s?.pageAnimation === false ? '' : ' page-motion'}`}>{children}</div>
          </div>
        </div>
      </Paper>
    </>
  );
}
