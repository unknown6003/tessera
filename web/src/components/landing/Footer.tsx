import { content } from '../../data/spec'
import { Sunburst } from './Sunburst'

export function Footer() {
  const { footer, brand } = content
  return (
    <footer className="border-t border-border/60 py-14">
      <div className="container-wrap">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-[1.6fr_repeat(3,1fr)]">
          <div className="col-span-2 md:col-span-1">
            <div className="flex items-center gap-2.5">
              <Sunburst size={28} />
              <span className="font-display text-base font-semibold text-foreground">
                {brand.name}
              </span>
            </div>
            <p className="mt-3 max-w-xs text-[0.82rem] leading-relaxed text-muted-foreground">
              {footer.tagline}
            </p>
          </div>

          {footer.columns.map((col) => (
            <div key={col.title}>
              <div className="kicker mb-3 text-[0.62rem]">{col.title}</div>
              <ul className="flex flex-col gap-2">
                {col.links.map((l) => (
                  <li key={l.label}>
                    <a
                      href={l.href}
                      className="text-[0.82rem] text-muted-foreground transition-colors hover:text-foreground"
                    >
                      {l.label}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div className="mt-12 border-t border-border/50 pt-6 text-[0.72rem] text-muted-foreground/80">
          {footer.legal}
        </div>
      </div>
    </footer>
  )
}
