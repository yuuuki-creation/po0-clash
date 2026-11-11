import { Box, TextField } from '@mui/material';
import type { ReactNode } from 'react';
import { t } from '../lib/i18n.js';
import { BaseDialog } from './index';

const MONO = 'ui-monospace, "Cascadia Mono", "SF Mono", Menlo, Consolas, monospace';

interface EditorProps {
  value: string;
  onChange?: (value: string) => void;
  rows?: number;
  label?: string;
  placeholder?: string;
  readOnly?: boolean;
  autoFocus?: boolean;
}

/** A plain monospace text area: no wrapping, no spell check. */
export function CodeEditor({ value, onChange, rows = 10, label, placeholder, readOnly, autoFocus }: EditorProps) {
  return (
    <TextField
      multiline
      fullWidth
      hiddenLabel
      size="small"
      rows={rows}
      value={value}
      placeholder={placeholder}
      autoFocus={autoFocus}
      spellCheck={false}
      autoComplete="off"
      onChange={(event) => onChange?.(event.target.value)}
      slotProps={{ htmlInput: { 'aria-label': label, readOnly, wrap: 'off' } }}
      sx={{ '& textarea': { fontFamily: MONO, fontSize: 13, lineHeight: 1.5, whiteSpace: 'pre', overflowX: 'auto' } }}
    />
  );
}

interface ViewerProps {
  open: boolean;
  title: ReactNode;
  value: string;
  onClose: () => void;
}

/** A read-only dialog for long text such as a generated config. */
export function CodeViewer({ open, title, value, onClose }: ViewerProps) {
  return (
    <BaseDialog open={open} title={title} disableOk cancelBtn={t('common.close')} onClose={onClose} contentSx={{ width: 600, pb: 0 }}>
      <Box
        component="pre"
        className="selectable"
        sx={{
          m: 0,
          p: 1.5,
          height: 'min(60vh, 520px)',
          overflow: 'auto',
          borderRadius: 1,
          border: 1,
          borderColor: 'divider',
          bgcolor: 'surface.page',
          fontFamily: MONO,
          fontSize: 13,
          lineHeight: 1.5,
          cursor: 'text',
        }}
      >
        {value}
      </Box>
    </BaseDialog>
  );
}
