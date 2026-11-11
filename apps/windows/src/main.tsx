import { CssBaseline, ThemeProvider } from '@mui/material';
import { type ComponentType, StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { useSnapshot } from 'valtio';
import { invoke } from './ipc';
import { Layout } from './layout/Layout';
import Home from './pages/Home';
import Proxies from './pages/Proxies';
import Profiles from './pages/Profiles';
import Connections from './pages/Connections';
import Rules from './pages/Rules';
import Logs from './pages/Logs';
import Whitelist from './pages/Whitelist';
import Settings from './pages/Settings';
import { app, applyLanguage, init, type PageId } from './state/core';
import { loadSettings } from './state/settings';
import { useAppTheme } from './state/theme';
import { startUpdateCheck } from './state/update';
import './styles.css';

const pages: Record<PageId, ComponentType> = {
  home: Home,
  proxies: Proxies,
  profiles: Profiles,
  connections: Connections,
  rules: Rules,
  logs: Logs,
  whitelist: Whitelist,
  settings: Settings,
};

function App() {
  const { page, language } = useSnapshot(app);
  const theme = useAppTheme();
  const Page = pages[page];
  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Layout key={language}>
        <Page />
      </Layout>
    </ThemeProvider>
  );
}

const [info] = await Promise.all([invoke('app_info'), loadSettings()]);
applyLanguage(info.language);
app.version = info.version;

document.addEventListener('contextmenu', (event) => {
  if (!(event.target as Element).closest('input, textarea, .selectable')) event.preventDefault();
});

createRoot(document.getElementById('app')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
init();
startUpdateCheck();
