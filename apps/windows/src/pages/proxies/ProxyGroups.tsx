// Follows Clash Verge Rev (GPL-3.0): src/components/proxy/{proxy-groups,proxy-render,use-render-list}.
import { ExpandLessRounded, ExpandMoreRounded, InboxRounded } from '@mui/icons-material';
import { alpha, Box, Chip, ListItemButton, styled, TextField, Typography } from '@mui/material';
import { useVirtualizer } from '@tanstack/react-virtual';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useSnapshot } from 'valtio';
import { BaseEmpty } from '../../base';
import { t } from '../../lib/i18n.js';
import { act, app, isRunning, isTestingNode, rankDelay, resolvedDelay, testDelay, testNode } from '../../state/core';
import { settings, updateSettings } from '../../state/settings';
import { GroupIcon } from './GroupIcon';
import { ProxyHead } from './ProxyHead';
import { ProxyItem } from './ProxyItem';
import { TILE_GAP, TILE_HEIGHT, toggleGroup, view } from './state';

type Row =
  | { type: 'group'; key: string; group: any; open: boolean }
  | { type: 'nodes'; key: string; group: any; nodes: any[] }
  | { type: 'empty'; key: string; group: any };

const GROUP_HEIGHT = 72;
const EMPTY_HEIGHT = 96;

function useColumns() {
  const ref = useRef<HTMLDivElement>(null);
  const [columns, setColumns] = useState(3);
  useEffect(() => {
    const element = ref.current;
    if (!element) return;
    const fit = () => setColumns(Math.max(1, Math.min(6, Math.floor((element.clientWidth - 32) / 200))));
    fit();
    const observer = new ResizeObserver(fit);
    observer.observe(element);
    return () => observer.disconnect();
  }, []);
  return [ref, columns] as const;
}

const onSelect = (group: string, node: string) => {
  const found = app.groups.find((g) => g.name === group);
  if (!found?.selectable || app.busy[`select:${group}`]) return;
  if (found.now === node && found.kind === 'Selector') return;
  act(`select:${group}`, 'select_node', { group, node });
};
const onSort = (proxiesSort: string) => updateSettings({ proxiesSort });
const onShowType = (show: boolean) => updateSettings({ proxyTileStyle: show ? 'detailed' : 'compact' });
const onLocate = (group: string) => {
  delete view.filter[group];
  view.locate = group;
};
const onFiltering = (group: string, on: boolean) => {
  view.filtering[group] = on;
  if (on) view.open[group] = true;
  if (!on) delete view.filter[group];
};
const onFilter = (group: string, text: string) => (view.filter[group] = text);

export function ProxyGroups() {
  const { groups, busy, status } = useSnapshot(app);
  const s = useSnapshot(settings).value;
  const v = useSnapshot(view);
  const [scroller, columns] = useColumns();

  const sort = s.proxiesSort;
  const showType = s.proxyTileStyle === 'detailed';
  const tile = TILE_HEIGHT[s.proxiesDensity] ?? TILE_HEIGHT.standard;
  const gap = TILE_GAP[s.proxiesDensity] ?? TILE_GAP.standard;
  const query = v.query.trim().toLowerCase();
  const { open, filter, filtering } = v;

  const nowOf = useMemo(() => new Map<string, string>(groups.map((g) => [g.name, g.now])), [groups]);

  const rows = useMemo(() => {
    const list: Row[] = [];
    const hit = (text: string, needle: string) => text.toLowerCase().includes(needle);
    for (const group of groups) {
      const groupHit = !query || hit(group.name, query);
      let nodes: any[] = groupHit ? group.nodes : group.nodes.filter((node: any) => hit(node.name, query));
      if (!groupHit && !nodes.length) continue;
      const isOpen = !!query || !!open[group.name];
      list.push({ type: 'group', key: `g:${group.name}`, group, open: isOpen });
      if (!isOpen) continue;
      const needle = filter[group.name]?.trim().toLowerCase();
      if (needle) nodes = nodes.filter((node) => hit(node.name, needle));
      if (sort === 'name') nodes = [...nodes].sort((a, b) => a.name.localeCompare(b.name));
      if (sort === 'delay') {
        const rank = new Map(nodes.map((node) => [node, rankDelay(resolvedDelay(node, groups))]));
        nodes = [...nodes].sort((a, b) => rank.get(a)! - rank.get(b)!);
      }
      if (!nodes.length) list.push({ type: 'empty', key: `e:${group.name}`, group });
      for (let i = 0; i < nodes.length; i += columns) {
        list.push({ type: 'nodes', key: `n:${group.name}:${i / columns}`, group, nodes: nodes.slice(i, i + columns) });
      }
    }
    return list;
  }, [groups, query, open, filter, sort, columns]);

  const estimateSize = useCallback(
    (index: number) => {
      const type = rows[index].type;
      return type === 'group' ? GROUP_HEIGHT + (filtering[rows[index].group.name] ? 40 : 0) : type === 'empty' ? EMPTY_HEIGHT : tile + gap;
    },
    [rows, tile, gap, filtering],
  );
  const getItemKey = useCallback((index: number) => rows[index].key, [rows]);
  const virtualizer = useVirtualizer({
    count: rows.length,
    getScrollElement: () => scroller.current,
    estimateSize,
    getItemKey,
    overscan: 6,
    paddingStart: 6,
    paddingEnd: 12,
  });
  useEffect(() => virtualizer.measure(), [virtualizer, estimateSize]);

  useEffect(() => {
    const name = v.locate;
    if (!name) return;
    const group = rows.find((row) => row.type === 'group' && row.group.name === name)?.group;
    const node = rows.findIndex(
      (row) => row.type === 'nodes' && row.group.name === name && row.nodes.some((n) => n.name === group?.now),
    );
    const index = node >= 0 ? node : rows.findIndex((row) => row.type === 'group' && row.group.name === name);
    if (index >= 0) virtualizer.scrollToIndex(index, { align: node >= 0 ? 'center' : 'start' });
    view.locate = null;
  }, [v.locate, rows, virtualizer]);

  const groupTesting = (group: any) =>
    !!busy[`delay:${group.name}`] || group.nodes.some((node: any) => busy[`node:${node.name}`]);

  function render(row: Row) {
    const { group } = row;
    if (row.type === 'group') {
      return (
        <Box sx={{ p: '4px 8px', height: '100%' }}>
          <Box sx={{ height: '100%', borderRadius: 2, bgcolor: 'surface.card' }}>
          <ListItemButton
            dense
            disabled={!!query}
            aria-expanded={row.open}
            aria-label={`${row.open ? t('proxies.collapse') : t('proxies.expand')} · ${group.name}`}
            onClick={() => toggleGroup(group.name)}
            sx={{ height: 64, borderRadius: 2, '&.Mui-disabled': { opacity: 1 } }}
          >
            <Box sx={{ display: 'flex', alignItems: 'center', minWidth: 0, flex: '1 1 auto' }}>
              <GroupIcon icon={group.icon} style={s.groupIconStyle}>
                <Box sx={{ minWidth: 0, display: 'flex', flexDirection: 'column' }}>
                  <GroupName>{group.name}</GroupName>
                  <Box sx={{ display: 'flex', alignItems: 'center', pt: '2px', minWidth: 0 }}>
                    <GroupType>{group.kind}</GroupType>
                    <Typography noWrap sx={{ fontSize: 13, color: 'text.secondary' }}>
                      {group.now}
                    </Typography>
                  </Box>
                </Box>
              </GroupIcon>
            </Box>
            <Box onClick={(event) => event.stopPropagation()} onKeyDown={(event) => event.stopPropagation()} sx={{ flex: 'none' }}>
              <ProxyHead group={group.name} sort={sort} showType={showType} testing={groupTesting(group)} canTest={isRunning(status)} filtering={!!filtering[group.name]}
                onLocate={onLocate} onTest={testDelay} onSort={onSort} onShowType={onShowType} onFiltering={onFiltering} />
            </Box>
            <Chip
              size="small"
              label={group.nodes.length}
              sx={({ palette }) => ({ mx: 1, bgcolor: alpha(palette.primary.main, 0.1), color: 'primary.main' })}
            />
            {row.open ? <ExpandLessRounded /> : <ExpandMoreRounded />}
          </ListItemButton>
          {filtering[group.name] && (
            <Box sx={{ px: 2, pb: 1 }}>
              <TextField autoFocus fullWidth size="small" value={filter[group.name] ?? ''} placeholder={t('proxies.filter')}
                slotProps={{ htmlInput: { 'aria-label': `${t('proxies.filter')} · ${group.name}` } }}
                onChange={(event) => onFilter(group.name, event.target.value)} sx={{ input: { py: 0.65 } }} />
            </Box>
          )}
          </Box>
        </Box>
      );
    }
    if (row.type === 'empty') {
      return (
        <Box sx={{ py: 2, display: 'flex', flexDirection: 'column', alignItems: 'center', color: 'text.secondary' }}>
          <InboxRounded sx={{ fontSize: '2.5em' }} />
          <Typography>{t('proxies.noMatch')}</Typography>
        </Box>
      );
    }
    return (
      <Box sx={{ height: tile, display: 'grid', gap: 1, px: 2, gridTemplateColumns: `repeat(${columns}, minmax(0, 1fr))` }}>
        {row.nodes.map((node, i) => (
          <ProxyItem
            key={i}
            group={group.name}
            name={node.name}
            kind={node.kind}
            now={nowOf.get(node.name)}
            delay={resolvedDelay(node, groups)}
            testing={isTestingNode(node.name, busy, groups)}
            selected={node.name === group.now}
            readOnly={!group.selectable}
            canTest={isRunning(status)}
            showType={showType}
            height={tile}
            onSelect={onSelect}
            onTest={testNode}
          />
        ))}
      </Box>
    );
  }

  return (
    <Box ref={scroller} sx={{ height: '100%', overflowY: 'auto', scrollbarGutter: 'stable' }}>
      {rows.length ? (
        <Box sx={{ position: 'relative', height: virtualizer.getTotalSize() }}>
          {virtualizer.getVirtualItems().map((item) => (
            <Box
              key={item.key}
              sx={{ position: 'absolute', top: 0, left: 0, width: '100%', height: item.size }}
              style={{ transform: `translateY(${item.start}px)` }}
            >
              {render(rows[item.index])}
            </Box>
          ))}
        </Box>
      ) : (
        <BaseEmpty text={t('proxies.noMatch')} />
      )}
    </Box>
  );
}

const GroupName = styled('span')({
  fontSize: 16,
  fontWeight: 700,
  lineHeight: 1.5,
  overflow: 'hidden',
  textOverflow: 'ellipsis',
  whiteSpace: 'nowrap',
});

const GroupType = styled('span')(({ theme }) => ({
  display: 'inline-block',
  flex: 'none',
  border: `1px solid ${alpha(theme.palette.primary.main, 0.5)}`,
  color: alpha(theme.palette.primary.main, 0.8),
  borderRadius: 4,
  fontSize: 10,
  padding: '0 4px',
  lineHeight: 1.5,
  marginRight: 8,
}));
