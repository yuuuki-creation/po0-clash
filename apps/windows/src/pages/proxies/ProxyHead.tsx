// Follows Clash Verge Rev (GPL-3.0): src/components/proxy/proxy-head.tsx.
import {
  AccessTimeRounded,
  MyLocationRounded,
  NetworkCheckRounded,
  SearchOffRounded,
  SearchRounded,
  SortByAlphaRounded,
  SortRounded,
  VisibilityOffRounded,
  VisibilityRounded,
} from '@mui/icons-material';
import { Box, CircularProgress, IconButton } from '@mui/material';
import { memo } from 'react';
import { t } from '../../lib/i18n.js';

const SORTS = ['profile', 'delay', 'name'];
const sortIcons: Record<string, typeof SortRounded> = { profile: SortRounded, delay: AccessTimeRounded, name: SortByAlphaRounded };

interface Props {
  group: string;
  sort: string;
  showType: boolean;
  testing: boolean;
  canTest: boolean;
  filtering: boolean;
  onLocate: (group: string) => void;
  onTest: (group: string) => void;
  onSort: (sort: string) => void;
  onShowType: (show: boolean) => void;
  onFiltering: (group: string, on: boolean) => void;
}

export const ProxyHead = memo(function ProxyHead(props: Props) {
  const { group, sort, showType, testing, filtering } = props;
  const SortIcon = sortIcons[sort] ?? SortRounded;
  return (
    <Box sx={{ display: 'flex', alignItems: 'center', gap: 0, height: 36 }}>
      <IconButton size="small" color="inherit" title={t('proxies.locate')} onClick={() => props.onLocate(group)}>
        <MyLocationRounded />
      </IconButton>
      <IconButton size="small" color="inherit" title={t('proxies.test')} disabled={testing || !props.canTest} onClick={() => props.onTest(group)}>
        {testing ? <CircularProgress size={20} color="inherit" sx={{ m: '2px' }} /> : <NetworkCheckRounded />}
      </IconButton>
      <IconButton
        size="small"
        color="inherit"
        title={`${t('proxies.sort')} · ${t(`sort.${SORTS.includes(sort) ? sort : 'profile'}`)}`}
        onClick={() => props.onSort(SORTS[(SORTS.indexOf(sort) + 1) % SORTS.length])}
      >
        <SortIcon />
      </IconButton>
      <IconButton
        size="small"
        color="inherit"
        title={showType ? t('proxies.hideType') : t('proxies.showType')}
        onClick={() => props.onShowType(!showType)}
      >
        {showType ? <VisibilityRounded /> : <VisibilityOffRounded />}
      </IconButton>
      <IconButton size="small" color="inherit" title={t('proxies.filter')} onClick={() => props.onFiltering(group, !filtering)}>
        {filtering ? <SearchOffRounded /> : <SearchRounded />}
      </IconButton>

    </Box>
  );
});
