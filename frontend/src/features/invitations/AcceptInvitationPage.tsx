import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useState, type FormEvent } from 'react'
import { useLocation, useNavigate } from 'react-router'
import { errorMessage } from '../../lib/api'
import { sessionQueryKey } from '../authentication/sessionApi'
import { acceptInvitation, previewInvitation, type InvitationPreview } from './invitationApi'

const roleNames = { admin: 'an admin', assistant_admin: 'an assistant admin' } as const

const inputClass =
  'w-full rounded border border-slate-300 px-3 py-2 focus:border-brand-600 focus:ring-2 focus:ring-brand-200 focus:outline-none'

// The link in an invitation email: /invitations/accept#token=...
// The token is after #, so the browser does not send it to a server.
export function AcceptInvitationPage() {
  const location = useLocation()
  const navigate = useNavigate()
  const [token] = useState(() => new URLSearchParams(location.hash.slice(1)).get('token'))

  // Remove the token from the address bar and browser history.
  useEffect(() => {
    if (location.hash) navigate({ hash: '' }, { replace: true })
  }, [location.hash, navigate])

  const preview = useQuery({
    queryKey: ['invitations', 'preview', token],
    queryFn: () => previewInvitation(token ?? ''),
    enabled: token !== null,
    retry: false,
    staleTime: Infinity,
  })

  if (token === null) {
    return <LinkDoesNotWork message="The link has no invitation in it. Open the link from the email again." />
  }
  if (preview.isPending) return <p>Loading…</p>
  if (preview.isError) {
    return <LinkDoesNotWork message={errorMessage(preview.error, 'Could not load the invitation. Try again later.')} />
  }

  return <AcceptForm token={token} invitation={preview.data} />
}

function LinkDoesNotWork({ message }: { message: string }) {
  return (
    <section className="mx-auto max-w-sm space-y-4 pt-8">
      <h1 className="text-2xl font-bold text-brand-900">This invitation link does not work</h1>
      <p>{message}</p>
    </section>
  )
}

function AcceptForm({ token, invitation }: { token: string; invitation: InvitationPreview }) {
  const [password, setPassword] = useState('')
  const [confirmation, setConfirmation] = useState('')
  const [mismatch, setMismatch] = useState(false)
  const queryClient = useQueryClient()
  const navigate = useNavigate()

  const accept = useMutation({
    mutationFn: () => acceptInvitation(token, password),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: sessionQueryKey })
      navigate('/', { replace: true })
    },
  })

  const submit = (event: FormEvent) => {
    event.preventDefault()
    const newPasswordMismatch = !invitation.has_account && password !== confirmation
    setMismatch(newPasswordMismatch)
    if (!newPasswordMismatch) accept.mutate()
  }

  const role = roleNames[invitation.role]
  const error = mismatch
    ? 'The passwords do not match.'
    : accept.isError && errorMessage(accept.error, 'Could not accept the invitation. Try again.')

  return (
    <section className="mx-auto max-w-sm space-y-6 pt-8">
      <div className="space-y-2">
        <h1 className="text-2xl font-bold text-brand-900">Join {invitation.school_name}</h1>
        <p>
          {invitation.inviter_name
            ? `${invitation.inviter_name} invited you to administer ${invitation.school_name} as ${role}.`
            : `You are invited to administer ${invitation.school_name} as ${role}.`}
        </p>
        <p className="text-sm text-slate-600">
          {invitation.has_account
            ? 'You have an account. Enter your password to accept.'
            : 'Set a password for your new account to accept.'}
        </p>
      </div>
      <form onSubmit={submit} className="space-y-4 rounded-lg border border-slate-200 bg-white p-6">
        <div className="space-y-1">
          <label htmlFor="email" className="block text-sm font-medium">
            Email
          </label>
          {/* Read-only, so password managers save the password for this email. */}
          <input
            id="email"
            type="email"
            autoComplete="username"
            readOnly
            value={invitation.email}
            className={`${inputClass} bg-slate-100`}
          />
        </div>
        {invitation.has_account ? (
          <PasswordField
            id="password"
            label="Password"
            autoComplete="current-password"
            value={password}
            onChange={setPassword}
          />
        ) : (
          <>
            <PasswordField
              id="new-password"
              label="New password"
              autoComplete="new-password"
              value={password}
              onChange={setPassword}
            />
            <PasswordField
              id="confirm-password"
              label="Confirm new password"
              autoComplete="new-password"
              value={confirmation}
              onChange={setConfirmation}
            />
          </>
        )}
        {error && (
          <p role="alert" className="text-sm text-red-600">
            {error}
          </p>
        )}
        <button
          type="submit"
          disabled={accept.isPending}
          className="w-full rounded bg-brand-900 px-4 py-2 font-medium text-white hover:bg-brand-700 disabled:opacity-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-600"
        >
          {accept.isPending ? 'Accepting…' : 'Accept invitation'}
        </button>
      </form>
    </section>
  )
}

type PasswordFieldProps = {
  id: string
  label: string
  autoComplete: 'current-password' | 'new-password'
  value: string
  onChange: (value: string) => void
}

function PasswordField({ id, label, autoComplete, value, onChange }: PasswordFieldProps) {
  return (
    <div className="space-y-1">
      <label htmlFor={id} className="block text-sm font-medium">
        {label}
      </label>
      <input
        id={id}
        type="password"
        autoComplete={autoComplete}
        required
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className={inputClass}
      />
    </div>
  )
}
