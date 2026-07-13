import { brandMark } from '../../lib/brand'

/**
 * Tessera brand mark — a simplified sunburst.
 *
 * The old mark was a two-ring, ~19-segment burst with per-wedge opacity noise:
 * gorgeous at 360px, illegible mush at favicon size. This is one bold donut of
 * four unequal wedges in the brand's cyan-forward palette — instantly readable
 * as "a map of your used space" and still crisp at 16px. The exact same
 * geometry drives the app icon (see `lib/brand.ts` + `/icon`), so the mark is
 * pixel-identical everywhere it appears.
 */
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
      aria-label="Tessera disk-usage sunburst"
    >
      <g className={animate ? 'spin-slow' : undefined}>
        {brandMark.wedges.map((w, i) => (
          <path key={i} d={w.d} fill={w.fill} />
        ))}
      </g>
    </svg>
  )
}
