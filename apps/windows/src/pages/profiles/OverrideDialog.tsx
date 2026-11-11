import { Alert, Box, Button, ButtonGroup, MenuItem, Stack, TextField, Typography } from '@mui/material';
import { type ReactNode, useEffect, useState } from 'react';
import { useSnapshot } from 'valtio';
import { BaseDialog, Switch } from '../../base';
import { CodeEditor } from '../../base/CodeEditor';
import { invoke } from '../../ipc';
import { t } from '../../lib/i18n.js';
import { act, app, notify } from '../../state/core';
import { engine, fromLines, loadOptions, loadScripts, scripts, toLines } from '../../state/settings';
import { ScriptEditor } from './ScriptEditor';

const MODES = ['standard', 'script', 'custom'];

function Section({ title, action, children }: { title: string; action?: ReactNode; children: ReactNode }) {
  return (
    <Box>
      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', minHeight: 32 }}>
        <Typography sx={{ fontSize: 14, fontWeight: 600 }}>{title}</Typography>
        {action}
      </Box>
      {children}
    </Box>
  );
}

interface Props {
  id: string;
  title: string;
  onClose: () => void;
}

export function OverrideDialog({ id, title, onClose }: Props) {
  const { busy } = useSnapshot(app);
  const { list } = useSnapshot(scripts);
  const globalRules: readonly string[] = useSnapshot(engine).options?.addedRules ?? [];
  /** The core's `ProfileOverride`, with the two rule lists held as text while editing. */
  const [draft, setDraft] = useState<any>(null);
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);
  const [editor, setEditor] = useState<{ script: any | null } | null>(null);
  const [replacing, setReplacing] = useState(false);

  useEffect(() => {
    let live = true;
    Promise.all([invoke('profile_override', { id }), loadOptions(), loadScripts()])
      .then(([o]) => live && setDraft({ ...o, addedRules: toLines(o.addedRules), customRules: toLines(o.customRules) }))
      .catch((e) => notify(e));
    return () => {
      live = false;
    };
  }, [id]);

  const patch = (change: Record<string, unknown>) => setDraft((current: any) => ({ ...current, ...change }));
  const script = list.find((s) => s.id === draft?.scriptId);

  function toggleGlobal(rule: string, enabled: boolean) {
    const disabled = draft.disabledGlobalRules.filter((r: string) => r !== rule);
    patch({ disabledGlobalRules: enabled ? disabled : [...disabled, rule] });
  }

  async function save() {
    const overrides = { ...draft, addedRules: fromLines(draft.addedRules), customRules: fromLines(draft.customRules) };
    setSaving(true);
    setError('');
    try {
      await invoke('set_profile_override', { id, overrides });
      notify(t('override.saved'), '', 'success');
      onClose();
    } catch (e) {
      setError(String(e));
    } finally {
      setSaving(false);
    }
  }

  async function copyFromProfile() {
    setReplacing(false);
    const parts = await act('override:copy', 'profile_groups_and_rules', { id });
    if (parts) patch({ customGroups: parts.groups, customRules: toLines(parts.rules) });
  }

  return (
    <BaseDialog
      open
      title={`${t('override.title')} · ${title}`}
      okBtn={t('common.save')}
      okDisabled={!draft}
      loading={saving}
      contentSx={{ width: 600, height: 'min(70vh, 560px)' }}
      onOk={save}
      onCancel={onClose}
    >
      {draft && (
        <Stack spacing={1.5}>
          <ButtonGroup size="small" fullWidth>
            {MODES.map((mode) => (
              <Button key={mode} variant={mode === draft.mode ? 'contained' : 'outlined'} onClick={() => patch({ mode })}>
                {t(`override.${mode}`)}
              </Button>
            ))}
          </ButtonGroup>

          {error && (
            <Alert severity="error" className="selectable" sx={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
              {error}
            </Alert>
          )}

          {draft.mode === 'standard' && (
            <>
              <Section title={t('override.addedRules')}>
                <CodeEditor
                  rows={7}
                  label={t('override.addedRules')}
                  placeholder="DOMAIN-SUFFIX,example.com,DIRECT"
                  value={draft.addedRules}
                  onChange={(addedRules) => patch({ addedRules })}
                />
              </Section>
              <TextField
                fullWidth
                size="small"
                spellCheck={false}
                label={t('override.matchTarget')}
                placeholder={t('override.matchTargetPlaceholder')}
                value={draft.matchTarget ?? ''}
                onChange={(event) => patch({ matchTarget: event.target.value.trim() || null })}
              />
              <Section title={t('override.globalRules')}>
                {globalRules.map((rule) => (
                  <Box key={rule} sx={{ display: 'flex', alignItems: 'center', gap: 1, minHeight: 36 }}>
                    <Typography noWrap title={rule} sx={{ flex: 1, fontSize: 13, fontFamily: 'ui-monospace, Consolas, monospace' }}>
                      {rule}
                    </Typography>
                    <Switch
                      slotProps={{ input: { 'aria-label': rule } }}
                      checked={!draft.disabledGlobalRules.includes(rule)}
                      onChange={(_, enabled) => toggleGlobal(rule, enabled)}
                    />
                  </Box>
                ))}
                {!globalRules.length && (
                  <Button size="small" sx={{ ml: -0.5 }} onClick={() => (app.page = 'settings')}>
                    {t('override.globalEmpty')}
                  </Button>
                )}
              </Section>
            </>
          )}

          {draft.mode === 'script' && (
            <>
              <TextField
                select
                fullWidth
                size="small"
                sx={{ mt: 1 }}
                label={t('override.script')}
                value={script ? draft.scriptId : ''}
                onChange={(event) => patch({ scriptId: event.target.value || null })}
                slotProps={{ select: { displayEmpty: true }, inputLabel: { shrink: true } }}
              >
                <MenuItem value="">{t('override.noScript')}</MenuItem>
                {list.map((s) => (
                  <MenuItem key={s.id} value={s.id}>
                    {s.name}
                  </MenuItem>
                ))}
              </TextField>
              <Stack direction="row" spacing={1}>
                {script && (
                  <Button size="small" variant="outlined" onClick={() => setEditor({ script })}>
                    {t('script.editEllipsis')}
                  </Button>
                )}
                <Button size="small" variant="outlined" onClick={() => setEditor({ script: null })}>
                  {t('script.newEllipsis')}
                </Button>
              </Stack>
            </>
          )}

          {draft.mode === 'custom' && (
            <>
              <Section
                title={t('override.customGroups')}
                action={
                  <Button
                    size="small"
                    disabled={!!busy['override:copy']}
                    onClick={() => (draft.customGroups.trim() || draft.customRules.trim() ? setReplacing(true) : copyFromProfile())}
                  >
                    {t('override.copyFromProfile')}
                  </Button>
                }
              >
                <CodeEditor
                  rows={9}
                  label={t('override.customGroups')}
                  placeholder={'- name: Proxy\n  type: select\n  proxies: [DIRECT]'}
                  value={draft.customGroups}
                  onChange={(customGroups) => patch({ customGroups })}
                />
              </Section>
              <Section title={t('override.customRules')}>
                <CodeEditor
                  rows={7}
                  label={t('override.customRules')}
                  placeholder="DOMAIN-SUFFIX,example.com,Proxy"
                  value={draft.customRules}
                  onChange={(customRules) => patch({ customRules })}
                />
              </Section>
            </>
          )}
        </Stack>
      )}

      {editor && <ScriptEditor script={editor.script} onClose={() => setEditor(null)} onSaved={(saved) => patch({ scriptId: saved.id })} />}
      <BaseDialog
        open={replacing}
        title={t('override.copyFromProfile')}
        okBtn={t('override.replace')}
        onOk={copyFromProfile}
        onCancel={() => setReplacing(false)}
      >
        {t('override.confirmCopy')}
      </BaseDialog>
    </BaseDialog>
  );
}
