import { useQuery } from '@tanstack/react-query'
import { getHealth } from '../lib/api'

export function HomePage() {
  const { data, isPending, isError } = useQuery({ queryKey: ['health'], queryFn: getHealth })

  return (
    <section className="space-y-4">
      <h1 className="text-2xl font-bold">Welcome to Permishly</h1>
      <div className="rounded-lg border border-slate-200 bg-white p-4 text-sm">
        <h2 className="mb-2 font-medium">API status</h2>
        {isPending && <p>Checking…</p>}
        {isError && <p className="text-red-600">API unreachable</p>}
        {data && (
          <ul className="space-y-1">
            <li>API: {data.status}</li>
            <li>Database: {data.database ? 'ok' : 'down'}</li>
            <li>Background jobs: {data.jobs ? 'ok' : 'down'}</li>
          </ul>
        )}
      </div>
    </section>
  )
}
