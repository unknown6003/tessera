import { content } from '../../data/spec'
import { Reveal } from './Reveal'
import { ShieldCheck } from 'lucide-react'

export function Trust() {
  const { trust } = content
  return (
    <section className="border-y border-border py-10">
      <div className="container-wrap">
        <Reveal className="flex flex-col items-center gap-6 text-center">
          <p className="font-display text-lg font-medium text-foreground/90">
            {trust.headline}
          </p>
          <ul className="flex flex-wrap items-center justify-center gap-x-3 gap-y-3">
            {trust.items.map((item) => (
              <li
                key={item}
                className="flex items-center gap-2 rounded-full border border-border bg-surface px-3.5 py-1.5 text-[0.8rem] text-muted-foreground"
              >
                <ShieldCheck className="size-3.5 text-brand" strokeWidth={2} />
                {item}
              </li>
            ))}
          </ul>
        </Reveal>
      </div>
    </section>
  )
}
