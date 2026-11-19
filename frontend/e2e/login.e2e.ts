import { expect, test } from '@playwright/test'

// A demo account from backend/db/seeds/demo.rb.
const administrator = {
  email: 'marsha.deepwater@eldritch-shores.example',
  password: 'permishly-demo',
}

test('a school administrator logs in, sees their school, and logs out', async ({ page }) => {
  await page.goto('/')
  await expect(page).toHaveTitle('Permission Ship')
  await expect(page.getByRole('heading', { name: 'Log in to Permission Ship' })).toBeVisible()

  await page.getByLabel('Email').fill(administrator.email)
  await page.getByLabel('Password').fill(administrator.password)
  await page.getByRole('button', { name: 'Log in' }).click()

  await expect(page.getByRole('heading', { name: 'Eldritch Shores Board of Education' })).toBeVisible()
  await expect(page.getByText('Signed in as Marsha Deepwater')).toBeVisible()
  await expect(page.getByRole('listitem')).toHaveText(['Innsmouth Heights Secondary School'])

  // The session survives a page reload (the session cookie works in a real browser).
  await page.reload()
  await expect(page.getByText('Signed in as Marsha Deepwater')).toBeVisible()

  await page.getByRole('button', { name: 'Log out' }).click()
  await expect(page.getByRole('heading', { name: 'Log in to Permission Ship' })).toBeVisible()
  await page.goto('/')
  await expect(page.getByRole('heading', { name: 'Log in to Permission Ship' })).toBeVisible()
})

test('a wrong password shows an error', async ({ page }) => {
  await page.goto('/login')

  await page.getByLabel('Email').fill(administrator.email)
  await page.getByLabel('Password').fill('not the password')
  await page.getByRole('button', { name: 'Log in' }).click()

  await expect(page.getByRole('alert')).toHaveText('Email or password is incorrect.')
})

test('in development, a demo account from the list logs in', async ({ page }) => {
  await page.goto('/login')

  const demoAccounts = page.getByRole('region', { name: 'Demo accounts' })
  await expect(demoAccounts.getByRole('heading', { name: 'United Realms District School Board' })).toBeVisible()
  // Morgan Crossway administers a school in two boards, so login shows the board picker.
  await demoAccounts.getByRole('button', { name: /morgan\.crossway@example\.com/ }).first().click()
  await page.getByRole('button', { name: 'Log in' }).click()

  await page.getByRole('button', { name: 'United Realms District School Board' }).click()
  await expect(page.getByText('Signed in as Morgan Crossway')).toBeVisible()
  await expect(page.getByRole('listitem')).toHaveText(['Quest Preparatory Academy'])

  await page.getByRole('button', { name: 'Log out' }).click()
})
