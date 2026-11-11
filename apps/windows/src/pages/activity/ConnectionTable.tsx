// Follows Clash Verge Rev (GPL-3.0): src/components/connection/connection-table.tsx.
import { useTheme } from '@mui/material';
import { useVirtualizer } from '@tanstack/react-virtual';
import { memo, useRef } from 'react';
import { formatAgo, formatBytes, t } from '../../lib/i18n.js';

export const hostOf = (c: any) => c.host || c.destination;
export const ruleOf = (c: any) => (c.rulePayload ? `${c.rule}(${c.rulePayload})` : c.rule);
export const chainOf = (c: any) => c.chains.toReversed().join(' / ');
export const typeOf = (c: any) => `${c.inbound}(${c.network})`;

interface Column {
  key: string;
  label: () => string;
  width: number;
  align?: 'right';
  value: (c: any) => string;
}

const columns: Column[] = [
  { key: 'host', label: () => t('activity.host'), width: 220, value: hostOf },
  { key: 'download', label: () => t('home.downloaded'), width: 88, align: 'right', value: (c) => formatBytes(c.download) },
  { key: 'upload', label: () => t('home.uploaded'), width: 88, align: 'right', value: (c) => formatBytes(c.upload) },
  { key: 'chains', label: () => t('activity.chain'), width: 240, value: chainOf },
  { key: 'rule', label: () => t('activity.rule'), width: 200, value: ruleOf },
  { key: 'process', label: () => t('activity.process'), width: 140, value: (c) => c.process ?? '' },
  { key: 'time', label: () => t('activity.time'), width: 110, align: 'right', value: (c) => formatAgo(c.start) },
  { key: 'destination', label: () => t('conn.destination'), width: 170, value: (c) => c.destination },
  { key: 'source', label: () => t('conn.source'), width: 150, value: (c) => c.source },
  { key: 'type', label: () => t('conn.type'), width: 130, value: typeOf },
];

const ROW_HEIGHT = 40;
const HEADER_HEIGHT = 37;
const tableWidth = columns.reduce((sum, column) => sum + column.width, 0);

const cellStyle = (column: Column) =>
  ({
    boxSizing: 'border-box',
    flex: `${column.key === 'host' ? 1 : 0} 0 ${column.width}px`,
    minWidth: 0,
    padding: 8,
    fontSize: 13,
    textAlign: column.align ?? 'left',
    whiteSpace: 'nowrap',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
  }) as const;

const Row = memo(function Row({ connection, top, onShowDetail }: { connection: any; top: number; onShowDetail: (c: any) => void }) {
  return (
    <div
      data-conn-row
      style={{
        display: 'flex',
        alignItems: 'center',
        position: 'absolute',
        top,
        left: 0,
        right: 0,
        height: ROW_HEIGHT,
        cursor: 'pointer',
        borderBottom: '1px solid var(--divider-color)',
      }}
      onClick={() => onShowDetail(connection)}
    >
      {columns.map((column) => (
        <div key={column.key} style={cellStyle(column)}>
          {column.value(connection)}
        </div>
      ))}
    </div>
  );
});

export function ConnectionTable({ connections, onShowDetail }: { connections: any[]; onShowDetail: (c: any) => void }) {
  const theme = useTheme();
  const scrollRef = useRef<HTMLDivElement>(null);
  const virtualizer = useVirtualizer({
    count: connections.length,
    getScrollElement: () => scrollRef.current,
    estimateSize: () => ROW_HEIGHT,
    overscan: 6,
    scrollMargin: HEADER_HEIGHT,
    getItemKey: (i) => connections[i].id,
  });

  return (
    <div ref={scrollRef} style={{ flex: 1, minHeight: 0, overflow: 'auto', overscrollBehavior: 'contain' }}>
      <div style={{ minWidth: '100%', width: tableWidth }}>
        <div
          style={{
            display: 'flex',
            position: 'sticky',
            top: 0,
            zIndex: 2,
            height: HEADER_HEIGHT,
            boxSizing: 'border-box',
            alignItems: 'center',
            borderBottom: `1px solid ${theme.palette.divider}`,
            backgroundColor: theme.palette.background.paper,
            color: theme.palette.text.secondary,
            fontWeight: 600,
          }}
        >
          {columns.map((column) => (
            <div key={column.key} style={cellStyle(column)}>
              {column.label()}
            </div>
          ))}
        </div>
        <div style={{ position: 'relative', height: virtualizer.getTotalSize() }}>
          {virtualizer.getVirtualItems().map((item) => (
            <Row key={item.key} connection={connections[item.index]} top={item.start - HEADER_HEIGHT} onShowDetail={onShowDetail} />
          ))}
        </div>
      </div>
    </div>
  );
}
