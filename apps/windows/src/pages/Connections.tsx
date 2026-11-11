// Follows Clash Verge Rev (GPL-3.0): src/pages/connections.tsx and components/connection/connection-row-item.tsx.
import {
  CloseRounded,
  DeleteForeverRounded,
  PauseCircleOutlineRounded,
  PlayCircleOutlineRounded,
  TableChartRounded,
  TableRowsRounded,
} from '@mui/icons-material';
import { Box, Button, ButtonGroup, Fab, IconButton, MenuItem, Select, Zoom } from '@mui/material';
import { memo, useCallback, useMemo, useState } from 'react';
import { proxy, useSnapshot } from 'valtio';
import { BaseEmpty, BasePage } from '../base';
import { emptySearch, SearchBox, useMatcher } from '../base/SearchBox';
import { invoke } from '../ipc';
import { formatAgo, formatBytes, t } from '../lib/i18n.js';
import { act, app } from '../state/core';
import { ConnectionDetail } from './activity/ConnectionDetail';
import { chainOf, ConnectionTable, hostOf, typeOf } from './activity/ConnectionTable';
import { usePoll } from './activity/usePoll';
import { pageContentStyle, selectSx, toolbarSx, VirtualList } from './activity/VirtualList';

type Kind = 'active' | 'closed';
type Order = 'default' | 'download' | 'upload';

const LAYOUT_KEY = 'po0-connections-layout';
const ORDERS: Order[] = ['default', 'download', 'upload'];

const view = proxy({
  kind: 'active' as Kind,
  layout: localStorage.getItem(LAYOUT_KEY) === 'list' ? 'list' : 'table',
  order: 'default' as Order,
  search: emptySearch(),
  paused: false,
});

const tagStyle = {
  boxSizing: 'border-box',
  maxWidth: '100%',
  padding: '0 4px',
  border: '1px solid rgba(128,128,128,0.35)',
  borderRadius: 4,
  fontSize: 10,
  lineHeight: 1.375,
  overflow: 'hidden',
  textOverflow: 'ellipsis',
  whiteSpace: 'nowrap',
} as const;

interface RowProps {
  connection: any;
  closed: boolean;
  onShowDetail: (c: any) => void;
  onCloseConnection: (id: string) => void;
}

const ConnectionRow = memo(function ConnectionRow({ connection: c, closed, onShowDetail, onCloseConnection }: RowProps) {
  const busy = !!useSnapshot(app).busy[`close:${c.id}`];
  return (
    <div
      data-conn-row
      style={{
        boxSizing: 'border-box',
        minHeight: 56,
        display: 'flex',
        alignItems: 'center',
        padding: '6px 48px 6px 12px',
        borderBottom: '1px solid var(--divider-color)',
        position: 'relative',
        overflow: 'hidden',
      }}
    >
      <div style={{ minWidth: 0, flex: 1, cursor: 'pointer' }} onClick={() => onShowDetail(c)}>
        <div style={{ fontSize: 14, lineHeight: 1.4, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{hostOf(c)}</div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4, marginTop: 4, overflow: 'hidden' }}>
          <span style={tagStyle}>{typeOf(c)}</span>
          {c.process && <span style={tagStyle}>{c.process}</span>}
          <span style={tagStyle}>{chainOf(c)}</span>
          <span style={tagStyle}>{formatAgo(c.start)}</span>
          <span style={tagStyle}>
            ↑ {formatBytes(c.upload)} ↓ {formatBytes(c.download)}
          </span>
        </div>
      </div>
      {!closed && (
        <IconButton
          size="small"
          color="inherit"
          disabled={busy}
          title={t('activity.close')}
          aria-label={t('activity.close')}
          onClick={() => onCloseConnection(c.id)}
          sx={{ position: 'absolute', right: 8, top: '50%', transform: 'translateY(-50%)' }}
        >
          <CloseRounded fontSize="small" />
        </IconButton>
      )}
    </div>
  );
});

export default function Connections() {
  const { kind, layout, order, search, paused } = useSnapshot(view);
  const snap = useSnapshot(app);
  const [active, setActive] = useState<any | null>(null);
  const [closed, setClosed] = useState<any[] | null>(null);
  const [detail, setDetail] = useState<any | null>(null);
  const match = useMatcher(search);

  const loadActive = useCallback(async () => setActive(await invoke('connections')), []);
  const loadClosed = useCallback(async () => setClosed(await invoke<any[]>('requests')), []);
  usePoll(kind === 'active' ? loadActive : loadClosed, !paused);

  const totals = (kind === 'active' ? active : null) ?? snap.totals ?? active;
  const activeCount = kind === 'active' && active ? active.items.length : (snap.totals?.items.length ?? 0);
  const closedCount = kind === 'closed' && closed ? closed.length : snap.requestCount;

  const shown = useMemo(() => {
    const source: any[] = (kind === 'active' ? active?.items : closed) ?? [];
    const list = source.filter((c) => [c.host, c.destination, c.process, c.rule, c.rulePayload, ...c.chains].some((value) => value && match(value)));
    if (kind === 'closed') list.reverse();
    return list.sort((a, b) => (order === 'default' ? b.start - a.start : b[order] - a[order]));
  }, [kind, active, closed, match, order]);

  const live = detail && (shown.find((c) => c.id === detail.id) ?? detail);

  const selectKind = (next: Kind) => {
    if (next === kind) return;
    setDetail(null);
    view.kind = next;
  };

  const closeConnection = useCallback(
    async (id: string) => {
      await act(`close:${id}`, 'close_connection', { id });
      await loadActive().catch(() => {});
    },
    [loadActive],
  );

  async function closeAll() {
    await act('activity:clear', 'close_all_connections');
    await loadActive().catch(() => {});
  }

  async function clearClosed() {
    await act('activity:clear', 'clear_requests');
    await loadClosed().catch(() => {});
  }

  const toggleLayout = () => {
    view.layout = layout === 'table' ? 'list' : 'table';
    localStorage.setItem(LAYOUT_KEY, view.layout);
  };

  const clearing = !!snap.busy['activity:clear'];
  const pauseLabel = t(paused ? 'activity.resume' : 'activity.pause');
  const layoutLabel = t(layout === 'table' ? 'conn.listView' : 'conn.tableView');

  return (
    <BasePage
      full
      title={t('nav.connections')}
      contentStyle={pageContentStyle}
      header={
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, minWidth: 0, fontSize: 14, whiteSpace: 'nowrap' }}>
          <Box sx={{ display: { xs: 'none', sm: 'block' } }}>
            {t('home.downloaded')}: {formatBytes(totals?.downloadTotal ?? 0)}
          </Box>
          <Box sx={{ display: { xs: 'none', sm: 'block' } }}>
            {t('home.uploaded')}: {formatBytes(totals?.uploadTotal ?? 0)}
          </Box>
          <IconButton color="inherit" size="small" title={layoutLabel} aria-label={layoutLabel} onClick={toggleLayout}>
            {layout === 'table' ? <TableRowsRounded /> : <TableChartRounded />}
          </IconButton>
          <IconButton color="inherit" size="small" title={pauseLabel} aria-label={pauseLabel} onClick={() => (view.paused = !paused)}>
            {paused ? <PlayCircleOutlineRounded /> : <PauseCircleOutlineRounded />}
          </IconButton>
          <Button size="small" variant="contained" disabled={!activeCount || clearing} onClick={closeAll}>
            {t('conn.closeAll')}
          </Button>
        </Box>
      }
    >
      <Box sx={toolbarSx}>
        <ButtonGroup sx={{ mr: 1, flexShrink: 0 }}>
          <Button size="small" variant={kind === 'active' ? 'contained' : 'outlined'} onClick={() => selectKind('active')}>
            {t('conn.active')} {activeCount}
          </Button>
          <Button size="small" variant={kind === 'closed' ? 'contained' : 'outlined'} onClick={() => selectKind('closed')}>
            {t('conn.closed')} {closedCount}
          </Button>
        </ButtonGroup>
        <Select
          size="small"
          value={order}
          sx={selectSx}
          inputProps={{ 'aria-label': t('conn.order') }}
          onChange={(event) => (view.order = event.target.value as Order)}
        >
          {ORDERS.map((value) => (
            <MenuItem key={value} value={value}>
              <span style={{ fontSize: 14 }}>{t(`conn.order.${value}`)}</span>
            </MenuItem>
          ))}
        </Select>
        <SearchBox value={search} onChange={(next) => (view.search = next)} />
      </Box>

      {!shown.length ? (
        <BaseEmpty text={search.text ? undefined : t(kind === 'active' ? 'activity.connectionsEmpty' : 'activity.requestsEmpty')} />
      ) : layout === 'table' ? (
        <ConnectionTable connections={shown} onShowDetail={setDetail} />
      ) : (
        <VirtualList
          key={kind}
          count={shown.length}
          estimateSize={56}
          getItemKey={(i) => shown[i].id}
          renderItem={(i) => (
            <ConnectionRow connection={shown[i]} closed={kind === 'closed'} onShowDetail={setDetail} onCloseConnection={closeConnection} />
          )}
          style={{ flex: 1 }}
        />
      )}
      <ConnectionDetail connection={live} closed={kind === 'closed'} onClose={() => setDetail(null)} onCloseConnection={closeConnection} />
      <Zoom in={kind === 'closed' && shown.length > 0} unmountOnExit>
        <Fab
          size="medium"
          variant="extended"
          color="primary"
          disabled={clearing}
          sx={{ position: 'absolute', right: 16, bottom: 16 }}
          onClick={clearClosed}
        >
          <DeleteForeverRounded sx={{ mr: 1 }} fontSize="small" />
          {t('activity.clear')}
        </Fab>
      </Zoom>
    </BasePage>
  );
}
