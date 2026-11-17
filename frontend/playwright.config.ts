import { defineConfig, devices } from '@playwright/test'

// Browser tests of critical user journeys. They run against the real Rails API
// and the development database with its demo data (backend/db/seeds/demo.rb).
// The servers use their own ports, so the tests can run while bin/dev runs.
const apiPort = 3101
const webPort = 5174

export default defineConfig({
  testDir: './e2e',
  testMatch: '**/*.e2e.ts',
  forbidOnly: !!process.env.CI,
  reporter: process.env.CI ? 'github' : 'list',
  use: {
    baseURL: `http://localhost:${webPort}`,
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: [
    {
      // db:seed is idempotent. It makes sure the demo accounts exist.
      command: `bin/rails db:seed && bin/rails server -p ${apiPort} -P tmp/pids/e2e.pid`,
      cwd: '../backend',
      url: `http://localhost:${apiPort}/up`,
      reuseExistingServer: false,
      timeout: 60_000,
    },
    {
      command: `npm run dev -- --port ${webPort} --strictPort`,
      env: { API_URL: `http://localhost:${apiPort}` },
      url: `http://localhost:${webPort}`,
      reuseExistingServer: false,
    },
  ],
})
