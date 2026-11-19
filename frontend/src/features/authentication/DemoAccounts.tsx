import { useDemoAccounts } from './demoAccountsApi'

// Development only: the demo boards, schools and logins. Picking a login fills the form.
// Shows nothing when the API does not list demo accounts.
export function DemoAccounts({ onPick }: { onPick: (email: string, password: string) => void }) {
  const { data } = useDemoAccounts()
  if (!data) return null

  return (
    <section
      aria-labelledby="demo-accounts-heading"
      className="space-y-4 rounded-lg border border-dashed border-amber-400 bg-amber-50 p-6 text-sm"
    >
      <div className="space-y-1">
        <h2 id="demo-accounts-heading" className="text-lg font-semibold">
          Demo accounts
        </h2>
        <p className="text-slate-600">
          Development only. Every account uses the password{' '}
          <code className="rounded bg-white px-1 font-mono">{data.password}</code>. Pick an account to fill in the
          form.
        </p>
      </div>
      {data.boards.map((board) => (
        <div key={board.name} className="space-y-2">
          <h3 className="font-semibold">{board.name}</h3>
          <ul className="space-y-2">
            {board.schools.map((school) => (
              <li key={school.name}>
                <span className="text-slate-600">{school.name}</span>
                <div className="flex flex-wrap gap-2 pt-1">
                  {school.administrators.map((administrator) => (
                    <button
                      key={administrator.email}
                      type="button"
                      onClick={() => onPick(administrator.email, data.password)}
                      className="rounded border border-slate-300 bg-white px-2 py-1 text-left hover:border-blue-500"
                    >
                      <span className="block font-medium">{administrator.name}</span>{' '}
                      <span className="block font-mono text-xs text-slate-600">{administrator.email}</span>
                    </button>
                  ))}
                </div>
              </li>
            ))}
          </ul>
        </div>
      ))}
    </section>
  )
}
