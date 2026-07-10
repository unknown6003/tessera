import { useEffect, useRef, useState } from 'react'
import { cn } from '#/lib/utils.ts'

/**
 * Fade-up on scroll into view. No-JS safe (the `.reveal` hidden state is gated
 * on `html.js` in CSS) and honors prefers-reduced-motion.
 */
export function Reveal({
  children,
  className,
  delay = 0,
  as: As = 'div',
}: {
  children: React.ReactNode
  className?: string
  delay?: number
  as?: React.ElementType
}) {
  const ref = useRef<HTMLElement | null>(null)
  const [shown, setShown] = useState(false)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) {
            setShown(true)
            io.disconnect()
          }
        }
      },
      { threshold: 0.12, rootMargin: '0px 0px -8% 0px' },
    )
    io.observe(el)
    return () => io.disconnect()
  }, [])

  return (
    <As
      ref={ref}
      className={cn('reveal', shown && 'in', className)}
      style={delay ? { transitionDelay: `${delay}ms` } : undefined}
    >
      {children}
    </As>
  )
}
