import { expect, test, type Page } from '@playwright/test'
import { waitForEmail } from './support/mailpit.ts'

// A demo admin from backend/db/seeds/demo.rb.
const admin = { email: 'marsha.deepwater@eldritch-shores.example', password: 'permishly-demo' }

async function logIn(page: Page, { email, password }: { email: string; password: string }) {
  await page.goto('/login')
  await page.getByLabel('Email').fill(email)
  await page.getByLabel('Password').fill(password)
  await page.getByRole('button', { name: 'Log in' }).click()
  await expect(page.getByText('Signed in as Marsha Deepwater')).toBeVisible()
}

// The app has no screen to invite yet, so the admin invites through the API,
// with the browser's session cookie and the headers that the app sends.
async function invite(page: Page, invitee: { email: string; name: string }) {
  const session = await (await page.request.get('/api/v1/session')).json()
  const school = session.administered_schools[0]
  const response = await page.request.post(`/api/v1/schools/${school.id}/invitations`, {
    headers: { Origin: new URL(page.url()).origin },
    data: { ...invitee, role: 'assistant_admin' },
  })
  expect(response.status()).toBe(201)
}

test('an admin invites a new person, who sets a password from the email and is logged in', async ({ page }) => {
  // The test writes to the development database, so the invitee is new on each run.
  const invitee = { email: `invitee-${Date.now()}@example.com`, name: 'Zadok Allen' }
  await logIn(page, admin)

  const receivedAfter = new Date()
  await invite(page, invitee)
  const email = await waitForEmail({ to: invitee.email, receivedAfter })
  expect(email.subject).toBe('You are invited to administer Innsmouth Heights Secondary School')
  const link = email.text.match(/\S+\/invitations\/accept#token=\S+/)?.[0]
  expect(link).toBeDefined()
  expect(email.html).toContain(link)

  await page.goto(link!)
  await expect(page.getByRole('heading', { name: 'Join Innsmouth Heights Secondary School' })).toBeVisible()
  await expect(
    page.getByText('Marsha Deepwater invited you to administer Innsmouth Heights Secondary School as an assistant admin.'),
  ).toBeVisible()
  // The page removes the token from the address bar.
  expect(page.url()).not.toContain('token')

  await page.getByLabel('New password', { exact: true }).fill('a long password')
  await page.getByLabel('Confirm new password').fill('a long password')
  await page.getByRole('button', { name: 'Accept invitation' }).click()

  await expect(page.getByText('Signed in as Zadok Allen')).toBeVisible()
  await expect(page.getByRole('listitem')).toHaveText(['Innsmouth Heights Secondary School'])

  // The link works once.
  await page.goto(link!)
  await expect(page.getByRole('heading', { name: 'This invitation link does not work' })).toBeVisible()
})
