import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { useNavigate } from 'react-router'
import stackedLogo from '../../assets/brand/permission-ship-stacked-logo.png'
import { errorMessage } from '../../lib/api'
import { DemoAccounts } from './DemoAccounts'
import { logIn, sessionQueryKey } from './sessionApi'

export function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const queryClient = useQueryClient()
  const navigate = useNavigate()

  const login = useMutation({
    mutationFn: () => logIn(email, password),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: sessionQueryKey })
      navigate('/', { replace: true })
    },
  })

  const submit = (event: FormEvent) => {
    event.preventDefault()
    login.mutate()
  }

  return (
    <section className="mx-auto max-w-sm space-y-6 pt-8">
      <img src={stackedLogo} alt="Permission Ship logo" width={360} height={180} className="mx-auto h-auto w-60" />
      <h1 className="text-2xl font-bold text-brand-900">Log in to Permission Ship</h1>
      <form onSubmit={submit} className="space-y-4 rounded-lg border border-slate-200 bg-white p-6">
        <div className="space-y-1">
          <label htmlFor="email" className="block text-sm font-medium">
            Email
          </label>
          <input
            id="email"
            type="email"
            autoComplete="username"
            required
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            className="w-full rounded border border-slate-300 px-3 py-2 focus:border-brand-600 focus:ring-2 focus:ring-brand-200 focus:outline-none"
          />
        </div>
        <div className="space-y-1">
          <label htmlFor="password" className="block text-sm font-medium">
            Password
          </label>
          <input
            id="password"
            type="password"
            autoComplete="current-password"
            required
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            className="w-full rounded border border-slate-300 px-3 py-2 focus:border-brand-600 focus:ring-2 focus:ring-brand-200 focus:outline-none"
          />
        </div>
        {login.isError && (
          <p role="alert" className="text-sm text-red-600">
            {errorMessage(login.error, 'Could not log in. Try again.')}
          </p>
        )}
        <button
          type="submit"
          disabled={login.isPending}
          className="w-full rounded bg-brand-900 px-4 py-2 font-medium text-white hover:bg-brand-700 disabled:opacity-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-600"
        >
          {login.isPending ? 'Logging in…' : 'Log in'}
        </button>
      </form>
      {import.meta.env.DEV && (
        <DemoAccounts
          onPick={(pickedEmail, pickedPassword) => {
            setEmail(pickedEmail)
            setPassword(pickedPassword)
          }}
        />
      )}
    </section>
  )
}
