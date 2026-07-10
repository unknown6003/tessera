import { content } from '../../data/spec'
import { Reveal } from './Reveal'
import { Card, CardContent } from '#/components/ui/card.tsx'
import { Lock, Cpu, WifiOff, FileLock2 } from 'lucide-react'

const POINT_ICONS = [Cpu, WifiOff, FileLock2, Lock]

export function Privacy() {
  const { privacy } = content
  return (
    <section id="privacy" className="section scroll-mt-20">
      <div className="container-wrap">
        <div className="rounded-2xl border border-border bg-card p-8 md:p-14">
          <div className="grid grid-cols-1 gap-10 lg:grid-cols-[1.1fr_1fr] lg:items-center">
            <Reveal>
              <div className="inline-flex items-center gap-2 rounded-full border border-border bg-surface px-3 py-1.5 text-[0.72rem] font-medium text-brand">
                <Lock className="size-3.5" />
                {privacy.kicker}
              </div>
              <h2 className="mt-5 text-balance font-display text-3xl font-semibold tracking-tight text-foreground sm:text-4xl">
                {privacy.headline}
              </h2>
              <p className="mt-4 text-pretty text-base leading-relaxed text-muted-foreground">
                {privacy.body}
              </p>
            </Reveal>

            <Reveal delay={100}>
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                {privacy.points.map((p, i) => {
                  const I = POINT_ICONS[i % POINT_ICONS.length]
                  return (
                    <Card
                      key={p.title}
                      className="gap-2 border-border bg-surface py-4"
                    >
                      <CardContent>
                        <I
                          className="mb-2.5 size-5 text-brand"
                          strokeWidth={1.8}
                        />
                        <div className="text-[0.9rem] font-semibold text-foreground">
                          {p.title}
                        </div>
                        <p className="mt-1 text-[0.8rem] leading-relaxed text-muted-foreground">
                          {p.description}
                        </p>
                      </CardContent>
                    </Card>
                  )
                })}
              </div>
            </Reveal>
          </div>
        </div>
      </div>
    </section>
  )
}
