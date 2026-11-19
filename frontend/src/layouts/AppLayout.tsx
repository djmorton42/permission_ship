import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Link, Outlet, useNavigate } from 'react-router'
import wordmark from '../assets/brand/permission-ship-wordmark.png'
import { logOut, sessionQueryKey, useCurrentSession } from '../features/authentication/sessionApi'

export function AppLayout() {
  const { data: session } = useCurrentSession()
  const queryClient = useQueryClient()
  const navigate = useNavigate()

  const logout = useMutation({
    mutationFn: logOut,
    onSuccess: () => {
      queryClient.removeQueries({ queryKey: sessionQueryKey })
      navigate('/login', { replace: true })
    },
  })

  return (
    <div className="flex min-h-dvh flex-col bg-slate-50 text-slate-900">
      <header className="border-b-2 border-brand-400 bg-white">
        <div className="mx-auto flex max-w-5xl items-center justify-between px-4 py-3">
          <Link to="/" className="rounded focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-600">
            <img src={wordmark} alt="Permission Ship" width={480} height={160} className="h-8 w-auto" />
          </Link>
          {session && (
            <button
              type="button"
              onClick={() => logout.mutate()}
              disabled={logout.isPending}
              className="rounded text-sm text-slate-600 hover:text-brand-900 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-600"
            >
              Log out
            </button>
          )}
        </div>
      </header>
      <main className="mx-auto w-full max-w-5xl flex-1 px-4 py-6">
        <Outlet />
      </main>
    </div>
  )
}
