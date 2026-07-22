// @vitest-environment jsdom

import { afterEach, describe, expect, it } from 'vitest'
import {
  cleanup,
  fireEvent,
  render,
  screen,
  within,
} from '@testing-library/react'

import { Compare } from './Compare'
import { Header } from './Header'
import { ProductTour } from './ProductTour'

afterEach(cleanup)

describe('landing page accessibility', () => {
  it('opens and closes the mobile navigation with keyboard focus restored', () => {
    render(<Header />)

    const toggle = screen.getByRole('button', { name: 'Open menu' })
    fireEvent.click(toggle)

    const navigation = screen.getByRole('navigation', {
      name: 'Mobile primary',
    })
    expect(toggle.getAttribute('aria-expanded')).toBe('true')
    expect(within(navigation).getByRole('link', { name: 'Features' })).toBe(
      document.activeElement,
    )

    fireEvent.keyDown(window, { key: 'Escape' })

    expect(toggle.getAttribute('aria-expanded')).toBe('false')
    expect(toggle).toBe(document.activeElement)
  })

  it('gives the scrollable comparison and icon-only values readable names', () => {
    render(<Compare />)

    const region = screen.getByRole('region', {
      name: 'Product comparison table',
    })
    expect(region.getAttribute('tabindex')).toBe('0')

    const table = within(region).getByRole('table')
    expect(
      within(table).getByRole('columnheader', { name: 'Feature' }),
    ).toBeTruthy()
    expect(within(table).getAllByText('Yes').length).toBeGreaterThan(0)
    expect(within(table).getAllByText('No').length).toBeGreaterThan(0)
  })

  it('activates every product-tour tab', () => {
    render(<ProductTour />)

    for (const name of ['Overview', 'By Kind', 'Uninstall', 'Cleanup']) {
      const tab = screen.getByRole('tab', { name })
      fireEvent.mouseDown(tab, { button: 0, ctrlKey: false })
      expect(tab.getAttribute('aria-selected')).toBe('true')
    }
  })
})
