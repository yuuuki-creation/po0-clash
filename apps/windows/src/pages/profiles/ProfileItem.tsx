// Follows Clash Verge Rev (GPL-3.0): src/components/profile/{profile-item,profile-box}.tsx.
import { DragIndicatorRounded, MoreVertRounded, RefreshRounded } from '@mui/icons-material';
import { alpha, Box, CircularProgress, IconButton, keyframes, LinearProgress, styled, Typography } from '@mui/material';
import { memo, type DragEvent, type MouseEvent } from 'react';
import { formatAgo, formatDate, formatTime, formatUsage, t } from '../../lib/i18n.js';

export const profileTitle = (profile: any) => (profile.kind === 'links' ? t('profiles.links') : profile.name);

function source(profile: any, nodeCount?: number) {
  if (profile.kind === 'links') return nodeCount == null ? '' : t('nodes.count', { count: nodeCount });
  if (profile.kind !== 'subscription' || !profile.url) return t('profiles.local');
  try {
    return new URL(profile.url).host;
  } catch {
    return profile.url;
  }
}

const tip = (profile: any) =>
  [
    profile.updatedAt && t('profiles.updated', { time: formatTime(profile.updatedAt) }),
    profile.kind === 'subscription' && profile.autoUpdate && t('profiles.autoUpdateEvery', { hours: profile.updateHours }),
  ]
    .filter(Boolean)
    .join(' · ');

const round = keyframes`from { transform: rotate(0deg); } to { transform: rotate(360deg); }`;

const ProfileBox = styled(Box)(({ theme, 'aria-selected': selected }) => {
  const { mode, primary, text } = theme.palette;
  return {
    position: 'relative',
    display: 'block',
    cursor: 'pointer',
    textAlign: 'left',
    padding: '8px 16px',
    boxSizing: 'border-box',
    backgroundColor: theme.palette.surface.card,
    width: '100%',
    ...(selected && { borderLeft: `3px solid ${primary.main}`, width: 'calc(100% + 3px)', marginLeft: '-3px' }),
    borderRadius: 8,
    color: mode === 'light' ? text.secondary : alpha(text.secondary, 0.65),
    '& h2': { color: selected ? primary.main : text.primary },
  };
});

const line = { height: 26, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 1, fontSize: 14 } as const;

interface Props {
  profile: any;
  nodeCount?: number;
  activating: boolean;
  updating: boolean;
  reorderable: boolean;
  dragging: boolean;
  dropTarget: boolean;
  onSelect: (profile: any) => void;
  onUpdate: (profile: any) => void;
  onMenu: (profile: any, position: { top: number; left: number }) => void;
  onDragStart: (id: string) => void;
  onDragOver: (id: string) => void;
  onDrop: (id: string) => void;
  onDragEnd: () => void;
}

export const ProfileItem = memo(function ProfileItem(props: Props) {
  const { profile, nodeCount, activating, updating, reorderable, dragging, dropTarget } = props;
  const remote = profile.kind === 'subscription';
  const usage = profile.usage;
  const used = usage ? usage.upload + usage.download : 0;
  const total = usage?.total ?? 0;
  const name = profileTitle(profile);

  const menu = (event: MouseEvent, position: { top: number; left: number }) => {
    event.preventDefault();
    event.stopPropagation();
    props.onMenu(profile, position);
  };

  return (
    <Box
      draggable={reorderable}
      onDragStart={(event: DragEvent) => {
        event.dataTransfer.effectAllowed = 'move';
        props.onDragStart(profile.id);
      }}
      onDragOver={(event: DragEvent) => {
        event.preventDefault();
        props.onDragOver(profile.id);
      }}
      onDrop={(event: DragEvent) => {
        event.preventDefault();
        props.onDrop(profile.id);
      }}
      onDragEnd={props.onDragEnd}
      sx={{
        position: 'relative',
        borderRadius: 2,
        opacity: dragging ? 0.4 : 1,
        outline: dropTarget ? 2 : 0,
        outlineStyle: 'dashed',
        outlineColor: 'primary.main',
      }}
    >
      <ProfileBox
        aria-selected={profile.selected}
        aria-label={`${t('profiles.use')} · ${name}`}
        onClick={() => !activating && props.onSelect(profile)}
        onContextMenu={(event) => menu(event, { top: event.clientY, left: event.clientX })}
      >
        {activating && (
          <Box
            sx={{
              position: 'absolute',
              inset: 0,
              zIndex: 10,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              borderRadius: 'inherit',
              backdropFilter: 'blur(2px)',
              bgcolor: 'rgba(0, 0, 0, 0.1)',
            }}
          >
            <CircularProgress color="inherit" size={20} />
          </Box>
        )}
        <Box sx={{ display: 'flex', alignItems: 'center' }}>
          {reorderable && (
            <Box title={t('profiles.reorder')} sx={{ display: 'flex', flex: 'none' }}>
              <DragIndicatorRounded sx={{ cursor: 'move', ml: '-6px', color: 'text.primary' }} />
            </Box>
          )}
          <Typography variant="h6" component="h2" noWrap title={name} sx={{ flex: 1, minWidth: 0, fontSize: 18, fontWeight: 600, lineHeight: '26px' }}>
            {name}
          </Typography>
          {remote && (
            <IconButton
              size="small"
              color="inherit"
              title={t('profiles.update')}
              disabled={updating}
              sx={{ p: '3px', animation: updating ? `1s linear infinite ${round}` : 'none' }}
              onClick={(event) => {
                event.stopPropagation();
                if (!activating) props.onUpdate(profile);
              }}
            >
              <RefreshRounded color="inherit" />
            </IconButton>
          )}
          <IconButton
            size="small"
            color="inherit"
            title={t('profiles.more')}
            sx={{ p: '3px', mr: '-8px' }}
            onClick={(event) => {
              const box = event.currentTarget.getBoundingClientRect();
              menu(event, { top: box.bottom, left: box.left });
            }}
          >
            <MoreVertRounded color="inherit" />
          </IconButton>
        </Box>
        <Box sx={line}>
          <Typography noWrap sx={{ fontSize: 14 }}>
            {source(profile, nodeCount)}
          </Typography>
          {remote && profile.updatedAt && (
            <Typography noWrap component="span" title={tip(profile)} sx={{ fontSize: 14, flex: 'none' }}>
              {formatAgo(profile.updatedAt)}
            </Typography>
          )}
        </Box>
        {total > 0 ? (
          <Box sx={line}>
            <span>{formatUsage(used, total)}</span>
            <span>{usage.expire ? formatDate(usage.expire) : ''}</span>
          </Box>
        ) : (
          <Box sx={{ ...line, fontSize: 12, justifyContent: 'flex-end' }}>
            <span>{profile.updatedAt ? formatTime(profile.updatedAt) : ''}</span>
          </Box>
        )}
        <LinearProgress variant="determinate" value={total > 0 ? Math.min(100, (used / total) * 100) : 0} style={{ opacity: total > 0 ? 1 : 0 }} />
      </ProfileBox>
    </Box>
  );
});
