import { content } from '../../data/spec'
import { Reveal } from './Reveal'
import { SectionHeading } from './SectionHeading'
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from '#/components/ui/accordion.tsx'

export function FAQ() {
  return (
    <section id="faq" className="section scroll-mt-20">
      <div className="container-wrap">
        <SectionHeading kicker="Questions" title="Everything you might ask." />
        <Reveal className="mx-auto mt-12 max-w-3xl">
          <div className="rounded-2xl border border-border bg-card px-5 py-2 sm:px-7">
            <Accordion type="single" collapsible className="w-full">
              {content.faq.map((f, i) => (
                <AccordionItem
                  key={i}
                  value={`item-${i}`}
                  className="border-border/60"
                >
                  <AccordionTrigger className="text-left font-display text-[1rem] font-medium text-foreground hover:no-underline">
                    {f.q}
                  </AccordionTrigger>
                  <AccordionContent className="text-[0.9rem] leading-relaxed text-muted-foreground">
                    {f.a}
                  </AccordionContent>
                </AccordionItem>
              ))}
            </Accordion>
          </div>
        </Reveal>
      </div>
    </section>
  )
}
