import { content } from '../../data/spec'
import { Reveal } from './Reveal'
import { SectionHeading } from './SectionHeading'
import { DownloadButton } from './DownloadButton'
import { site } from '#/lib/site.ts'
import { Button } from '#/components/ui/button.tsx'
import { Check, Github, Heart, Star } from 'lucide-react'

export function Download() {
  const { download } = content
  return (
    <section id="download" className="section scroll-mt-20">
      <div className="container-wrap">
        <SectionHeading
          kicker={download.kicker}
          title={download.headline}
          subtitle={download.subhead}
        />

        <Reveal>
          <div className="mx-auto mt-14 max-w-3xl overflow-hidden rounded-2xl border border-border bg-card p-8 md:p-10">
            <div className="grid grid-cols-1 gap-8 md:grid-cols-[1fr_1.05fr] md:items-center">
              {/* the offer */}
              <div>
                <div className="inline-flex items-center gap-2 rounded-full border border-border bg-surface px-3 py-1 text-[0.72rem] font-medium text-brand">
                  <span className="size-1.5 rounded-full bg-brand" />
                  Free &amp; open source
                </div>
                <p className="mt-4 font-display text-4xl font-bold tracking-tight text-foreground">
                  $0
                </p>
                <p className="mt-1 text-sm text-muted-foreground">
                  No price, no account, no upsells — forever.
                </p>

                <div className="mt-7 flex flex-col gap-2.5">
                  <DownloadButton
                    label={download.ctaLabel}
                    className="w-full"
                  />
                  <div className="flex gap-2.5">
                    <Button
                      asChild
                      variant="outline"
                      className="flex-1 rounded-full border-border bg-transparent font-medium text-foreground hover:bg-accent hover:text-accent-foreground"
                    >
                      <a href={site.githubUrl} target="_blank" rel="noreferrer">
                        <Star className="size-4" strokeWidth={2.2} />
                        {download.starLabel}
                      </a>
                    </Button>
                    <Button
                      asChild
                      variant="outline"
                      className="flex-1 rounded-full border-border bg-transparent font-medium text-foreground hover:bg-accent hover:text-accent-foreground"
                    >
                      <a
                        href={site.sponsorUrl}
                        target="_blank"
                        rel="noreferrer"
                      >
                        <Heart
                          className="size-4 text-brand"
                          strokeWidth={2.2}
                        />
                        {download.sponsorLabel}
                      </a>
                    </Button>
                  </div>
                </div>
              </div>

              {/* what you get */}
              <div className="md:border-l md:border-border/60 md:pl-8">
                <div className="kicker mb-3 flex items-center gap-1.5">
                  <Github className="size-3.5" />
                  What you get
                </div>
                <ul className="flex flex-col gap-2.5">
                  {download.includes.map((item) => (
                    <li
                      key={item}
                      className="flex items-start gap-2.5 text-[0.9rem] text-foreground/90"
                    >
                      <Check
                        className="mt-0.5 size-4 shrink-0 text-brand"
                        strokeWidth={2.4}
                      />
                      <span>{item}</span>
                    </li>
                  ))}
                </ul>
              </div>
            </div>

            <p className="mt-8 border-t border-border pt-5 text-[0.72rem] leading-relaxed text-muted-foreground/80">
              {download.note}
            </p>
          </div>
        </Reveal>
      </div>
    </section>
  )
}
