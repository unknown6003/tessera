import { Reveal } from './Reveal'

export function SectionHeading({
  kicker,
  title,
  subtitle,
  className = '',
}: {
  kicker?: string
  title: string
  subtitle?: string
  className?: string
}) {
  return (
    <Reveal className={`mx-auto max-w-2xl text-center ${className}`}>
      {kicker ? <div className="kicker mb-3">{kicker}</div> : null}
      <h2 className="text-balance font-display text-3xl font-semibold tracking-tight text-foreground sm:text-4xl md:text-[2.75rem]">
        {title}
      </h2>
      {subtitle ? (
        <p className="mx-auto mt-4 max-w-xl text-pretty text-base leading-relaxed text-muted-foreground">
          {subtitle}
        </p>
      ) : null}
    </Reveal>
  )
}
