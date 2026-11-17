import { useQuery } from '@tanstack/react-query'
import { ApiError, apiFetch } from '../../lib/api'

export type Summary = { id: string; name: string }

export type CurrentSession =
  | {
      status: 'signed_in'
      user: { name: string }
      organization: Summary
      administered_schools: Summary[]
    }
  | { status: 'organization_required'; organizations: Summary[] }

export const sessionQueryKey = ['authentication', 'session'] as const

export const getSession = () => apiFetch<CurrentSession>('/session')

export const logIn = (email: string, password: string) =>
  apiFetch<null>('/session', { method: 'POST', body: JSON.stringify({ email, password }) })

export const chooseOrganization = (organizationId: string) =>
  apiFetch<null>('/session/organization', {
    method: 'POST',
    body: JSON.stringify({ organization_id: organizationId }),
  })

export const logOut = () => apiFetch<null>('/session', { method: 'DELETE' })

export const isNotLoggedIn = (error: unknown) => error instanceof ApiError && error.status === 401

export function useCurrentSession() {
  return useQuery({
    queryKey: sessionQueryKey,
    queryFn: getSession,
    // "Not logged in" is an answer, not a failure to retry.
    retry: (failureCount, error) => !isNotLoggedIn(error) && failureCount < 3,
  })
}
