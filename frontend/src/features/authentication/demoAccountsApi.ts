import { useQuery } from '@tanstack/react-query'
import { apiFetch } from '../../lib/api'

// The demo logins from backend/db/seeds/demo_data.rb.
// The endpoint exists only when Rails runs in development or test.
export type DemoAccounts = {
  password: string
  boards: {
    name: string
    schools: { name: string; administrators: { name: string; email: string }[] }[]
  }[]
}

export const useDemoAccounts = () =>
  useQuery({
    queryKey: ['development', 'demoAccounts'],
    queryFn: () => apiFetch<DemoAccounts>('/development/demo_accounts'),
    // A production build never asks. Vite replaces import.meta.env.DEV with false.
    enabled: import.meta.env.DEV,
    retry: false,
    staleTime: Infinity,
  })
