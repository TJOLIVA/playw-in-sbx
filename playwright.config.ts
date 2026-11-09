import { defineConfig, devices } from '@playwright/test';

// BASE_URL is set per environment (never hard-code internal URLs or credentials).
const baseURL = process.env.BASE_URL || 'https://playwright.dev';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 2 : undefined,
  reporter: [
    ['list'],
    ['html', { open: 'never' }],
    // Only enabled when an OTLP endpoint is configured (the sandbox kit sets it; CI does not).
    ...(process.env.OTEL_EXPORTER_OTLP_ENDPOINT ? [['./reporters/otlp-reporter.ts'] as [string]] : []),
  ],
  use: {
    baseURL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
