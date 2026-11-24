// A fake of the Rails invitation acceptance API (/api/v1/invitation_acceptances),
// installed over the fake session API. It follows the contract in
// backend/spec/requests/api/v1/invitation_acceptances_spec.rb.

export type FakeInvitation = {
  token: string
  email: string
  name: string
  role: 'admin' | 'assistant_admin'
  school_name: string
  inviter_name: string | null
  // The password of the person's existing account, or null when they have none.
  existingPassword: string | null
}

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

const error = (status: number, field: string | null, code: string, message: string) =>
  json(status, { errors: [{ field, code, message }] })

const linkInvalid = () =>
  error(404, null, 'invitation_link_invalid', 'This invitation link does not work. Ask for a new invitation.')

// Install the fake session API first. Acceptance logs in to it with the email and password,
// so give it an account with the invitation's email and the password the test uses.
export function installFakeInvitationApi(invitation: FakeInvitation) {
  const sessionFetch = globalThis.fetch
  let accepted = false
  const requests: { url: string; body: unknown }[] = []

  const fetch = async (input: RequestInfo | URL, init: RequestInit = {}) => {
    const url = String(input)
    const body = init.body ? JSON.parse(String(init.body)) : {}
    if (!url.includes('/api/v1/invitation_acceptances')) return sessionFetch(input, init)

    requests.push({ url, body })
    if (body.token !== invitation.token || accepted) return linkInvalid()

    if (url.endsWith('/preview')) {
      const { token: _token, existingPassword, ...preview } = invitation
      return json(200, { ...preview, has_account: existingPassword !== null })
    }
    if (invitation.existingPassword !== null && body.password !== invitation.existingPassword) {
      return error(422, 'password', 'incorrect_password', 'The password is not correct for this email address.')
    }
    accepted = true
    await sessionFetch('/api/v1/session', {
      method: 'POST',
      body: JSON.stringify({ email: invitation.email, password: body.password }),
    })
    return new Response(null, { status: 204 })
  }

  globalThis.fetch = fetch as typeof globalThis.fetch
  return { requests }
}
