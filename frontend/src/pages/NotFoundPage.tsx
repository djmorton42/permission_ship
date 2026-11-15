import { Link } from 'react-router'

export function NotFoundPage() {
  return (
    <section className="space-y-2">
      <h1 className="text-2xl font-bold">Page not found</h1>
      <Link to="/" className="text-blue-600 underline">
        Go home
      </Link>
    </section>
  )
}
