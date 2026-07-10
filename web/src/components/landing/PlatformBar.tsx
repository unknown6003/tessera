import { Apple, Monitor, Terminal, Check } from 'lucide-react'
import { cn } from '#/lib/utils.ts'

type Platform = {
  name: string
  icon: typeof Apple
  status: 'available' | 'soon'
}

const PLATFORMS: Platform[] = [
  { name: 'macOS', icon: Apple, status: 'available' },
  { name: 'Windows', icon: Monitor, status: 'soon' },
  { name: 'Linux', icon: Terminal, status: 'soon' },
]

/**
 * Availability strip shown under the hero CTAs. macOS ships today; Windows and
 * Linux are marked "soon" (see DISTRIBUTION.md for the packaging plan — winget
 * and Linux package managers). Purely informational, no download links for the
 * unreleased platforms.
 */
export function PlatformBar() {
  return (
    <div className="mt-6 flex flex-wrap items-center justify-center gap-2.5">
      {PLATFORMS.map((p) => {
        const available = p.status === 'available'
        return (
          <span
            key={p.name}
            className={cn(
              'inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-[0.72rem] font-medium',
              available
                ? 'border-border bg-surface text-foreground'
                : 'border-border bg-transparent text-muted-foreground',
            )}
          >
            <p.icon className="size-3.5" strokeWidth={2} />
            {p.name}
            {available ? (
              <Check className="size-3 text-brand" strokeWidth={2.6} />
            ) : (
              <span className="text-[0.62rem] uppercase tracking-wide text-muted-foreground/70">
                soon
              </span>
            )}
          </span>
        )
      })}
    </div>
  )
}
