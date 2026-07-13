import { useEffect, useState } from 'react'
import { Menu, X } from 'lucide-react'
import { content } from '../../data/spec'
import { Sunburst } from './Sunburst'
import { DownloadButton } from './DownloadButton'
import { cn } from '#/lib/utils.ts'

export function Header() {
  const nav = content.nav.filter((n) => n.label !== 'Download')
  const [open, setOpen] = useState(false)

  // Close the mobile menu on Escape, and never leave it open past a resize
  // up into the desktop breakpoint.
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false)
    const onResize = () => window.innerWidth >= 768 && setOpen(false)
    window.addEventListener('keydown', onKey)
    window.addEventListener('resize', onResize)
    return () => {
      window.removeEventListener('keydown', onKey)
      window.removeEventListener('resize', onResize)
    }
  }, [open])

  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-border bg-background/95">
      <div className="container-wrap flex h-16 items-center gap-4">
        <a
          href="#top"
          className="flex items-center gap-2.5"
          onClick={() => setOpen(false)}
        >
          <Sunburst size={24} />
          <span className="font-display text-[0.95rem] font-semibold tracking-tight text-foreground">
            {content.brand.name}
          </span>
        </a>

        {/* desktop nav */}
        <nav
          aria-label="Primary"
          className="ml-auto hidden items-center gap-8 md:flex"
        >
          {nav.map((n) => (
            <a
              key={n.label}
              href={n.href}
              className="text-[0.85rem] text-muted-foreground transition-colors hover:text-foreground"
            >
              {n.label}
            </a>
          ))}
        </nav>

        <DownloadButton
          label="Download"
          size="sm"
          showIcon={false}
          className="ml-auto hidden md:ml-0 md:inline-flex"
        />

        {/* mobile menu toggle */}
        <button
          type="button"
          aria-label={open ? 'Close menu' : 'Open menu'}
          aria-expanded={open}
          aria-controls="mobile-nav"
          onClick={() => setOpen((v) => !v)}
          className="ml-auto inline-flex size-9 items-center justify-center rounded-md border border-border bg-surface text-foreground md:hidden"
        >
          {open ? <X className="size-5" /> : <Menu className="size-5" />}
        </button>
      </div>

      {/* mobile nav panel */}
      <div
        id="mobile-nav"
        className={cn(
          'border-t border-border bg-background md:hidden',
          open ? 'block' : 'hidden',
        )}
      >
        <nav aria-label="Primary" className="container-wrap flex flex-col py-3">
          {nav.map((n) => (
            <a
              key={n.label}
              href={n.href}
              onClick={() => setOpen(false)}
              className="rounded-md px-2 py-3 text-[0.95rem] text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
            >
              {n.label}
            </a>
          ))}
          <div onClick={() => setOpen(false)}>
            <DownloadButton
              label="Download for macOS"
              className="mt-2 w-full"
            />
          </div>
        </nav>
      </div>
    </header>
  )
}
