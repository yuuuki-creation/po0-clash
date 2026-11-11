// Follows Clash Verge Rev (GPL-3.0): src/components/connection/connection-detail.tsx.
import { Box, Button, Snackbar } from '@mui/material';
import { formatAgo, formatBytes, t } from '../../lib/i18n.js';
import { chainOf, hostOf, ruleOf, typeOf } from './ConnectionTable';

interface Props {
  connection: any | null;
  closed: boolean;
  onClose: () => void;
  onCloseConnection: (id: string) => void;
}

export function ConnectionDetail({ connection: c, closed, onClose, onCloseConnection }: Props) {
  const information = c
    ? [
        [t('activity.host'), hostOf(c)],
        [t('home.downloaded'), formatBytes(c.download)],
        [t('home.uploaded'), formatBytes(c.upload)],
        [t('activity.chain'), chainOf(c)],
        [t('activity.rule'), ruleOf(c)],
        [t('activity.process'), `${c.process ?? ''}${c.processPath ? `(${c.processPath})` : ''}`],
        [t('activity.time'), formatAgo(c.start)],
        [t('conn.source'), c.source],
        [t('conn.destination'), c.destination],
        [t('conn.type'), typeOf(c)],
      ]
    : [];

  return (
    <Snackbar
      anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
      open={!!c}
      onClose={(event, reason) => {
        // A click on another row replaces the detail, so it must not also dismiss it.
        if (reason === 'clickaway' && (event?.target as Element | null)?.closest?.('[data-conn-row]')) return;
        onClose();
      }}
      sx={{
        '.MuiSnackbarContent-root': {
          maxWidth: 520,
          maxHeight: 480,
          overflowY: 'auto',
          bgcolor: 'background.paper',
          color: 'text.primary',
          boxShadow: '0 4px 20px rgba(0, 0, 0, 0.18)',
          border: 1,
          borderColor: 'divider',
        },
        '.MuiSnackbarContent-message': { flex: 1 },
      }}
      message={
        c && (
          <Box className="selectable" sx={{ color: 'text.secondary', fontSize: 14, lineHeight: 1.6 }}>
            {information.map(([label, value]) => (
              <div key={label}>
                <b>{label}</b>
                <Box component="span" sx={{ wordBreak: 'break-all', color: 'text.primary' }}>
                  : {value}
                </Box>
              </div>
            ))}
            {!closed && (
              <Box sx={{ textAlign: 'right', mt: 0.5 }}>
                <Button
                  variant="contained"
                  size="small"
                  onClick={() => {
                    onCloseConnection(c.id);
                    onClose();
                  }}
                >
                  {t('activity.close')}
                </Button>
              </Box>
            )}
          </Box>
        )
      }
    />
  );
}
