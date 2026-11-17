import { screen } from '@testing-library/react'
import { afterEach, describe, expect, it } from 'vitest'
import { installFakeSessionApi } from './test/fakeSessionApi'
import { renderRoute } from './test/render'

describe('routes', () => {
  const originalFetch = globalThis.fetch

  afterEach(() => {
    globalThis.fetch = originalFetch
  })

  it('renders not found for unknown routes', () => {
    installFakeSessionApi([])

    renderRoute('/nope')

    expect(screen.getByText('Page not found')).toBeInTheDocument()
  })
})
