import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { installFakeSessionApi, type FakeAccount } from '../../test/fakeSessionApi'
import { renderRoute } from '../../test/render'

const eldritch = { id: 'org-eldritch', name: 'Eldritch Shores Board of Education' }
const realms = { id: 'org-realms', name: 'United Realms District School Board' }
const innsmouth = { id: 'school-innsmouth', name: 'Innsmouth Heights Secondary School' }
const quest = { id: 'school-quest', name: 'Quest Preparatory Academy' }

const marsha: FakeAccount = {
  email: 'marsha.deepwater@eldritch-shores.example',
  password: 'permishly-demo',
  users: [{ organization: eldritch, name: 'Marsha Deepwater', schools: [innsmouth] }],
}

const morgan: FakeAccount = {
  email: 'morgan.crossway@example.com',
  password: 'permishly-demo',
  users: [
    { organization: eldritch, name: 'Morgan Crossway', schools: [innsmouth] },
    { organization: realms, name: 'Sir Morgan', schools: [quest] },
  ],
}

async function logIn(email: string, password: string) {
  const user = userEvent.setup()
  await user.type(await screen.findByLabelText('Email'), email)
  await user.type(screen.getByLabelText('Password'), password)
  await user.click(screen.getByRole('button', { name: 'Log in' }))
  return user
}

describe('School administrator login', () => {
  const originalFetch = globalThis.fetch

  beforeEach(() => {
    installFakeSessionApi([marsha, morgan])
  })

  afterEach(() => {
    globalThis.fetch = originalFetch
    vi.restoreAllMocks()
  })

  it('sends a visitor who is not logged in to the login page', async () => {
    renderRoute('/')

    expect(await screen.findByRole('heading', { name: 'Log in to Permission Ship' })).toBeInTheDocument()
  })

  it('shows the Permission Ship logo on the login page, and the wordmark in the header', async () => {
    renderRoute('/login')

    expect(await screen.findByRole('img', { name: 'Permission Ship logo' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Permission Ship' })).toHaveAttribute('href', '/')
  })

  it('logs in and shows the organization and the schools the administrator manages', async () => {
    renderRoute('/login')

    await logIn('marsha.deepwater@eldritch-shores.example', 'permishly-demo')

    expect(await screen.findByRole('heading', { name: 'Eldritch Shores Board of Education' })).toBeInTheDocument()
    expect(screen.getByText('Signed in as Marsha Deepwater')).toBeInTheDocument()
    expect(screen.getByRole('listitem')).toHaveTextContent('Innsmouth Heights Secondary School')
  })

  it('shows the server error when the password is wrong', async () => {
    renderRoute('/login')

    await logIn('marsha.deepwater@eldritch-shores.example', 'wrong password')

    expect(await screen.findByRole('alert')).toHaveTextContent('Email or password is incorrect.')
    expect(screen.getByRole('heading', { name: 'Log in to Permission Ship' })).toBeInTheDocument()
  })

  it('asks a person in two organizations to pick one, then shows that organization', async () => {
    renderRoute('/login')

    const user = await logIn('morgan.crossway@example.com', 'permishly-demo')
    await user.click(await screen.findByRole('button', { name: 'United Realms District School Board' }))

    expect(await screen.findByRole('heading', { name: 'United Realms District School Board' })).toBeInTheDocument()
    expect(screen.getByText('Signed in as Sir Morgan')).toBeInTheDocument()
    expect(screen.getByRole('listitem')).toHaveTextContent('Quest Preparatory Academy')
  })

  it('logs out and returns to the login page', async () => {
    renderRoute('/login')
    const user = await logIn('marsha.deepwater@eldritch-shores.example', 'permishly-demo')

    await user.click(await screen.findByRole('button', { name: 'Log out' }))

    expect(await screen.findByRole('heading', { name: 'Log in to Permission Ship' })).toBeInTheDocument()
  })
})
