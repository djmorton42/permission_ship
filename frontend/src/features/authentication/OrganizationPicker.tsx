import { useMutation, useQueryClient } from '@tanstack/react-query'
import { errorMessage } from '../../lib/api'
import { chooseOrganization, sessionQueryKey, type Summary } from './sessionApi'

// Shown after login when the person has a user in more than one organization.
export function OrganizationPicker({ organizations }: { organizations: Summary[] }) {
  const queryClient = useQueryClient()
  const choose = useMutation({
    mutationFn: chooseOrganization,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: sessionQueryKey }),
  })

  return (
    <section className="mx-auto max-w-sm space-y-4 pt-8">
      <h1 className="text-2xl font-bold">Choose an organization</h1>
      <div className="space-y-2">
        {organizations.map((organization) => (
          <button
            key={organization.id}
            type="button"
            disabled={choose.isPending}
            onClick={() => choose.mutate(organization.id)}
            className="block w-full rounded-lg border border-slate-200 bg-white px-4 py-3 text-left hover:border-blue-600 disabled:opacity-50"
          >
            {organization.name}
          </button>
        ))}
      </div>
      {choose.isError && (
        <p role="alert" className="text-sm text-red-600">
          {errorMessage(choose.error, 'Could not choose the organization. Try again.')}
        </p>
      )}
    </section>
  )
}
