import type { MouseEvent } from 'react'
import { Download } from 'lucide-react'
import { Button } from '#/components/ui/button.tsx'
import { cn } from '#/lib/utils.ts'
import { site } from '#/lib/site.ts'

/** Trigger the .dmg download. */
function startDownload() {
  if (typeof window === 'undefined') return
  const a = document.createElement('a')
  a.href = site.downloadUrl
  a.download = ''
  a.rel = 'noopener'
  document.body.appendChild(a)
  a.click()
  a.remove()
}

/**
 * Primary CTA — downloads the free build. Rendered as a real anchor to the
 * download URL (progressive enhancement: works without JS); with JS it starts
 * the download in place instead of navigating away.
 */
export function DownloadButton({
  label = 'Download for macOS',
  className,
  size = 'lg',
  variant = 'default',
  showIcon = true,
  onActivate,
}: {
  label?: string
  className?: string
  size?: 'default' | 'lg' | 'sm'
  variant?: 'default' | 'outline' | 'secondary'
  showIcon?: boolean
  onActivate?: () => void
}) {
  const onClick = (e: MouseEvent<HTMLAnchorElement>) => {
    e.preventDefault()
    onActivate?.()
    startDownload()
  }
  return (
    <Button
      asChild
      size={size}
      variant={variant}
      className={cn(
        'rounded-full font-semibold',
        variant === 'default' &&
          'bg-primary text-primary-foreground transition-colors hover:bg-primary/90',
        className,
      )}
    >
      <a href={site.downloadUrl} onClick={onClick}>
        {showIcon ? <Download className="size-4" strokeWidth={2.4} /> : null}
        {label}
      </a>
    </Button>
  )
}

/** Secondary in-page link styled as an outline button (e.g. "See it in action"). */
export function SecondaryLink({
  label,
  href,
  className,
}: {
  label: string
  href: string
  className?: string
}) {
  return (
    <Button
      asChild
      size="lg"
      variant="outline"
      className={cn(
        'rounded-full border-border bg-transparent font-medium text-foreground hover:bg-accent hover:text-accent-foreground',
        className,
      )}
    >
      <a href={href}>{label}</a>
    </Button>
  )
}
