// Follows Clash Verge Rev (GPL-3.0): src/pages/rules.tsx and components/rule/rule-item.tsx.
import { Box, Typography } from '@mui/material';
import { useEffect, useMemo, useState } from 'react';
import { proxy, useSnapshot } from 'valtio';
import { BaseEmpty, BasePage } from '../base';
import { emptySearch, SearchBox, useMatcher } from '../base/SearchBox';
import { invoke } from '../ipc';
import { t } from '../lib/i18n.js';
import { app } from '../state/core';
import { ProvidersButton } from './activity/ProvidersButton';
import { pageContentStyle, toolbarSx, VirtualList } from './activity/VirtualList';

const view = proxy({ search: emptySearch() });

const COLORS = ['primary.main', 'secondary.main', 'info.main', 'warning.main', 'success.main'];

function proxyColor(name: string) {
  if (name === 'REJECT' || name === 'REJECT-DROP') return 'error.main';
  if (name === 'DIRECT') return 'text.primary';
  let sum = 0;
  for (let i = 0; i < name.length; i++) sum += name.charCodeAt(i);
  return COLORS[sum % COLORS.length];
}

function RuleItem({ rule }: { rule: any }) {
  return (
    <Box sx={{ display: 'flex', px: 2, py: 0.5, borderBottom: '1px solid var(--divider-color)' }}>
      <Typography color="text.secondary" variant="body2" sx={{ lineHeight: 2, minWidth: 30, mr: 2.25, textAlign: 'center' }}>
        {rule.lineNo}
      </Typography>
      <Box className="selectable" sx={{ minWidth: 0 }}>
        <Typography component="h6" variant="subtitle1" color="text.primary" sx={{ overflowWrap: 'anywhere' }}>
          {rule.payload || '-'}
        </Typography>
        <Typography component="span" variant="body2" color="text.secondary" sx={{ mr: 3, minWidth: 120, display: 'inline-block' }}>
          {rule.kind}
        </Typography>
        <Typography component="span" variant="body2" sx={{ color: proxyColor(rule.proxy) }}>
          {rule.proxy}
        </Typography>
      </Box>
    </Box>
  );
}

export default function Rules() {
  const { search } = useSnapshot(view);
  const engineState = useSnapshot(app).status?.engine.state;
  const [rules, setRules] = useState<any[] | null>(null);
  const match = useMatcher(search);

  useEffect(() => {
    let stale = false;
    invoke<any[]>('rules').then(
      (list) => stale || setRules(list.map((rule, i) => ({ ...rule, lineNo: i + 1 }))),
      () => stale || setRules([]),
    );
    return () => void (stale = true);
  }, [engineState]);

  const shown = useMemo(
    () => (rules ?? []).filter((rule) => match(`${rule.kind} ${rule.payload} ${rule.proxy}`)),
    [rules, match],
  );

  return (
    <BasePage full title={t('nav.rules')} contentStyle={pageContentStyle} header={<ProvidersButton />}>
      <Box sx={toolbarSx}>
        <SearchBox value={search} placeholder={t('rules.search')} onChange={(next) => (view.search = next)} />
      </Box>
      {shown.length ? (
        <VirtualList
          count={shown.length}
          estimateSize={61}
          getItemKey={(i) => shown[i].lineNo}
          renderItem={(i) => <RuleItem rule={shown[i]} />}
          style={{ flex: 1 }}
        />
      ) : (
        rules && <BaseEmpty text={rules.length ? undefined : t('rules.empty')} />
      )}
    </BasePage>
  );
}
