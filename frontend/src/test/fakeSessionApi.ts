// A fake of the Rails session API (/api/v1/session), installed as global fetch.
// It follows the contract in backend/spec/requests/api/v1/session_spec.rb.

type Organization = { id: string; name: string }

export type FakeAccount = {
  email: string
  password: string
  // One entry per organization where the person has a user.
  users: { organization: Organization; name: string; schools: Organization[] }[]
}

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

const error = (status: number, code: string, message: string) =>
  json(status, { errors: [{ field: null, code, message }] })

export function installFakeSessionApi(accounts: FakeAccount[]) {
  let account: FakeAccount | null = null
  let organizationId: string | null = null

  const fetch = async (input: RequestInfo | URL, init: RequestInit = {}) => {
    const url = String(input)
    const method = init.method ?? 'GET'
    const body = init.body ? JSON.parse(String(init.body)) : {}

    if (url.endsWith('/api/v1/session') && method === 'POST') {
      const match = accounts.find((a) => a.email === body.email && a.password === body.password)
      if (!match) return error(401, 'invalid_credentials', 'Email or password is incorrect.')
      account = match
      organizationId = match.users.length === 1 ? match.users[0].organization.id : null
      return new Response(null, { status: 204 })
    }
    if (url.endsWith('/api/v1/session') && method === 'GET') {
      if (!account) return error(401, 'not_logged_in', 'Log in to continue.')
      const user = account.users.find((u) => u.organization.id === organizationId)
      if (!user) {
        return json(200, {
          status: 'organization_required',
          organizations: account.users.map((u) => u.organization),
        })
      }
      return json(200, {
        status: 'signed_in',
        user: { name: user.name },
        organization: user.organization,
        administered_schools: user.schools,
      })
    }
    if (url.endsWith('/api/v1/session/organization') && method === 'POST') {
      if (!account) return error(401, 'not_logged_in', 'Log in to continue.')
      if (!account.users.some((u) => u.organization.id === body.organization_id)) {
        return error(403, 'not_a_member', 'You are not a member of this organization.')
      }
      organizationId = body.organization_id
      return new Response(null, { status: 204 })
    }
    if (url.endsWith('/api/v1/session') && method === 'DELETE') {
      account = null
      organizationId = null
      return new Response(null, { status: 204 })
    }
    return error(404, 'not_found', `No fake for ${method} ${url}`)
  }

  globalThis.fetch = fetch as typeof globalThis.fetch
}
