import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './ui-tests',
  fullyParallel: true,
  workers: 2,
  timeout: 30_000,
  use: { baseURL: 'http://127.0.0.1:5173', locale: 'en-US', trace: 'retain-on-failure' },
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
    { name: 'webkit', use: { browserName: 'webkit' } },
  ],
  webServer: { command: 'npm run dev -- --host 127.0.0.1', url: 'http://127.0.0.1:5173', reuseExistingServer: !process.env.CI },
});
