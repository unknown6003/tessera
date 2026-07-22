import { cn } from '#/lib/utils.ts'

/**
 * Layout wrapper retained for consistent section composition. Content is never
 * hidden behind JavaScript or IntersectionObserver state: browser automation
 * exposed that a missed observer callback could leave the entire hero blank.
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
  return (
    <As
      className={cn('reveal', className)}
      style={delay ? { transitionDelay: `${delay}ms` } : undefined}
    >
      {children}
    </As>
  )
}
