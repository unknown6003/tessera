import { describe, expect, it } from 'vitest'

import { cn } from './utils'

describe('cn', () => {
  it('combines class names from supported input shapes', () => {
    expect(cn('button', ['active'])).toBe('button active')
  })

  it('keeps the last conflicting Tailwind utility', () => {
    expect(cn('px-2 text-sm', 'px-4', undefined, 'text-lg')).toBe(
      'px-4 text-lg',
    )
  })
})
