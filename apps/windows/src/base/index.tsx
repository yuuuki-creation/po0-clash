// Base components follow Clash Verge Rev (GPL-3.0): src/components/base and home/enhanced-card.tsx.
import { InboxRounded } from '@mui/icons-material';
import {
  alpha,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Switch as MuiSwitch,
  type SwitchProps,
  type SxProps,
  type Theme,
  Typography,
} from '@mui/material';
import { styled, useTheme } from '@mui/material/styles';
import type { CSSProperties, ReactNode } from 'react';
import { t } from '../lib/i18n.js';

interface PageProps {
  title?: ReactNode;
  header?: ReactNode;
  contentStyle?: CSSProperties;
  children?: ReactNode;
  /** The content fills the page and scrolls by itself (tables, virtual lists). */
  full?: boolean;
}

export function BasePage({ title, header, contentStyle, full, children }: PageProps) {
  return (
    <div className="base-page">
      <header data-tauri-drag-region>
        <Typography sx={{ fontSize: 20, fontWeight: 700, whiteSpace: 'nowrap' }} data-tauri-drag-region>
          {title}
        </Typography>
        {header}
      </header>
      <div className={full ? 'base-container no-padding' : 'base-container'}>
        <section>
          <div className="base-content" style={contentStyle}>
            {children}
          </div>
        </section>
      </div>
    </div>
  );
}

interface DialogProps {
  title: ReactNode;
  open: boolean;
  okBtn?: ReactNode;
  cancelBtn?: ReactNode;
  disableOk?: boolean;
  disableCancel?: boolean;
  disableFooter?: boolean;
  okDisabled?: boolean;
  contentSx?: SxProps<Theme>;
  children?: ReactNode;
  loading?: boolean;
  onOk?: () => void;
  onCancel?: () => void;
  onClose?: () => void;
}

export function BaseDialog(props: DialogProps) {
  const { open, title, children, okBtn, cancelBtn, contentSx, disableCancel, disableOk, disableFooter, okDisabled } = props;
  const close = props.onClose ?? props.onCancel;
  return (
    <Dialog open={open} onClose={close}>
      <DialogTitle>{title}</DialogTitle>
      <DialogContent sx={contentSx}>{children}</DialogContent>
      {!disableFooter && (
        <DialogActions>
          {!disableCancel && (
            <Button variant="outlined" onClick={props.onCancel ?? close}>
              {cancelBtn ?? t('common.cancel')}
            </Button>
          )}
          {!disableOk && (
            <Button loading={props.loading} disabled={okDisabled} variant="contained" onClick={props.onOk}>
              {okBtn ?? t('common.ok')}
            </Button>
          )}
        </DialogActions>
      )}
    </Dialog>
  );
}

export const Switch = styled((props: SwitchProps) => <MuiSwitch disableRipple {...props} />)(({ theme }) => ({
  width: 42,
  height: 26,
  padding: 0,
  marginRight: 1,
  '& .MuiSwitch-switchBase': {
    padding: 0,
    margin: 2,
    transitionDuration: '300ms',
    '&.Mui-checked': {
      transform: 'translateX(16px)',
      color: '#fff',
      '& + .MuiSwitch-track': { backgroundColor: theme.palette.primary.main, opacity: 1, border: 0 },
      '&.Mui-disabled + .MuiSwitch-track': { opacity: 0.5 },
    },
    '&.Mui-disabled .MuiSwitch-thumb': {
      color: theme.palette.mode === 'light' ? theme.palette.grey[100] : theme.palette.grey[600],
    },
    '&.Mui-disabled + .MuiSwitch-track': { opacity: theme.palette.mode === 'light' ? 0.7 : 0.3 },
  },
  '& .MuiSwitch-thumb': { boxSizing: 'border-box', width: 22, height: 22 },
  '& .MuiSwitch-track': {
    borderRadius: 13,
    backgroundColor: theme.palette.mode === 'light' ? '#BBBBBB' : '#39393D',
    opacity: 1,
    transition: theme.transitions.create(['background-color'], { duration: 500 }),
  },
}));

interface CardProps {
  title: ReactNode;
  icon: ReactNode;
  action?: ReactNode;
  children: ReactNode;
  iconColor?: 'primary' | 'secondary' | 'error' | 'warning' | 'info' | 'success';
  minHeight?: number | string;
  noContentPadding?: boolean;
}

export function EnhancedCard({ title, icon, action, children, iconColor = 'primary', minHeight, noContentPadding }: CardProps) {
  const theme = useTheme();
  return (
    <Box sx={{ height: '100%', display: 'flex', flexDirection: 'column', borderRadius: 2, bgcolor: 'surface.card' }}>
      <Box
        sx={{
          px: 2,
          py: 1,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          borderBottom: 1,
          borderColor: 'divider',
        }}
      >
        <Box sx={{ display: 'flex', alignItems: 'center', minWidth: 0, flex: 1, overflow: 'hidden' }}>
          <Box
            sx={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              borderRadius: 1.5,
              width: 38,
              height: 38,
              mr: 1.5,
              flexShrink: 0,
              bgcolor: alpha(theme.palette[iconColor].main, 0.12),
              color: theme.palette[iconColor].main,
            }}
          >
            {icon}
          </Box>
          <Typography variant="h6" noWrap sx={{ fontWeight: 'medium', fontSize: 18, minWidth: 0 }}>
            {title}
          </Typography>
        </Box>
        {action && <Box sx={{ ml: 2, flexShrink: 0 }}>{action}</Box>}
      </Box>
      <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column', p: noContentPadding ? 0 : 2, minHeight }}>
        {children}
      </Box>
    </Box>
  );
}

export function BaseEmpty({ text, extra }: { text?: ReactNode; extra?: ReactNode }) {
  return (
    <Box
      sx={({ palette }) => ({
        width: '100%',
        height: '100%',
        minHeight: 240,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        color: alpha(palette.text.secondary, 0.75),
      })}
    >
      <InboxRounded sx={{ fontSize: '4em' }} />
      <Typography sx={{ fontSize: '1.25em' }}>{text ?? t('common.empty')}</Typography>
      {extra}
    </Box>
  );
}
