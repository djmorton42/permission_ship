import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { installFakeSessionApi, type FakeAccount } from '../../test/fakeSessionApi'
import { renderRoute } from '../../test/render'
import type { DemoAccounts } from './demoAccountsApi'

const eldritch = { id: 'org-eldritch', name: 'Eldritch Shores Board of Education' }
const innsmouth = { id: 'school-innsmouth', name: 'Innsmouth Heights Secondary School' }

const marsha: FakeAccount = {
  email: 'marsha.deepwater@eldritch-shores.example',
  password: 'permishly-demo',
  users: [{ organization: eldritch, name: 'Marsha Deepwater', schools: [innsmouth] }],
}

const demoAccounts: DemoAccounts = {
  password: 'permishly-demo',
  boards: [
    {
      name: 'Eldritch Shores Board of Education',
      schools: [
        {
          name: 'Innsmouth Heights Secondary School',
          administrators: [{ name: 'Marsha Deepwater', email: 'marsha.deepwater@eldritch-shores.example' }],
        },
      ],
    },
  ],
}

// In development, the login page lists the demo logins from backend/db/seeds/demo_data.rb.
describe('Demo accounts on the login page', () => {
  const originalFetch = globalThis.fetch

  afterEach(() => {
    globalThis.fetch = originalFetch
  })

  describe('when the API lists demo accounts', () => {
    beforeEach(() => {
      installFakeSessionApi([marsha], { demoAccounts })
    })

    it('shows each board, its schools, the administrators and the password', async () => {
      renderRoute('/login')

      const panel = await screen.findByRole('region', { name: 'Demo accounts' })
      expect(within(panel).getByText('permishly-demo')).toBeInTheDocument()
      expect(within(panel).getByRole('heading', { name: 'Eldritch Shores Board of Education' })).toBeInTheDocument()
      expect(within(panel).getByText('Innsmouth Heights Secondary School')).toBeInTheDocument()
      expect(
        within(panel).getByRole('button', { name: 'Marsha Deepwater marsha.deepwater@eldritch-shores.example' }),
      ).toBeInTheDocument()
    })

    it('fills the login form with a picked account, which then logs in', async () => {
      const user = userEvent.setup()
      renderRoute('/login')

      await user.click(await screen.findByRole('button', { name: /Marsha Deepwater/ }))

      expect(screen.getByLabelText('Email')).toHaveValue('marsha.deepwater@eldritch-shores.example')
      expect(screen.getByLabelText('Password')).toHaveValue('permishly-demo')

      await user.click(screen.getByRole('button', { name: 'Log in' }))
      expect(await screen.findByText('Signed in as Marsha Deepwater')).toBeInTheDocument()
    })
  })

  it('shows nothing when the API has no demo accounts', async () => {
    installFakeSessionApi([marsha])
    const requests: string[] = []
    const fakeFetch = globalThis.fetch
    globalThis.fetch = (input, init) => {
      requests.push(String(input))
      return fakeFetch(input, init)
    }

    renderRoute('/login')

    await screen.findByRole('heading', { name: 'Log in to Permishly' })
    await vi.waitFor(() => expect(requests.some((url) => url.endsWith('/development/demo_accounts'))).toBe(true))
    await new Promise((resolve) => setTimeout(resolve, 0))
    expect(screen.queryByRole('region', { name: 'Demo accounts' })).not.toBeInTheDocument()
  })
})
