// Follows Clash Verge Rev (GPL-3.0): src/pages/proxies.tsx.
import { CheckRounded, MyLocationRounded, NetworkCheckRounded, SearchRounded, TuneRounded } from '@mui/icons-material';
import {
  Box,
  Button,
  ButtonGroup,
  CircularProgress,
  IconButton,
  InputAdornment,
  ListItemIcon,
  ListSubheader,
  Menu,
  MenuItem,
  TextField,
} from '@mui/material';
import { useState } from 'react';
import { useSnapshot } from 'valtio';
import { BaseEmpty, BasePage } from '../base';
import { t } from '../lib/i18n.js';
import { app, isRunning, setMode, testDelay } from '../state/core';
import { settings, updateSettings } from '../state/settings';
import { ProxyGroups } from './proxies/ProxyGroups';
import { focusGroup, view } from './proxies/state';

const MODES = ['rule', 'global', 'direct'];
const DENSITIES = ['loose', 'standard', 'tight'];
const ICON_STYLES = ['standard', 'iconOnly', 'hidden'];

function locateCurrent() {
  const group = app.groups.find((g) => g.selectable && g.now === app.status?.currentNode) ?? app.groups[0];
  if (group) focusGroup(group.name);
}

async function testAll() {
  const queue = app.groups.map((group) => group.name);
  const workers = Array.from({ length: Math.min(4, queue.length) }, async () => {
    for (let next = queue.shift(); next; next = queue.shift()) await testDelay(next);
  });
  await Promise.all(workers);
}

function ViewMenu() {
  const s = useSnapshot(settings).value;
  const [anchor, setAnchor] = useState<HTMLElement | null>(null);
  const option = (key: string, value: string, label: string) => (
    <MenuItem key={`${key}:${value}`} dense selected={s[key] === value} onClick={() => updateSettings({ [key]: value })}>
      <ListItemIcon>{s[key] === value && <CheckRounded fontSize="small" />}</ListItemIcon>
      {label}
    </MenuItem>
  );
  return (
    <>
      <IconButton size="small" color="inherit" title={t('proxies.view')} onClick={(event) => setAnchor(event.currentTarget)}>
        <TuneRounded />
      </IconButton>
      <Menu open={!!anchor} anchorEl={anchor} onClose={() => setAnchor(null)} slotProps={{ list: { sx: { py: 0.5 } } }}>
        <ListSubheader sx={{ lineHeight: '32px', bgcolor: 'transparent' }}>{t('view.density')}</ListSubheader>
        {DENSITIES.map((value) => option('proxiesDensity', value, t(`density.${value}`)))}
        <ListSubheader sx={{ lineHeight: '32px', bgcolor: 'transparent' }}>{t('view.icon')}</ListSubheader>
        {ICON_STYLES.map((value) => option('groupIconStyle', value, t(`icon.${value}`)))}
      </Menu>
    </>
  );
}

export default function Proxies() {
  const { status, groups, busy } = useSnapshot(app);
  const { query } = useSnapshot(view);
  const mode = status?.mode;
  const running = isRunning(status);
  const listed = running && mode !== 'direct' && groups.length > 0;
  const testingAny = Object.keys(busy).some((key) => /^(delay|node):/.test(key));

  return (
    <BasePage
      full
      title={t('nav.proxies')}
      contentStyle={{ height: '100%' }}
      header={
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, minWidth: 0, flexWrap: 'wrap', justifyContent: 'flex-end' }}>
          {listed && (
            <>
              <TextField
                hiddenLabel
                size="small"
                autoComplete="off"
                spellCheck={false}
                value={query}
                placeholder={t('proxies.search')}
                onChange={(event) => (view.query = event.target.value)}
                sx={{ width: 170, minWidth: 90, flexShrink: 1, input: { py: 0.65, px: 0 } }}
                slotProps={{
                  htmlInput: { 'aria-label': t('proxies.searchLabel') },
                  input: {
                    sx: { pl: 1 },
                    startAdornment: (
                      <InputAdornment position="start" sx={{ mr: 0.5 }}>
                        <SearchRounded fontSize="small" />
                      </InputAdornment>
                    ),
                  },
                }}
              />
              <IconButton size="small" color="inherit" title={t('proxies.locate')} onClick={locateCurrent}>
                <MyLocationRounded />
              </IconButton>
              <IconButton size="small" color="inherit" title={t('proxies.testAll')} disabled={testingAny} onClick={testAll}>
                {testingAny ? <CircularProgress size={20} color="inherit" sx={{ m: '2px' }} /> : <NetworkCheckRounded />}
              </IconButton>
              <ViewMenu />
            </>
          )}
          <ButtonGroup size="small" sx={{ flex: 'none' }}>
            {MODES.map((value) => (
              <Button
                key={value}
                variant={value === mode ? 'contained' : 'outlined'}
                onClick={() => value !== mode && !app.busy.mode && setMode(value)}
              >
                {t(`mode.${value}`)}
              </Button>
            ))}
          </ButtonGroup>
        </Box>
      }
    >
      {!running ? (
        <BaseEmpty text={t('status.stopped')} />
      ) : mode === 'direct' ? (
        <BaseEmpty text={t('proxies.direct')} />
      ) : !groups.length ? (
        <BaseEmpty text={t('proxies.empty')} />
      ) : (
        <ProxyGroups />
      )}
    </BasePage>
  );
}
