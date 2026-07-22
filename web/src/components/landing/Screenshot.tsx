import { Card } from '#/components/ui/card.tsx'
import { asset } from '#/lib/asset.ts'
import { cn } from '#/lib/utils.ts'

/**
 * A real product screenshot. The capture already includes the app's native
 * macOS window chrome (title bar + traffic lights), so we simply frame it in
 * a rounded, shadowed shadcn `Card` — no synthetic chrome on top.
 */
export function Screenshot({
  src,
  alt,
  width = 2400,
  height = 1500,
  fitContainer = false,
  priority = false,
  className,
}: {
  src: string
  alt: string
  width?: number
  height?: number
  fitContainer?: boolean
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
        src={asset(src)}
        alt={alt}
        width={width}
        height={height}
        loading={priority ? 'eager' : 'lazy'}
        decoding="async"
        className={cn('block w-full', fitContainer && 'h-full object-contain')}
      />
    </Card>
  )
}
