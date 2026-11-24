import { apiFetch } from '../../lib/api'

export type InvitationPreview = {
  email: string
  name: string
  role: 'admin' | 'assistant_admin'
  school_name: string
  // Null when the operations team sent the invitation.
  inviter_name: string | null
  // True when the email has an account. The person then gives their password, not a new one.
  has_account: boolean
}

// The token goes in the body, not the URL, so it does not reach server logs.
export const previewInvitation = (token: string) =>
  apiFetch<InvitationPreview>('/invitation_acceptances/preview', {
    method: 'POST',
    body: JSON.stringify({ token }),
  })

export const acceptInvitation = (token: string, password: string) =>
  apiFetch<null>('/invitation_acceptances', { method: 'POST', body: JSON.stringify({ token, password }) })
