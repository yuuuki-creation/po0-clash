import { DeleteRounded, EditRounded } from '@mui/icons-material';
import { Box, Button, IconButton, List, ListItem, ListItemText, Typography } from '@mui/material';
import { useEffect, useState } from 'react';
import { snapshot, useSnapshot } from 'valtio';
import { BaseDialog, Switch } from '../../base';
import { CodeEditor } from '../../base/CodeEditor';
import { invoke } from '../../ipc';
import { formatBytes, formatTime, t } from '../../lib/i18n.js';
import { act, app, notify } from '../../state/core';
import { engine, loadScripts, patchOptions, scripts } from '../../state/settings';
import { Choice, DialogRow, DialogSection, PlainField, run, useLoaded } from './common';
import type { DialogProps } from './EngineDialogs';

const geoUrls = [
  ['geoip', 'GeoIP'],
  ['geosite', 'GeoSite'],
  ['mmdb', 'MMDB'],
  ['asn', 'ASN'],
] as const;

export function GeoDialog({ onClose }: DialogProps) {
  const { busy } = useSnapshot(app);
  const [files, reload] = useLoaded<any[]>(() => invoke('geo_files'), []);
  const [draft, setDraft] = useState(() => {
    const o = snapshot(engine.options) as any;
    return { geodataLoader: o.geodataLoader, geoAutoUpdate: o.geoAutoUpdate, interval: String(o.geoUpdateInterval), geoxUrl: { ...o.geoxUrl } };
  });
  const set = (patch: Partial<typeof draft>) => setDraft((old) => ({ ...old, ...patch }));

  async function update() {
    if (!(await run('geo', 'update_geo'))) return;
    await reload();
    notify(t('opt.geoUpdated'), '', 'success');
  }

  function save() {
    const geoxUrl = Object.fromEntries(Object.entries(draft.geoxUrl).map(([key, url]) => [key, String(url).trim()]));
    patchOptions({
      geodataLoader: draft.geodataLoader,
      geoAutoUpdate: draft.geoAutoUpdate,
      geoUpdateInterval: Math.max(1, Math.floor(Number(draft.interval)) || 1),
      geoxUrl,
    });
    onClose();
  }

  return (
    <BaseDialog
      open
      title={
        <Box sx={{ display: 'flex', justifyContent: 'space-between', gap: 1 }}>
          <Typography variant="h6">{t('opt.geo')}</Typography>
          <Button variant="outlined" size="small" loading={!!busy.geo} onClick={update}>
            {t('opt.updateGeo')}
          </Button>
        </Box>
      }
      contentSx={{ width: 500 }}
      okBtn={t('common.save')}
      onClose={onClose}
      onCancel={onClose}
      onOk={save}
    >
      <List>
        {files.map((file) => (
          <DialogRow key={file.name} label={<span className="selectable">{file.name}</span>}>
            <Typography variant="body2" color="text.secondary" noWrap>
              {file.size != null ? formatBytes(file.size) : t('opt.notDownloaded')}
              {file.modified ? ` · ${formatTime(file.modified)}` : ''}
            </Typography>
          </DialogRow>
        ))}
      </List>
      <List disablePadding>
        <DialogRow label={t('opt.geoLoader')}>
          <Choice
            width={150}
            value={draft.geodataLoader}
            options={['standard', 'memconservative'].map((value) => ({ value, label: t(`loader.${value}`) }))}
            onChange={(geodataLoader) => set({ geodataLoader })}
          />
        </DialogRow>
        <DialogRow label={t('opt.geoAutoUpdate')}>
          <Switch edge="end" checked={draft.geoAutoUpdate} onChange={(_, geoAutoUpdate) => set({ geoAutoUpdate })} />
        </DialogRow>
        <DialogRow label={t('opt.geoInterval')}>
          <PlainField type="number" sx={{ width: 150 }} value={draft.interval} onChange={(event) => set({ interval: event.target.value })} />
        </DialogRow>
      </List>
      <DialogSection title={t('opt.geoUrls')} />
      <List disablePadding>
        {geoUrls.map(([key, label]) => (
          <DialogRow key={key} label={label}>
            <PlainField
              sx={{ width: 380 }}
              value={draft.geoxUrl[key] ?? ''}
              onChange={(event) => set({ geoxUrl: { ...draft.geoxUrl, [key]: event.target.value } })}
            />
          </DialogRow>
        ))}
      </List>
    </BaseDialog>
  );
}

const template = 'const main = (config) => {\n  return config;\n};\n';

function ScriptEditor({ script, onClose }: { script: any | null; onClose: () => void }) {
  const { busy } = useSnapshot(app);
  const [name, setName] = useState(script?.name ?? '');
  const [content, setContent] = useState(script?.content ?? template);

  async function save() {
    const saved = await act('script:save', 'save_script', { script: { id: script?.id ?? '', name, content } });
    if (!saved) return;
    await loadScripts();
    onClose();
  }

  return (
    <BaseDialog
      open
      title={script ? t('script.edit') : t('script.new')}
      contentSx={{ width: 600 }}
      okBtn={t('common.save')}
      okDisabled={!name.trim()}
      loading={!!busy['script:save']}
      onClose={onClose}
      onCancel={onClose}
      onOk={save}
    >
      <PlainField fullWidth autoFocus sx={{ mt: 1 }} label={t('script.name')} value={name} onChange={(event) => setName(event.target.value)} />
      <Box sx={{ mt: 1.5 }}>
        <CodeEditor rows={16} label={t('script.content')} value={content} onChange={setContent} />
      </Box>
    </BaseDialog>
  );
}

export function ScriptsDialog({ onClose }: DialogProps) {
  const { list } = useSnapshot(scripts);
  const [editing, setEditing] = useState<{ script: any | null } | null>(null);
  const [removing, setRemoving] = useState<any | null>(null);

  useEffect(() => {
    loadScripts().catch((error) => notify(error));
  }, []);

  async function remove() {
    const { id } = removing;
    setRemoving(null);
    if (await run(`script:remove:${id}`, 'remove_script', { id })) await loadScripts();
  }

  return (
    <BaseDialog
      open
      title={
        <Box sx={{ display: 'flex', justifyContent: 'space-between', gap: 1 }}>
          <Typography variant="h6">{t('script.library')}</Typography>
          <Button variant="contained" size="small" onClick={() => setEditing({ script: null })}>
            {t('script.new')}
          </Button>
        </Box>
      }
      contentSx={{ width: 450, minHeight: 160 }}
      disableOk
      cancelBtn={t('common.close')}
      onClose={onClose}
      onCancel={onClose}
    >
      <List>
        {list.map((script) => (
          <ListItem key={script.id} sx={{ padding: '2px' }}>
            <ListItemText
              primary={script.name}
              secondary={t('script.lines', { count: script.content.split('\n').length })}
              slotProps={{ primary: { noWrap: true, sx: { fontSize: 14 } } }}
            />
            <IconButton size="small" color="inherit" title={t('script.edit')} onClick={() => setEditing({ script })}>
              <EditRounded fontSize="inherit" />
            </IconButton>
            <IconButton size="small" color="inherit" title={t('script.delete')} onClick={() => setRemoving(script)}>
              <DeleteRounded fontSize="inherit" />
            </IconButton>
          </ListItem>
        ))}
      </List>
      {!list.length && (
        <Typography variant="body2" color="text.secondary" sx={{ textAlign: 'center', py: 3 }}>
          {t('script.empty')}
        </Typography>
      )}
      {editing && <ScriptEditor script={editing.script} onClose={() => setEditing(null)} />}
      {removing && (
        <BaseDialog
          open
          title={t('script.confirmDelete', { name: removing.name })}
          contentSx={{ width: 400 }}
          okBtn={t('script.delete')}
          onClose={() => setRemoving(null)}
          onCancel={() => setRemoving(null)}
          onOk={remove}
        >
          <Typography variant="body2">{t('script.deleteHint')}</Typography>
        </BaseDialog>
      )}
    </BaseDialog>
  );
}
