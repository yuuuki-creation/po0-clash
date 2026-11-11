import { DeleteRounded } from '@mui/icons-material';
import { alpha, Box, Button, Chip, IconButton, styled, TextField, Typography } from '@mui/material';
import { useState } from 'react';
import { useSnapshot } from 'valtio';
import { BaseDialog, BaseEmpty, BasePage, Switch } from '../base';
import { formatAgo, formatTime, t } from '../lib/i18n.js';
import { act, app, notify } from '../state/core';

const outcomeColor: Record<string, 'success' | 'warning' | 'error' | 'default'> = {
  applied: 'success',
  notApplied: 'warning',
  disabled: 'default',
  rejected: 'error',
  error: 'error',
};

const KindBox = styled('span')(({ theme }) => ({
  display: 'inline-block',
  border: '1px solid',
  borderColor: alpha(theme.palette.secondary.main, 0.5),
  color: alpha(theme.palette.secondary.main, 0.8),
  borderRadius: 4,
  fontSize: 10,
  padding: '0 4px',
  lineHeight: 1.4,
  textTransform: 'uppercase',
  flexShrink: 0,
}));

function Entry({ entry, enabled, onRemove }: { entry: any; enabled: boolean; onRemove: (entry: any) => void }) {
  const busy = !!useSnapshot(app).busy[`wl:remove:${entry.id}`];
  const result = entry.result;
  const outcome = !enabled ? 'disabled' : result?.outcome;

  return (
    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5, mb: 1, px: 2, py: 1.25, borderRadius: 2, bgcolor: 'surface.card' }}>
      <Box sx={{ flex: 1, minWidth: 0 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <KindBox>{entry.kind}</KindBox>
          <Typography variant="subtitle1" noWrap title={entry.name || entry.label} sx={{ minWidth: 0 }}>
            {entry.name || entry.label}
          </Typography>
        </Box>
        <Typography variant="body2" color="text.secondary" noWrap sx={{ mt: 0.25 }}>
          {[entry.name ? entry.label : '', enabled && result ? t('whitelist.checked', { ago: formatAgo(result.at) }) : '']
            .filter(Boolean)
            .join(' · ') || ' '}
        </Typography>
        {result?.message && (
          <Typography className="selectable" variant="body2" sx={{ color: 'error.main', mt: 0.25, overflowWrap: 'anywhere' }}>
            {result.message}
          </Typography>
        )}
      </Box>
      {enabled && result?.ip && (
        <Typography className="selectable" variant="body2" sx={{ flexShrink: 0, fontVariantNumeric: 'tabular-nums' }}>
          {result.ip}
        </Typography>
      )}
      <Chip
        size="small"
        variant="outlined"
        color={outcome ? outcomeColor[outcome] : 'default'}
        title={enabled && result ? formatTime(result.at) : undefined}
        label={outcome ? t(`outcome.${outcome}`) : t('whitelist.pending')}
        sx={{ flexShrink: 0 }}
      />
      <IconButton
        size="small"
        color="inherit"
        disabled={busy}
        title={t('whitelist.remove')}
        aria-label={t('whitelist.remove')}
        onClick={() => onRemove(entry)}
      >
        <DeleteRounded fontSize="small" />
      </IconButton>
    </Box>
  );
}

export default function Whitelist() {
  const snap = useSnapshot(app);
  const { enabled, entries } = snap.whitelist;
  const [adding, setAdding] = useState(false);
  const [removing, setRemoving] = useState<any | null>(null);
  const [text, setText] = useState('');
  const [name, setName] = useState('');

  const applied = entries.filter((entry) => entry.result?.outcome === 'applied').length;

  async function add() {
    const count = await act<number>('wl:add', 'add_whitelist_entries', { text, name });
    if (count === undefined) return;
    setText('');
    setName('');
    setAdding(false);
    notify(t('whitelist.added', { count }), '', 'success');
  }

  function remove() {
    act(`wl:remove:${removing.id}`, 'remove_whitelist_entry', { id: removing.id });
    setRemoving(null);
  }

  return (
    <BasePage
      title={t('nav.whitelist')}
      header={
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1.5 }}>
          <Switch
            checked={enabled}
            disabled={!!snap.busy['wl:enabled']}
            slotProps={{ input: { 'aria-label': t('whitelist.enabled') } }}
            title={t('whitelist.enabled')}
            onChange={(_, checked) => act('wl:enabled', 'set_whitelist_enabled', { enabled: checked })}
          />
          <Button
            size="small"
            variant="outlined"
            disabled={!entries.length || !enabled}
            loading={!!snap.busy['wl:now']}
            onClick={() => act('wl:now', 'whitelist_now')}
          >
            {t('whitelist.now')}
          </Button>
          <Button size="small" variant="contained" onClick={() => setAdding(true)}>
            {t('whitelist.add')}
          </Button>
        </Box>
      }
    >
      {entries.length ? (
        <>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', px: 1, mb: 1 }}>
            <Typography variant="body2" sx={{ fontWeight: 600 }}>
              {t('whitelist.entries')}
            </Typography>
            <Typography variant="body2" color="text.secondary">
              {enabled ? t('whitelist.summary', { applied, total: entries.length }) : t('outcome.disabled')}
            </Typography>
          </Box>
          {entries.map((entry) => (
            <Entry key={entry.id} entry={entry} enabled={enabled} onRemove={setRemoving} />
          ))}
        </>
      ) : (
        <BaseEmpty text={t('whitelist.empty')} />
      )}

      <BaseDialog
        open={adding}
        title={t('whitelist.addTitle')}
        okBtn={t('whitelist.add')}
        okDisabled={!text.trim()}
        loading={!!snap.busy['wl:add']}
        contentSx={{ width: 'min(420px, calc(100vw - 112px))' }}
        onOk={add}
        onCancel={() => setAdding(false)}
      >
        <TextField
          fullWidth
          multiline
          autoFocus
          size="small"
          rows={4}
          margin="dense"
          spellCheck={false}
          autoComplete="off"
          value={text}
          placeholder={t('whitelist.textPlaceholder')}
          slotProps={{ htmlInput: { 'aria-label': t('whitelist.addTitle') } }}
          onChange={(event) => setText(event.target.value)}
        />
        <TextField
          fullWidth
          size="small"
          margin="dense"
          autoComplete="off"
          value={name}
          placeholder={t('whitelist.namePlaceholder')}
          slotProps={{ htmlInput: { 'aria-label': t('whitelist.namePlaceholder') } }}
          onChange={(event) => setName(event.target.value)}
        />
      </BaseDialog>

      <BaseDialog
        open={!!removing}
        title={removing ? t('whitelist.confirmRemove', { name: removing.name || removing.label }) : ''}
        okBtn={t('whitelist.remove')}
        contentSx={{ display: 'none' }}
        onOk={remove}
        onCancel={() => setRemoving(null)}
      />
    </BasePage>
  );
}
