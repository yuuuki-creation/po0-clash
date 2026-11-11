import { Stack, TextField } from '@mui/material';
import { useState } from 'react';
import { useSnapshot } from 'valtio';
import { BaseDialog } from '../../base';
import { CodeEditor } from '../../base/CodeEditor';
import { t } from '../../lib/i18n.js';
import { act, app } from '../../state/core';
import { loadScripts } from '../../state/settings';

const template = 'const main = (config) => {\n  return config;\n};\n';

interface Props {
  script: any | null;
  onClose: () => void;
  onSaved?: (script: any) => void;
}

export function ScriptEditor({ script, onClose, onSaved }: Props) {
  const { busy } = useSnapshot(app);
  const [name, setName] = useState<string>(script?.name ?? '');
  const [content, setContent] = useState<string>(script?.content ?? template);

  async function save() {
    const saved = await act('script:save', 'save_script', { script: { id: script?.id ?? '', name, content } });
    if (!saved) return;
    await loadScripts();
    onSaved?.(saved);
    onClose();
  }

  return (
    <BaseDialog
      open
      title={script ? t('script.edit') : t('script.new')}
      okBtn={t('common.save')}
      okDisabled={!name.trim()}
      loading={!!busy['script:save']}
      contentSx={{ width: 600 }}
      onOk={save}
      onCancel={onClose}
    >
      <Stack spacing={1.5} sx={{ pt: 1 }}>
        <TextField autoFocus fullWidth size="small" label={t('script.name')} value={name} spellCheck={false} onChange={(event) => setName(event.target.value)} />
        <CodeEditor rows={16} label={t('script.content')} value={content} onChange={setContent} />
      </Stack>
    </BaseDialog>
  );
}
