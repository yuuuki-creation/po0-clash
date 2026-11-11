// Follows Clash Verge Rev (GPL-3.0): src/pages/logs.tsx and components/log/log-item.tsx.
import { PauseCircleOutlineRounded, PlayCircleOutlineRounded } from '@mui/icons-material';
import { Box, Button, IconButton, MenuItem, Select, styled } from '@mui/material';
import { useCallback, useMemo, useState } from 'react';
import { proxy, useSnapshot } from 'valtio';
import { BaseEmpty, BasePage } from '../base';
import { emptySearch, SearchBox, useMatcher } from '../base/SearchBox';
import { invoke } from '../ipc';
import { formatTime, t } from '../lib/i18n.js';
import { act, app } from '../state/core';
import { usePoll } from './activity/usePoll';
import { pageContentStyle, selectSx, toolbarSx, VirtualList } from './activity/VirtualList';

const LEVELS = ['all', 'debug', 'info', 'warning', 'error'];

const view = proxy({ level: 'all', search: emptySearch(), paused: false });

const Item = styled('div')(({ theme: { palette } }) => ({
  padding: '8px 0',
  margin: '0 12px',
  lineHeight: 1.35,
  borderBottom: `1px solid ${palette.divider}`,
  fontSize: '0.875rem',
  '& .time': { color: palette.text.secondary },
  '& .type': { marginLeft: 8, textTransform: 'uppercase', fontWeight: 600 },
  '& .type[data-type="error"]': { color: palette.error.main },
  '& .type[data-type="warning"]': { color: palette.warning.main },
  '& .type[data-type="info"]': { color: palette.info.main },
  '& .data': { color: palette.text.primary, overflowWrap: 'anywhere' },
}));

function LogItem({ entry }: { entry: any }) {
  return (
    <Item className="selectable">
      <div>
        <span className="time">{formatTime(entry.at)}</span>
        <span className="type" data-type={entry.level}>
          {t(`level.${entry.level}`)}
        </span>
      </div>
      <div className="data">{entry.message}</div>
    </Item>
  );
}

export default function Logs() {
  const { level, search, paused } = useSnapshot(view);
  const clearing = !!useSnapshot(app).busy['logs:clear'];
  const [logs, setLogs] = useState<any[]>([]);
  const match = useMatcher(search);

  const load = useCallback(async () => setLogs((await invoke<any[]>('logs')).toReversed()), []);
  usePoll(load, !paused);

  const shown = useMemo(
    () => logs.filter((entry) => (level === 'all' || entry.level === level) && match(entry.message)),
    [logs, level, match],
  );

  async function clear() {
    await act('logs:clear', 'clear_logs');
    await load().catch(() => {});
  }

  const toggleLabel = t(paused ? 'activity.resume' : 'activity.pause');

  return (
    <BasePage
      full
      title={t('nav.logs')}
      contentStyle={pageContentStyle}
      header={
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
          <IconButton title={toggleLabel} aria-label={toggleLabel} size="small" color="inherit" onClick={() => (view.paused = !paused)}>
            {paused ? <PlayCircleOutlineRounded /> : <PauseCircleOutlineRounded />}
          </IconButton>
          <Button size="small" variant="contained" disabled={!logs.length || clearing} onClick={clear}>
            {t('activity.clear')}
          </Button>
        </Box>
      }
    >
      <Box sx={toolbarSx}>
        <Select
          size="small"
          value={level}
          sx={selectSx}
          inputProps={{ 'aria-label': t('activity.level') }}
          onChange={(event) => (view.level = event.target.value)}
        >
          {LEVELS.map((value) => (
            <MenuItem key={value} value={value}>
              {value === 'all' ? t('activity.allLevels') : t(`level.${value}`)}
            </MenuItem>
          ))}
        </Select>
        <SearchBox value={search} onChange={(next) => (view.search = next)} />
      </Box>
      {shown.length ? (
        <VirtualList count={shown.length} estimateSize={54} renderItem={(i) => <LogItem entry={shown[i]} />} style={{ flex: 1 }} />
      ) : (
        <BaseEmpty text={logs.length ? undefined : t('activity.logsEmpty')} />
      )}
    </BasePage>
  );
}
