import { Card } from '#/components/ui/card.tsx'
import { cn } from '#/lib/utils.ts'

/**
 * A real product screenshot. The capture already includes the app's native
 * macOS window chrome (title bar + traffic lights), so we simply frame it in
 * a rounded, shadowed shadcn `Card` — no synthetic chrome on top.
 */
export function Screenshot({
  src,
  alt,
  priority = false,
  className,
}: {
  src: string
  alt: string
  title?: string
  priority?: boolean
  className?: string
}) {
  return (
    <Card
      className={cn(
        'overflow-hidden rounded-xl border-border bg-card p-0 shadow-[var(--shadow-lg)]',
        className,
      )}
    >
      <img
        src={src}
        alt={alt}
        loading={priority ? 'eager' : 'lazy'}
        decoding="async"
        className="block w-full"
      />
    </Card>
  )
}
