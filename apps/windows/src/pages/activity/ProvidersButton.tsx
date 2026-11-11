// Follows Clash Verge Rev (GPL-3.0): src/components/rule/provider-button.tsx and proxy/provider-button.tsx.
import { RefreshRounded, StorageOutlined } from '@mui/icons-material';
import { alpha, Box, Button, Divider, IconButton, LinearProgress, styled, Typography } from '@mui/material';
import { useCallback, useEffect, useState } from 'react';
import { useSnapshot } from 'valtio';
import { BaseDialog, BaseEmpty } from '../../base';
import { invoke } from '../../ipc';
import { formatAgo, formatDate, formatUsage, t } from '../../lib/i18n.js';
import { act, app } from '../../state/core';

const TypeBox = styled('span')(({ theme }) => ({
  display: 'inline-block',
  border: '1px solid',
  borderColor: alpha(theme.palette.secondary.main, 0.5),
  color: alpha(theme.palette.secondary.main, 0.8),
  borderRadius: 4,
  fontSize: 10,
  marginRight: 4,
  padding: '0 2px',
  lineHeight: 1.25,
}));

const busyKey = (provider: any) => `provider:${provider.kind}:${provider.name}`;
const updatable = (provider: any) => provider.vehicle === 'HTTP';

function ProviderItem({ provider, onUpdate }: { provider: any; onUpdate: (provider: any) => void }) {
  const busy = !!useSnapshot(app).busy[busyKey(provider)];
  const usage = provider.usage;
  const used = usage ? usage.upload + usage.download : 0;

  return (
    <Box
      sx={({ palette }) => ({
        display: 'flex',
        mb: 1,
        borderRadius: 2,
        overflow: 'hidden',
        transition: 'background-color 0.2s',
        bgcolor: palette.mode === 'light' ? 'background.paper' : alpha(palette.common.white, 0.04),
        '&:hover': { bgcolor: alpha(palette.primary.main, palette.mode === 'light' ? 0.1 : 0.2) },
      })}
    >
      <Box sx={{ flex: 1, minWidth: 0, px: 2, py: 1 }}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 1 }}>
          <Typography variant="subtitle1" component="div" noWrap title={provider.name} sx={{ minWidth: 0 }}>
            <span className="selectable" style={{ marginRight: 8 }}>
              {provider.name}
            </span>
            <TypeBox>{t('prov.count', { count: provider.count })}</TypeBox>
          </Typography>
          {provider.updatedAt && (
            <Typography variant="body2" color="text.secondary" noWrap sx={{ flexShrink: 0 }}>
              {t('home.updated', { ago: formatAgo(provider.updatedAt) })}
            </Typography>
          )}
        </Box>
        <Box sx={{ display: 'flex', mt: 0.25 }}>
          <TypeBox>{provider.vehicle}</TypeBox>
          {provider.behavior && <TypeBox>{provider.behavior}</TypeBox>}
        </Box>
        {usage?.total > 0 && (
          <Box sx={{ mt: 0.75, color: 'text.secondary', fontSize: 13 }}>
            <Box sx={{ mb: 0.5, display: 'flex', justifyContent: 'space-between' }}>
              <span>{formatUsage(used, usage.total)}</span>
              {usage.expire ? <span>{formatDate(usage.expire)}</span> : null}
            </Box>
            <LinearProgress variant="determinate" value={Math.min(100, (used / usage.total) * 100)} sx={{ height: 6, borderRadius: 3 }} />
          </Box>
        )}
      </Box>
      {updatable(provider) && (
        <>
          <Divider orientation="vertical" flexItem />
          <Box sx={{ width: 40, display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
            <IconButton
              size="small"
              color="primary"
              disabled={busy}
              title={t('prov.update')}
              aria-label={t('prov.update')}
              onClick={() => onUpdate(provider)}
              sx={{
                animation: busy ? 'provider-spin 1s linear infinite' : 'none',
                '@keyframes provider-spin': { from: { transform: 'rotate(0deg)' }, to: { transform: 'rotate(360deg)' } },
              }}
            >
              <RefreshRounded />
            </IconButton>
          </Box>
        </>
      )}
    </Box>
  );
}

export function ProvidersButton() {
  const engineState = useSnapshot(app).status?.engine.state;
  const [open, setOpen] = useState(false);
  const [providers, setProviders] = useState<any[] | null>(null);
  const [updatingAll, setUpdatingAll] = useState(false);

  const load = useCallback(
    () =>
      invoke<any[]>('providers').then(
        (list) => setProviders(list),
        () => setProviders([]),
      ),
    [],
  );

  useEffect(() => {
    if (open) load();
  }, [open, engineState, load]);

  const update = async (provider: any) => {
    await act(busyKey(provider), 'update_provider', { kind: provider.kind, name: provider.name });
    await load();
  };

  const updateAll = async () => {
    setUpdatingAll(true);
    for (const provider of (providers ?? []).filter(updatable)) {
      await act(busyKey(provider), 'update_provider', { kind: provider.kind, name: provider.name });
    }
    await load();
    setUpdatingAll(false);
  };

  const sections = ['proxy', 'rule']
    .map((kind) => ({ kind, items: (providers ?? []).filter((provider) => provider.kind === kind) }))
    .filter((section) => section.items.length);

  return (
    <>
      <Button variant="outlined" size="small" startIcon={<StorageOutlined />} onClick={() => setOpen(true)}>
        {t('prov.title')}
      </Button>
      <BaseDialog
        open={open}
        title={
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            {t('prov.title')}
            <Button
              variant="contained"
              size="small"
              loading={updatingAll}
              disabled={!providers?.some(updatable)}
              onClick={updateAll}
            >
              {t('prov.updateAll')}
            </Button>
          </Box>
        }
        contentSx={{ width: 'min(520px, calc(100vw - 112px))', minHeight: 250, pb: 0 }}
        disableOk
        cancelBtn={t('common.close')}
        onCancel={() => setOpen(false)}
      >
        {providers && !sections.length && <BaseEmpty text={t('prov.empty')} />}
        {sections.map((section) => (
          <Box key={section.kind} sx={{ mb: 1 }}>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 0.75, fontWeight: 600 }}>
              {t(`prov.${section.kind}`)}
            </Typography>
            {section.items.map((provider) => (
              <ProviderItem key={provider.name} provider={provider} onUpdate={update} />
            ))}
          </Box>
        ))}
      </BaseDialog>
    </>
  );
}
