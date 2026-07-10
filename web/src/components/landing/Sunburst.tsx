import { design } from '../../data/spec'

const COLORS = design.sunburstColors

function pol(r: number, deg: number): [number, number] {
  const a = ((deg - 90) * Math.PI) / 180
  return [r * Math.cos(a), r * Math.sin(a)]
}

function sector(rIn: number, rOut: number, a0: number, a1: number): string {
  const large = a1 - a0 > 180 ? 1 : 0
  const [x0, y0] = pol(rOut, a0)
  const [x1, y1] = pol(rOut, a1)
  const [x2, y2] = pol(rIn, a1)
  const [x3, y3] = pol(rIn, a0)
  return `M${x0} ${y0} A${rOut} ${rOut} 0 ${large} 1 ${x1} ${y1} L${x2} ${y2} A${rIn} ${rIn} 0 ${large} 0 ${x3} ${y3} Z`
}

// deterministic layout (no randomness → stable prerender)
const RING1 = [22, 17, 14, 12, 10, 9, 8, 8]
const SPLITS = [3, 2, 3, 2, 2, 2, 1, 2]
const GAP = 1.4

type Seg = { d: string; fill: string; opacity: number }

function build(): Seg[] {
  const total = RING1.reduce((a, b) => a + b, 0)
  const segs: Seg[] = []
  let angle = 0
  RING1.forEach((w, i) => {
    const span = (w / total) * 360
    const a0 = angle + GAP / 2
    const a1 = angle + span - GAP / 2
    const color = COLORS[i % COLORS.length]
    // ring 1
    segs.push({ d: sector(34, 64, a0, a1), fill: color, opacity: 0.95 })
    // ring 2 (children)
    const n = SPLITS[i]
    const childSpan = (a1 - a0) / n
    for (let c = 0; c < n; c++) {
      const c0 = a0 + c * childSpan + GAP / 4
      const c1 = a0 + (c + 1) * childSpan - GAP / 4
      segs.push({
        d: sector(66, 92, c0, c1),
        fill: color,
        opacity: 0.42 + 0.16 * ((c % 3) - 1) + 0.2,
      })
    }
    angle += span
  })
  return segs
}

const SEGMENTS = build()

export function Sunburst({
  className,
  size = 360,
  animate = false,
}: {
  className?: string
  size?: number
  animate?: boolean
}) {
  return (
    <svg
      viewBox="-100 -100 200 200"
      width={size}
      height={size}
      className={className}
      role="img"
      aria-label="Disk usage sunburst"
    >
      <g className={animate ? 'spin-slow' : undefined}>
        {SEGMENTS.map((s, i) => (
          <path
            key={i}
            d={s.d}
            fill={s.fill}
            opacity={s.opacity}
            stroke="#0a0b0d"
            strokeWidth="0.6"
          />
        ))}
      </g>
      <circle
        r="31"
        fill="#0a0b0d"
        stroke="rgba(255,255,255,0.14)"
        strokeWidth="0.8"
      />
    </svg>
  )
}
