// Follows Clash Verge Rev (GPL-3.0): src/components/proxy/proxy-item-mini.tsx.
import { CheckCircleOutlineRounded } from '@mui/icons-material';
import { alpha, Box, CircularProgress, ListItemButton, styled, Typography } from '@mui/material';
import { memo, type KeyboardEvent, type MouseEvent } from 'react';
import { formatDelay, t } from '../../lib/i18n.js';
import { delayColor } from './state';

interface Props {
  group: string;
  name: string;
  kind: string;
  /** For a group listed as a node: the node that group routes to. */
  now?: string;
  delay: number | null;
  testing: boolean;
  selected: boolean;
  readOnly: boolean;
  canTest: boolean;
  showType: boolean;
  height: number;
  onSelect: (group: string, node: string) => void;
  onTest: (node: string) => void;
}

const clip = { display: 'block', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' } as const;

export const ProxyItem = memo(function ProxyItem(props: Props) {
  const { group, name, kind, now, delay, testing, selected, readOnly, showType, height, onSelect, onTest } = props;
  const test = (event: MouseEvent) => {
    event.preventDefault();
    event.stopPropagation();
    onTest(name);
  };
  const quiet = (event: MouseEvent) => event.stopPropagation();
  const keyTest = (event: KeyboardEvent) => {
    if (event.key !== 'Enter' && event.key !== ' ') return;
    event.preventDefault();
    event.stopPropagation();
    onTest(name);
  };

  return (
    <ListItemButton
      dense
      selected={selected}
      disableRipple={readOnly}
      aria-pressed={selected}
      onClick={() => !readOnly && onSelect(group, name)}
      sx={[
        { height, borderRadius: 1.5, pl: 1.5, pr: 1, justifyContent: 'space-between', alignItems: 'center', bgcolor: 'surface.card' },
        readOnly && { cursor: 'default', '&:hover': { bgcolor: 'surface.card' } },
        ({ palette: { mode, primary } }) => ({
          '& .the-check': { display: 'none' },
          '&:hover .the-check': { display: 'block' },
          '&:hover .the-icon': { display: 'none' },
          '&.Mui-selected': {
            width: 'calc(100% + 3px)',
            marginLeft: '-3px',
            borderLeft: `3px solid ${mode === 'light' ? primary.main : primary.light}`,
            bgcolor: alpha(primary.main, mode === 'light' ? 0.15 : 0.35),
          },
        }),
      ]}
    >
      <Box title={now ? `${name}\n${now}` : name} sx={{ overflow: 'hidden', minWidth: 0 }}>
        <Typography variant="body2" component="div" color="text.primary" sx={clip}>
          {name}
        </Typography>
        {showType && (
          <Box sx={{ display: 'flex', flexWrap: 'nowrap', mt: '4px', minWidth: 0 }}>
            {now && (
              <Typography variant="body2" component="div" color="text.secondary" sx={{ ...clip, mr: 1, fontSize: 12 }}>
                {now}
              </Typography>
            )}
            <TypeBox>{kind}</TypeBox>
          </Box>
        )}
      </Box>
      <Box sx={{ ml: 0.5, flex: 'none', color: 'primary.main', display: props.canTest ? undefined : 'none' }}>
        {testing ? (
          <Widget sx={{ display: 'flex' }}>
            <CircularProgress size={14} />
          </Widget>
        ) : delay != null ? (
          <Widget
            role="button"
            tabIndex={0}
            aria-label={t('proxies.testNode')}
            onKeyDown={keyTest}
            title={t('proxies.testNode')}
            onClick={test}
            onMouseDown={quiet}
            sx={({ palette }) => ({ color: delayColor(delay), cursor: 'pointer', ':hover': { bgcolor: alpha(palette.primary.main, 0.15) } })}
          >
            {formatDelay(delay)}
          </Widget>
        ) : (
          <>
            <Widget
              className="the-check"
              role="button"
              tabIndex={0}
              aria-label={t('proxies.testNode')}
              onKeyDown={keyTest}
              title={t('proxies.testNode')}
              onClick={test}
              onMouseDown={quiet}
              sx={({ palette }) => ({ cursor: 'pointer', ':hover': { bgcolor: alpha(palette.primary.main, 0.15) } })}
            >
              {t('proxies.check')}
            </Widget>
            {selected && <CheckCircleOutlineRounded className="the-icon" sx={{ fontSize: 16, mr: 0.5, display: 'block' }} />}
          </>
        )}
      </Box>
    </ListItemButton>
  );
});

const Widget = styled(Box)({ padding: '2px 4px', fontSize: 14, borderRadius: 4, whiteSpace: 'nowrap' });

const TypeBox = styled('span')(({ theme }) => ({
  display: 'inline-block',
  flex: 'none',
  border: `1px solid ${alpha(theme.palette.text.secondary, 0.36)}`,
  color: theme.palette.text.secondary,
  borderRadius: 4,
  fontSize: 10,
  marginRight: 4,
  padding: '0 4px',
  lineHeight: 1.5,
}));
