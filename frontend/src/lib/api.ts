// Thin fetch wrapper for the Rails API (versioned under /api/v1).

export const API_BASE = `${import.meta.env.VITE_API_URL ?? ''}/api/v1`

export class ApiError extends Error {
  readonly status: number
  readonly body: unknown

  constructor(status: number, body: unknown) {
    super(`API request failed with status ${status}`)
    this.status = status
    this.body = body
  }
}

export async function apiFetch<T>(path: string, init: RequestInit = {}): Promise<T> {
  const response = await fetch(`${API_BASE}${path}`, {
    ...init,
    credentials: 'include',
    headers: {
      Accept: 'application/json',
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      ...init.headers,
    },
  })

  const text = await response.text()
  const body: unknown = text ? JSON.parse(text) : null

  if (!response.ok) throw new ApiError(response.status, body)
  return body as T
}

// The server's error format. See "Results and errors" in architecture.md.
export type ApiErrorBody = { errors: { field: string | null; code: string; message: string }[] }

// The first error message in an API error, or the fallback.
export function errorMessage(error: unknown, fallback: string): string {
  if (error instanceof ApiError) {
    const body = error.body as Partial<ApiErrorBody> | null
    const message = body?.errors?.[0]?.message
    if (message) return message
  }
  return fallback
}
