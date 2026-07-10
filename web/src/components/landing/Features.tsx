import { content } from '../../data/spec'
import { Icon } from './icon'
import { Reveal } from './Reveal'
import { SectionHeading } from './SectionHeading'
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
} from '#/components/ui/card.tsx'

export function Features() {
  return (
    <section id="features" className="section scroll-mt-20">
      <div className="container-wrap">
        <SectionHeading
          kicker="Everything in one app"
          title="One scan. Then every way to clean it up."
          subtitle="A complete toolkit for understanding and reclaiming your disk — fast, visual, and safe by default."
        />

        <div className="mt-14 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {content.features.map((f, i) => (
            <Reveal key={f.title} delay={(i % 3) * 70}>
              <Card className="h-full gap-3 border-border bg-card transition-colors hover:border-white/15">
                <CardHeader>
                  <div className="inline-flex size-11 items-center justify-center rounded-lg border border-border bg-surface text-brand">
                    <Icon name={f.icon} className="size-5" />
                  </div>
                  <CardTitle className="mt-4 font-display text-lg font-semibold">
                    {f.title}
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-[0.9rem] leading-relaxed text-muted-foreground">
                    {f.description}
                  </p>
                </CardContent>
              </Card>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  )
}
