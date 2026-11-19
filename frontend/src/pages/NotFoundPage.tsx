import { Link } from 'react-router'

export function NotFoundPage() {
  return (
    <section className="space-y-2">
      <h1 className="text-2xl font-bold text-brand-900">Page not found</h1>
      <Link to="/" className="text-brand-700 underline hover:text-brand-900">
        Go home
      </Link>
    </section>
  )
}
