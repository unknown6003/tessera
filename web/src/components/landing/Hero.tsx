import { content } from '../../data/spec'
import { Screenshot } from './Screenshot'
import { DownloadButton, SecondaryLink } from './DownloadButton'
import { PlatformBar } from './PlatformBar'
import { Reveal } from './Reveal'
import { Check } from 'lucide-react'

export function Hero() {
  const { hero } = content
  return (
    <section id="top" className="pt-32 pb-20 sm:pt-36">
      <div className="container-wrap text-center">
        <Reveal>
          <span className="inline-flex items-center gap-2 rounded-full border border-border bg-surface px-3.5 py-1.5 text-[0.72rem] font-medium text-muted-foreground">
            <span className="size-1.5 rounded-full bg-brand" />
            {hero.kicker}
          </span>
        </Reveal>

        <Reveal delay={60}>
          <h1 className="mx-auto mt-6 max-w-4xl text-balance font-display text-5xl leading-[1.05] font-semibold tracking-tight text-foreground sm:text-6xl md:text-7xl">
            See every byte on your Mac.{' '}
            <span className="text-brand">Reclaim the space.</span>
          </h1>
        </Reveal>

        <Reveal delay={120}>
          <p className="mx-auto mt-6 max-w-2xl text-pretty text-lg leading-relaxed text-muted-foreground">
            {hero.subhead}
          </p>
        </Reveal>

        <Reveal delay={180}>
          <div className="mt-9 flex flex-wrap items-center justify-center gap-3">
            <DownloadButton label={hero.primaryCta.label} />
            <SecondaryLink
              label={hero.secondaryCta.label}
              href={hero.secondaryCta.href}
            />
          </div>
        </Reveal>

        <Reveal delay={210}>
          <PlatformBar />
        </Reveal>

        <Reveal delay={240}>
          <ul className="mx-auto mt-7 flex flex-wrap items-center justify-center gap-x-6 gap-y-2">
            {hero.highlights.map((h) => (
              <li
                key={h}
                className="flex items-center gap-1.5 text-[0.82rem] text-muted-foreground"
              >
                <Check className="size-3.5 text-brand" strokeWidth={2.4} />
                {h}
              </li>
            ))}
          </ul>
        </Reveal>
      </div>

      {/* real product screenshot — flat, bordered, no glow */}
      <div className="container-wrap mt-16">
        <Reveal delay={120}>
          <div className="mx-auto max-w-5xl">
            <Screenshot
              src="/screenshots/overview.jpg"
              alt="Tessera showing an interactive sunburst map of the whole disk"
              title="Tessera — Macintosh HD"
              priority
            />
          </div>
        </Reveal>
        <p className="mt-5 text-center text-xs text-muted-foreground">
          {hero.footnote}
        </p>
      </div>
    </section>
  )
}
