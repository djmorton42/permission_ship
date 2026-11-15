import { screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { renderRoute } from '../test/render'

describe('HomePage', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('shows API health from the backend', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        new Response(JSON.stringify({ status: 'ok', database: true, jobs: true, time: '' })),
      ),
    )

    renderRoute('/')

    expect(await screen.findByText('API: ok')).toBeInTheDocument()
    expect(screen.getByText('Database: ok')).toBeInTheDocument()
  })

  it('renders not found for unknown routes', () => {
    renderRoute('/nope')
    expect(screen.getByText('Page not found')).toBeInTheDocument()
  })
})
