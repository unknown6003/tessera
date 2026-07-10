import { content } from '../../data/spec'
import { Reveal } from './Reveal'
import { DownloadButton, SecondaryLink } from './DownloadButton'

export function FinalCta() {
  const { finalCta, hero } = content
  return (
    <section className="section">
      <div className="container-wrap">
        <Reveal>
          <div className="rounded-2xl border border-border bg-card px-8 py-16 text-center md:py-20">
            <h2 className="mx-auto max-w-2xl text-balance font-display text-4xl font-semibold tracking-tight text-foreground sm:text-5xl">
              {finalCta.headline}
            </h2>
            <p className="mx-auto mt-5 max-w-xl text-pretty text-base leading-relaxed text-muted-foreground">
              {finalCta.subhead}
            </p>
            <div className="mt-9 flex flex-wrap items-center justify-center gap-3">
              <DownloadButton label={finalCta.cta.label} />
              <SecondaryLink
                label={hero.secondaryCta.label}
                href={hero.secondaryCta.href}
              />
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  )
}
