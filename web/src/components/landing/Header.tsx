import { content } from '../../data/spec'
import { Sunburst } from './Sunburst'
import { DownloadButton } from './DownloadButton'

export function Header() {
  const nav = content.nav.filter((n) => n.label !== 'Download')
  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-border bg-background/95">
      <div className="container-wrap flex h-16 items-center gap-4">
        <a href="#top" className="flex items-center gap-2.5">
          <Sunburst size={24} />
          <span className="font-display text-[0.95rem] font-semibold tracking-tight text-foreground">
            {content.brand.name}
          </span>
        </a>
        <nav className="ml-auto hidden items-center gap-8 md:flex">
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
          className="ml-auto md:ml-0"
        />
      </div>
    </header>
  )
}
