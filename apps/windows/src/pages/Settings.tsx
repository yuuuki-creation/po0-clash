// Page layout follows Clash Verge Rev (GPL-3.0): src/pages/settings.tsx.
import { GitHub, HelpOutlineRounded } from '@mui/icons-material';
import { Box, ButtonGroup, Grid, IconButton } from '@mui/material';
import { type ReactNode, useEffect } from 'react';
import { BasePage } from '../base';
import { t } from '../lib/i18n.js';
import { notify } from '../state/core';
import { loadOptions } from '../state/settings';
import { AdvancedCard, BasicCard, ClashCard, SystemCard } from './settings/Cards';
import { openUrl } from './settings/common';

const REPOSITORY = 'https://github.com/yuuuki-creation/po0-clash';

const Card = ({ children }: { children: ReactNode }) => <Box sx={{ borderRadius: 2, bgcolor: 'surface.card' }}>{children}</Box>;

export default function Settings() {
  useEffect(() => {
    loadOptions().catch((error) => notify(error));
  }, []);

  return (
    <BasePage
      title={t('nav.settings')}
      header={
        <ButtonGroup variant="contained" aria-label={t('nav.settings')}>
          <IconButton size="medium" color="inherit" title={t('settings.docs')} onClick={() => openUrl(`${REPOSITORY}/tree/main/docs`)}>
            <HelpOutlineRounded fontSize="inherit" />
          </IconButton>
          <IconButton size="medium" color="inherit" title={t('settings.repository')} onClick={() => openUrl(REPOSITORY)}>
            <GitHub fontSize="inherit" />
          </IconButton>
        </ButtonGroup>
      }
    >
      <Grid container spacing={1.5} columns={{ xs: 6, sm: 6, md: 12 }}>
        <Grid size={6}>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5 }}>
            <Card>
              <SystemCard />
            </Card>
            <Card>
              <ClashCard />
            </Card>
          </Box>
        </Grid>
        <Grid size={6}>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1.5 }}>
            <Card>
              <BasicCard />
            </Card>
            <Card>
              <AdvancedCard />
            </Card>
          </Box>
        </Grid>
      </Grid>
    </BasePage>
  );
}
