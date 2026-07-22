import { PieChart, Layers, AppWindow, Sparkles } from 'lucide-react'
import {
  Tabs,
  TabsList,
  TabsTrigger,
  TabsContent,
} from '#/components/ui/tabs.tsx'
import { Reveal } from './Reveal'
import { SectionHeading } from './SectionHeading'
import { Screenshot } from './Screenshot'

const SHOTS = [
  {
    value: 'overview',
    tab: 'Overview',
    icon: PieChart,
    title: 'Tessera — Macintosh HD',
    caption: 'Every file on the drive, mapped as one interactive sunburst.',
    src: '/screenshots/overview.jpg',
    height: 1500,
    alt: 'Tessera showing an interactive sunburst map of the whole disk',
  },
  {
    value: 'by-kind',
    tab: 'By Kind',
    icon: Layers,
    title: 'Tessera — By Kind',
    caption: 'Group everything as Video, Photo, App, Archive, Code, and more.',
    src: '/screenshots/by-kind.jpg',
    height: 1543,
    alt: 'Tessera grouping disk usage by file kind',
  },
  {
    value: 'uninstall',
    tab: 'Uninstall',
    icon: AppWindow,
    title: 'Tessera — App Uninstaller',
    caption: 'Remove an app and the leftovers it scatters across your disk.',
    src: '/screenshots/uninstall.jpg',
    height: 1543,
    alt: 'Tessera app uninstaller listing installed apps and their leftovers',
  },
  {
    value: 'cleanup',
    tab: 'Cleanup',
    icon: Sparkles,
    title: 'Tessera — Cleanup',
    caption:
      'Suggested junk lands in a collector you review before anything happens.',
    src: '/screenshots/cleanup.jpg',
    height: 1543,
    alt: 'Tessera cleanup suggestions staged for review',
  },
] as const

export function ProductTour() {
  return (
    <section id="demo" className="section scroll-mt-20">
      <div className="container-wrap">
        <SectionHeading
          kicker="See it in action"
          title="A real look at Tessera."
          subtitle="Actual screenshots — not mockups. Click through the four core views."
        />

        <Reveal className="mt-12">
          <Tabs defaultValue="overview" className="items-center gap-8">
            <TabsList className="!h-auto max-w-full flex-wrap gap-1 rounded-full border border-border bg-surface p-1.5">
              {SHOTS.map((s) => (
                <TabsTrigger
                  key={s.value}
                  value={s.value}
                  className="h-10 gap-2 rounded-full px-4 py-2 text-[0.85rem] data-[state=active]:!bg-brand data-[state=active]:!text-brand-ink"
                >
                  <s.icon className="size-4" strokeWidth={2} />
                  {s.tab}
                </TabsTrigger>
              ))}
            </TabsList>

            <div className="relative mx-auto w-full max-w-5xl">
              {SHOTS.map((s) => (
                <TabsContent key={s.value} value={s.value} className="mt-0">
                  <Screenshot
                    src={s.src}
                    alt={s.alt}
                    title={s.title}
                    height={s.height}
                    fitContainer
                    className="aspect-[2400/1543]"
                  />
                  <p className="mt-4 text-center text-sm text-muted-foreground">
                    {s.caption}
                  </p>
                </TabsContent>
              ))}
            </div>
          </Tabs>
        </Reveal>
      </div>
    </section>
  )
}
