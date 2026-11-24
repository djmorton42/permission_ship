import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it } from 'vitest'
import { installFakeInvitationApi, type FakeInvitation } from '../../test/fakeInvitationApi'
import { installFakeSessionApi } from '../../test/fakeSessionApi'
import { renderRoute } from '../../test/render'

const eldritch = { id: 'org-eldritch', name: 'Eldritch Shores Board of Education' }
const innsmouth = { id: 'school-innsmouth', name: 'Innsmouth Heights Secondary School' }

const invitation: FakeInvitation = {
  token: 'signed-token',
  email: 'zadok.allen@example.com',
  name: 'Zadok Allen',
  role: 'assistant_admin',
  school_name: 'Innsmouth Heights Secondary School',
  inviter_name: 'Marsha Deepwater',
  existingPassword: null,
}

function install(password: string, overrides: Partial<FakeInvitation> = {}) {
  installFakeSessionApi([
    {
      email: invitation.email,
      password,
      users: [{ organization: eldritch, name: 'Zadok Allen', schools: [innsmouth] }],
    },
  ])
  return installFakeInvitationApi({ ...invitation, ...overrides })
}

describe('Accepting an invitation', () => {
  const originalFetch = globalThis.fetch

  afterEach(() => {
    globalThis.fetch = originalFetch
  })

  it('shows the invitation, lets a new person set a password, and logs them in', async () => {
    const api = install('a long password')
    renderRoute('/invitations/accept#token=signed-token')
    const user = userEvent.setup()

    expect(await screen.findByRole('heading', { name: 'Join Innsmouth Heights Secondary School' })).toBeInTheDocument()
    expect(
      screen.getByText('Marsha Deepwater invited you to administer Innsmouth Heights Secondary School as an assistant admin.'),
    ).toBeInTheDocument()
    expect(screen.getByLabelText('Email')).toHaveValue('zadok.allen@example.com')

    await user.type(screen.getByLabelText('New password'), 'a long password')
    await user.type(screen.getByLabelText('Confirm new password'), 'a long password')
    await user.click(screen.getByRole('button', { name: 'Accept invitation' }))

    expect(await screen.findByText('Signed in as Zadok Allen')).toBeInTheDocument()
    expect(api.requests.at(-1)?.body).toEqual({ token: 'signed-token', password: 'a long password' })
  })

  it('does not send passwords that do not match', async () => {
    const api = install('a long password')
    renderRoute('/invitations/accept#token=signed-token')
    const user = userEvent.setup()

    await user.type(await screen.findByLabelText('New password'), 'a long password')
    await user.type(screen.getByLabelText('Confirm new password'), 'a lung password')
    await user.click(screen.getByRole('button', { name: 'Accept invitation' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('The passwords do not match.')
    expect(api.requests).toHaveLength(1)
  })

  it('asks a person with an account for their password, and shows the error when it is wrong', async () => {
    install('my own password', { existingPassword: 'my own password', role: 'admin', inviter_name: null })
    renderRoute('/invitations/accept#token=signed-token')
    const user = userEvent.setup()

    expect(
      await screen.findByText('You are invited to administer Innsmouth Heights Secondary School as an admin.'),
    ).toBeInTheDocument()
    expect(screen.queryByLabelText('New password')).not.toBeInTheDocument()

    await user.type(screen.getByLabelText('Password'), 'a guess')
    await user.click(screen.getByRole('button', { name: 'Accept invitation' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('The password is not correct for this email address.')

    await user.clear(screen.getByLabelText('Password'))
    await user.type(screen.getByLabelText('Password'), 'my own password')
    await user.click(screen.getByRole('button', { name: 'Accept invitation' }))
    expect(await screen.findByText('Signed in as Zadok Allen')).toBeInTheDocument()
  })

  it('explains a link that does not work', async () => {
    install('a long password')
    renderRoute('/invitations/accept#token=an-old-token')

    expect(await screen.findByRole('heading', { name: 'This invitation link does not work' })).toBeInTheDocument()
    expect(screen.getByText('This invitation link does not work. Ask for a new invitation.')).toBeInTheDocument()
  })

  it('explains a link without a token', async () => {
    const api = install('a long password')
    renderRoute('/invitations/accept')

    expect(await screen.findByRole('heading', { name: 'This invitation link does not work' })).toBeInTheDocument()
    expect(api.requests).toHaveLength(0)
  })
})
