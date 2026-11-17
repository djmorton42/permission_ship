import { Navigate } from 'react-router'
import { OrganizationPicker } from '../features/authentication/OrganizationPicker'
import { isNotLoggedIn, useCurrentSession } from '../features/authentication/sessionApi'

export function HomePage() {
  const { data, error, isPending } = useCurrentSession()

  if (isPending) return <p>Loading…</p>
  if (isNotLoggedIn(error)) return <Navigate to="/login" replace />
  if (error) return <p className="text-red-600">Could not load your account. Try again later.</p>
  if (data.status === 'organization_required') {
    return <OrganizationPicker organizations={data.organizations} />
  }

  return (
    <section className="space-y-4">
      <div>
        <h1 className="text-2xl font-bold">{data.organization.name}</h1>
        <p className="text-sm text-slate-600">Signed in as {data.user.name}</p>
      </div>
      <div className="rounded-lg border border-slate-200 bg-white p-4">
        <h2 className="mb-2 font-medium">Schools you administer</h2>
        {data.administered_schools.length === 0 ? (
          <p className="text-sm text-slate-600">You do not administer a school.</p>
        ) : (
          <ul className="space-y-1">
            {data.administered_schools.map((school) => (
              <li key={school.id}>{school.name}</li>
            ))}
          </ul>
        )}
      </div>
    </section>
  )
}
