import { content } from '../../data/spec'
import { Reveal } from './Reveal'
import { SectionHeading } from './SectionHeading'
import { Card, CardContent } from '#/components/ui/card.tsx'

export function HowItWorks() {
  return (
    <section className="section">
      <div className="container-wrap">
        <SectionHeading
          kicker="How it works"
          title="From full disk to reclaimed in four steps."
        />
        <div className="mt-14 grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
          {content.howItWorks.map((step, i) => (
            <Reveal key={step.title} delay={i * 70}>
              <Card className="h-full border-border bg-card">
                <CardContent>
                  <div className="font-display text-3xl font-bold text-brand tabular-nums">
                    {String(i + 1).padStart(2, '0')}
                  </div>
                  <h3 className="mt-3 font-display text-base font-semibold text-foreground">
                    {step.title}
                  </h3>
                  <p className="mt-2 text-[0.85rem] leading-relaxed text-muted-foreground">
                    {step.description}
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
