import { DeleteRounded, EditRounded } from '@mui/icons-material';
import { alpha, Box, IconButton, TextField, Typography } from '@mui/material';
import { useCallback, useEffect, useState } from 'react';
import { useSnapshot } from 'valtio';
import { BaseDialog, BaseEmpty } from '../../base';
import { invoke } from '../../ipc';
import { t } from '../../lib/i18n.js';
import { act, app, notify } from '../../state/core';

interface Props {
  id: string;
  onClose: () => void;
  onChanged: () => void;
}

export function ShareNodesDialog({ id, onClose, onChanged }: Props) {
  const { busy } = useSnapshot(app);
  const [nodes, setNodes] = useState<any[] | null>(null);
  const [renaming, setRenaming] = useState<{ name: string; newName: string } | null>(null);
  const [removing, setRemoving] = useState<any>(null);

  const load = useCallback(
    () =>
      invoke('share_nodes', { id })
        .then(setNodes)
        .catch((e) => notify(e)),
    [id],
  );
  useEffect(() => void load(), [load]);

  async function rename() {
    if (!renaming?.newName.trim() || busy['node:rename']) return;
    const { name, newName } = renaming;
    if (newName.trim() === name) return setRenaming(null);
    if ((await act('node:rename', 'rename_share_node', { id, name, newName })) === undefined) return;
    setRenaming(null);
    await load();
  }

  async function remove() {
    const { name } = removing;
    setRemoving(null);
    if ((await act(`node:remove:${name}`, 'remove_share_node', { id, name })) === undefined) return;
    await load();
    onChanged();
  }

  return (
    <BaseDialog open title={t('nodes.title')} disableOk cancelBtn={t('common.close')} contentSx={{ width: 520, height: 'min(60vh, 480px)' }} onClose={onClose}>
      {nodes?.length === 0 && <BaseEmpty />}
      {nodes?.map((node) => (
        <Box key={node.name} sx={{ display: 'flex', alignItems: 'center', gap: 1, minHeight: 40, borderBottom: 1, borderColor: 'divider' }}>
          <Box
            component="span"
            sx={({ palette }) => ({
              flex: 'none',
              border: `1px solid ${alpha(palette.text.secondary, 0.36)}`,
              color: 'text.secondary',
              borderRadius: 1,
              fontSize: 10,
              px: 0.5,
              lineHeight: 1.5,
            })}
          >
            {node.kind}
          </Box>
          <Typography noWrap className="selectable" title={node.name} sx={{ flex: 1, fontSize: 14 }}>
            {node.name}
          </Typography>
          <IconButton size="small" color="inherit" title={t('nodes.rename')} onClick={() => setRenaming({ name: node.name, newName: node.name })}>
            <EditRounded fontSize="small" />
          </IconButton>
          <span title={nodes.length > 1 ? t('nodes.delete') : t('nodes.lastNode')}>
            <IconButton
              size="small"
              color="inherit"
              aria-label={t('nodes.delete')}
              disabled={nodes.length < 2 || !!busy[`node:remove:${node.name}`]}
              onClick={() => setRemoving(node)}
            >
              <DeleteRounded fontSize="small" />
            </IconButton>
          </span>
        </Box>
      ))}

      <BaseDialog
        open={!!renaming}
        title={t('nodes.renameTitle')}
        okBtn={t('nodes.rename')}
        okDisabled={!renaming?.newName.trim()}
        loading={!!busy['node:rename']}
        contentSx={{ width: 380 }}
        onOk={rename}
        onCancel={() => setRenaming(null)}
      >
        <TextField
          autoFocus
          fullWidth
          size="small"
          spellCheck={false}
          sx={{ mt: 1 }}
          label={t('nodes.name')}
          value={renaming?.newName ?? ''}
          onChange={(event) => setRenaming((current) => current && { ...current, newName: event.target.value })}
          onKeyDown={(event) => event.key === 'Enter' && !event.nativeEvent.isComposing && rename()}
        />
      </BaseDialog>
      <BaseDialog open={!!removing} title={t('nodes.delete')} okBtn={t('nodes.delete')} onOk={remove} onCancel={() => setRemoving(null)}>
        {removing && t('nodes.confirmDelete', { name: removing.name })}
      </BaseDialog>
    </BaseDialog>
  );
}
