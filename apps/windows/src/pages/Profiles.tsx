// Follows Clash Verge Rev (GPL-3.0): src/pages/profiles.tsx and src/components/profile/profile-viewer.tsx.
import { ClearRounded, RefreshRounded, TextSnippetOutlined } from '@mui/icons-material';
import { Box, Button, IconButton, Menu, MenuItem, Stack, TextField, Typography } from '@mui/material';
import { AddedRulesDialog } from './settings/EngineDialogs';
import { ScriptsDialog } from './settings/ResourceDialogs';
import { loadOptions } from '../state/settings';
import { type ChangeEvent, useCallback, useEffect, useRef, useState } from 'react';
import { useSnapshot } from 'valtio';
import { BaseDialog, BaseEmpty, BasePage, Switch } from '../base';
import { CodeEditor, CodeViewer } from '../base/CodeEditor';
import { invoke } from '../ipc';
import { t } from '../lib/i18n.js';
import { act, app, notify } from '../state/core';
import { OverrideDialog } from './profiles/OverrideDialog';
import { ProfileItem, profileTitle } from './profiles/ProfileItem';
import { ShareNodesDialog } from './profiles/ShareNodesDialog';

const update = (profile: any) => act(`update:${profile.id}`, 'update_profile', { id: profile.id });
const select = (profile: any) => !profile.selected && act(`select:${profile.id}`, 'select_profile', { id: profile.id });

async function exportProfile(profile: any) {
  const path = await act('export', 'export_profile', { id: profile.id, name: profileTitle(profile) });
  if (path) notify(t('profiles.exported', { path }), '', 'success');
}

function EditDialog({ profile, onClose }: { profile: any; onClose: () => void }) {
  const { busy } = useSnapshot(app);
  const remote = profile.kind === 'subscription';
  const [form, setForm] = useState({
    name: profile.name as string,
    url: (profile.url ?? '') as string,
    autoUpdate: !!profile.autoUpdate,
    updateHours: String(profile.updateHours),
  });
  const hours = Number(form.updateHours);
  const valid = !!form.name.trim() && (!remote || !form.autoUpdate || (Number.isInteger(hours) && hours >= 1 && hours <= 720));

  async function save() {
    if (!valid || busy.edit) return;
    const edit = { name: form.name, url: remote ? form.url : null, autoUpdate: form.autoUpdate, updateHours: hours };
    if (await act('edit', 'edit_profile', { id: profile.id, edit })) onClose();
  }
  const field = (key: keyof typeof form) => ({
    fullWidth: true,
    size: 'small' as const,
    spellCheck: false,
    value: form[key],
    onChange: (event: ChangeEvent<HTMLInputElement>) => setForm({ ...form, [key]: event.target.value }),
  });

  return (
    <BaseDialog
      open
      title={t('profiles.editTitle')}
      okBtn={t('common.save')}
      okDisabled={!valid}
      loading={!!busy.edit}
      contentSx={{ width: 400 }}
      onOk={save}
      onCancel={onClose}
    >
      <Stack spacing={2} sx={{ pt: 1 }}>
        <TextField autoFocus label={t('profiles.name')} {...field('name')} />
        {remote && (
          <>
            <TextField multiline maxRows={4} label={t('profiles.url')} {...field('url')} />
            <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <Typography>{t('profiles.autoUpdate')}</Typography>
              <Switch checked={form.autoUpdate} onChange={(_, autoUpdate) => setForm({ ...form, autoUpdate })} />
            </Box>
            <TextField
              type="number"
              label={t('profiles.updateHours')}
              disabled={!form.autoUpdate}
              slotProps={{ htmlInput: { min: 1, max: 720 } }}
              {...field('updateHours')}
            />
          </>
        )}
      </Stack>
    </BaseDialog>
  );
}

function LinksDialog({ onClose }: { onClose: () => void }) {
  const { busy } = useSnapshot(app);
  const [links, setLinks] = useState('');
  async function importLinks() {
    const result = await act('import', 'import_links', { text: links });
    if (!result) return;
    notify(t('profiles.imported', { count: result.added }), '', 'success');
    onClose();
  }
  return (
    <BaseDialog
      open
      title={t('profiles.import')}
      okBtn={t('profiles.importButton')}
      okDisabled={!links.trim()}
      loading={!!busy.import}
      contentSx={{ width: 520 }}
      onOk={importLinks}
      onCancel={onClose}
    >
      <CodeEditor autoFocus rows={8} label={t('profiles.import')} placeholder={'vless://…\nss://…\ntrojan://…\nhysteria2://…'} value={links} onChange={setLinks} />
    </BaseDialog>
  );
}

type DialogState =
  | { kind: 'links' }
  | { kind: 'edit' | 'override' | 'nodes' | 'remove'; id: string }
  | { kind: 'preview'; title: string; config: string };

export default function Profiles() {
  const [globalDialog, setGlobalDialog] = useState<'rules' | 'scripts' | null>(null);
  useEffect(() => { loadOptions().catch(notify); }, []);

  const { profiles, busy } = useSnapshot(app);
  const [url, setUrl] = useState('');
  const [dialog, setDialog] = useState<DialogState | null>(null);
  const [menu, setMenu] = useState<{ id: string; top: number; left: number } | null>(null);
  const [newAnchor, setNewAnchor] = useState<HTMLElement | null>(null);
  const [drag, setDrag] = useState<{ from: string | null; over: string | null }>({ from: null, over: null });
  const [nodeCounts, setNodeCounts] = useState<Record<string, number>>({});
  const picker = useRef<HTMLInputElement>(null);
  const dragged = useRef<string | null>(null);

  const subscriptions = profiles.filter((p) => p.kind === 'subscription');
  const updating = subscriptions.some((p) => busy[`update:${p.id}`]);
  const selected = profiles.find((p) => p.selected);
  const reorderable = profiles.length > 1;
  const subject = dialog && 'id' in dialog ? profiles.find((p) => p.id === dialog.id) : undefined;
  const menuProfile = menu && profiles.find((p) => p.id === menu.id);

  const countNodes = useCallback(() => {
    for (const { id, kind } of app.profiles) {
      if (kind !== 'links') continue;
      invoke('share_nodes', { id }).then(
        (nodes) => setNodeCounts((counts) => ({ ...counts, [id]: nodes.length })),
        () => {},
      );
    }
  }, []);
  useEffect(countNodes, [profiles, countNodes]);

  async function add() {
    if (!url.trim() || app.busy.add) return;
    if (await act('add', 'add_subscription', { url })) setUrl('');
  }

  async function importFile(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;
    const profile = await act('importFile', 'import_file', { name: file.name, content: await file.text() });
    if (profile) notify(t('profiles.importedFile', { name: profile.name }), '', 'success');
  }

  const showPreview = useCallback(async (profile: any) => {
    const config = await act('preview', 'preview_config', { id: profile.id });
    if (config !== undefined) setDialog({ kind: 'preview', title: profileTitle(profile), config });
  }, []);

  function remove(id: string) {
    act(`remove:${id}`, 'remove_profile', { id });
    setDialog(null);
  }

  const onMenu = useCallback((profile: any, position: { top: number; left: number }) => setMenu({ id: profile.id, ...position }), []);
  const onDragStart = useCallback((id: string) => {
    dragged.current = id;
    setDrag({ from: id, over: null });
  }, []);
  const onDragOver = useCallback((id: string) => {
    if (dragged.current) setDrag((current) => (current.over === id ? current : { ...current, over: id }));
  }, []);
  const onDragEnd = useCallback(() => {
    dragged.current = null;
    setDrag({ from: null, over: null });
  }, []);
  const onDrop = useCallback(
    (over: string) => {
      const from = dragged.current;
      onDragEnd();
      if (!from || from === over) return;
      const ids = app.profiles.map((p) => p.id).filter((id) => id !== from);
      ids.splice(ids.indexOf(over), 0, from);
      app.profiles = ids.map((id) => app.profiles.find((p) => p.id === id));
      act('reorder', 'reorder_profiles', { ids });
    },
    [onDragEnd],
  );

  const actions = (profile: any) => {
    const open = (kind: 'edit' | 'override' | 'nodes' | 'remove') => () => setDialog({ kind, id: profile.id });
    const links = profile.kind === 'links';
    return [
      !profile.selected && { label: t('profiles.use'), run: () => select(profile), disabled: !!busy[`select:${profile.id}`] },
      profile.kind === 'subscription' && { label: t('profiles.update'), run: () => update(profile), disabled: !!busy[`update:${profile.id}`] },
      !links && { label: t('profiles.edit'), run: open('edit') },
      { label: t('override.title'), run: open('override') },
      links && { label: t('nodes.title'), run: open('nodes') },
      { label: t('profiles.preview'), run: () => showPreview(profile), disabled: !!busy.preview },
      { label: t('profiles.export'), run: () => exportProfile(profile), disabled: !!busy.export },
      { label: t('profiles.delete'), run: open('remove'), disabled: !!busy[`remove:${profile.id}`], danger: true },
    ].filter(Boolean) as { label: string; run: () => void; disabled?: boolean; danger?: boolean }[];
  };

  return (
    <BasePage
      full
      title={t('nav.profiles')}
      contentStyle={{ height: '100%' }}
      header={
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <IconButton
            size="small"
            color="inherit"
            title={t('profiles.updateAll')}
            disabled={updating || !subscriptions.length}
            onClick={() => app.profiles.filter((p) => p.kind === 'subscription').forEach(update)}
          >
            <RefreshRounded />
          </IconButton>
          <IconButton
            size="small"
            color="inherit"
            title={t('profiles.preview')}
            disabled={!selected || !!busy.preview}
            onClick={() => selected && showPreview(selected)}
          >
            <TextSnippetOutlined />
          </IconButton>
        </Box>
      }
    >
      <Stack direction="row" spacing={1} sx={{ pt: 1, mb: 0.5, mx: '10px', height: 36, alignItems: 'center' }}>
        <TextField
          fullWidth
          hiddenLabel
          size="small"
          autoComplete="off"
          spellCheck={false}
          value={url}
          placeholder={t('profiles.url')}
          onChange={(event) => setUrl(event.target.value)}
          onKeyDown={(event) => event.key === 'Enter' && !event.nativeEvent.isComposing && add()}
          sx={{ input: { py: 0.65, px: 1.25 }, '& .MuiInputBase-root': { bgcolor: 'surface.card' } }}
          slotProps={{
            htmlInput: { 'aria-label': t('profiles.url') },
            input: {
              sx: { pr: 1 },
              endAdornment: url && (
                <IconButton size="small" sx={{ p: 0.5 }} onClick={() => setUrl('')}>
                  <ClearRounded fontSize="inherit" />
                </IconButton>
              ),
            },
          }}
        />
        <Button disabled={!url.trim()} loading={!!busy.add} variant="contained" size="small" sx={{ borderRadius: '6px', flex: 'none' }} onClick={add}>
          {t('profiles.importButton')}
        </Button>
        <Button variant="contained" size="small" sx={{ borderRadius: '6px', flex: 'none' }} onClick={(event) => setNewAnchor(event.currentTarget)}>
          {t('profiles.new')}
        </Button>
      </Stack>
      <input ref={picker} type="file" accept=".yaml,.yml,.txt,.conf" hidden onChange={importFile} />

      <Box sx={{ px: '10px', height: 'calc(100% - 48px)', overflowY: 'auto' }}>
        {!profiles.length ? (
          <BaseEmpty text={t('profiles.empty')} />
        ) : (
          <Box
            sx={{
              mt: 0.5,
              mb: 1.5,
              px: 0.5,
              py: '2px',
              display: 'grid',
              gap: 1,
              gridTemplateColumns: 'repeat(auto-fill, minmax(clamp(260px, calc((100% - 24px) / 4), 480px), 1fr))',
            }}
          >
            {profiles.map((profile) => (
              <ProfileItem
                key={profile.id}
                profile={profile}
                nodeCount={nodeCounts[profile.id]}
                activating={!!busy[`select:${profile.id}`]}
                updating={!!busy[`update:${profile.id}`]}
                reorderable={reorderable}
                dragging={drag.from === profile.id}
                dropTarget={drag.over === profile.id && drag.from !== profile.id}
                onSelect={select}
                onUpdate={update}
                onMenu={onMenu}
                onDragStart={onDragStart}
                onDragOver={onDragOver}
                onDrop={onDrop}
                onDragEnd={onDragEnd}
              />
            ))}
          </Box>
        )}
        <Box sx={{ mt: 1.5, pt: 1.5, borderTop: 1, borderColor: 'divider', display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: 1 }}>
          <Button variant="text" color="inherit" onClick={() => setGlobalDialog('rules')} sx={{ bgcolor: 'surface.card', minHeight: 80, justifyContent: 'space-between', px: 2, borderRadius: 2, textTransform: 'none', fontSize: 20 }}>
            {t('settings.globalRules')}
          </Button>
          <Button variant="text" color="inherit" onClick={() => setGlobalDialog('scripts')} sx={{ bgcolor: 'surface.card', minHeight: 80, justifyContent: 'space-between', px: 2, borderRadius: 2, textTransform: 'none', fontSize: 20 }}>
            {t('script.library')}
          </Button>
        </Box>
      </Box>
      {globalDialog === 'rules' && <AddedRulesDialog onClose={() => setGlobalDialog(null)} />}
      {globalDialog === 'scripts' && <ScriptsDialog onClose={() => setGlobalDialog(null)} />}

      <Menu open={!!newAnchor} anchorEl={newAnchor} onClose={() => setNewAnchor(null)} slotProps={{ list: { sx: { py: 0.5 } } }}>
        <MenuItem
          dense
          onClick={() => {
            setNewAnchor(null);
            setDialog({ kind: 'links' });
          }}
        >
          {t('profiles.importEllipsis')}
        </MenuItem>
        <MenuItem
          dense
          disabled={!!busy.importFile}
          onClick={() => {
            setNewAnchor(null);
            picker.current?.click();
          }}
        >
          {t('profiles.importFile')}
        </MenuItem>
      </Menu>

      <Menu
        open={!!menuProfile}
        anchorReference="anchorPosition"
        anchorPosition={menu ?? undefined}
        onClose={() => setMenu(null)}
        slotProps={{ list: { sx: { py: 0.5 } } }}
        onContextMenu={(event) => {
          event.preventDefault();
          setMenu(null);
        }}
      >
        {menuProfile &&
          actions(menuProfile).map((item) => (
            <MenuItem
              key={item.label}
              dense
              disabled={item.disabled}
              sx={[{ minWidth: 120 }, !!item.danger && { color: 'error.main' }]}
              onClick={() => {
                setMenu(null);
                item.run();
              }}
            >
              {item.label}
            </MenuItem>
          ))}
      </Menu>

      {dialog?.kind === 'links' && <LinksDialog onClose={() => setDialog(null)} />}
      {dialog?.kind === 'edit' && subject && <EditDialog profile={subject} onClose={() => setDialog(null)} />}
      {dialog?.kind === 'override' && subject && <OverrideDialog id={subject.id} title={profileTitle(subject)} onClose={() => setDialog(null)} />}
      {dialog?.kind === 'nodes' && subject && <ShareNodesDialog id={subject.id} onClose={() => setDialog(null)} onChanged={countNodes} />}
      {dialog?.kind === 'preview' && (
        <CodeViewer open title={t('profiles.previewTitle', { name: dialog.title })} value={dialog.config} onClose={() => setDialog(null)} />
      )}
      {dialog?.kind === 'remove' && subject && (
        <BaseDialog open title={t('profiles.delete')} okBtn={t('profiles.delete')} onOk={() => remove(subject.id)} onCancel={() => setDialog(null)}>
          {t('profiles.confirmDelete', { name: profileTitle(subject) })}
        </BaseDialog>
      )}
    </BasePage>
  );
}
