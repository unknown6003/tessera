// ---------------------------------------------------------------------------
// Tessera brand geometry — the single source of truth for the mark.
//
// Plain ESM (no types) so it can be imported unchanged by:
//   • the React app  (src/components/landing/Sunburst.tsx  → typed via brand.d.ts)
//   • the icon build (icon/generate.mjs → favicon, web logos, .icns, .ico, PNGs)
//
// One definition → pixel-identical mark on the site and in every OS app icon.
// ---------------------------------------------------------------------------

// Cyan-forward brand family. These four are also the leading colors of the
// in-app sunburst chart, so the icon and the product read as one thing.
export const PALETTE = {
  bg: '#0a0b0d', // app-icon tile — near-black neutral (matches --bg)
  edge: 'rgba(255,255,255,0.10)', // hairline tile edge (no glow, no gradient)
  wedges: ['#1be6ff', '#37e0c8', '#5b8cff', '#9e6bff'], // cyan · teal · blue · violet
}

// Four UNEQUAL wedges (fractions of the ring). Unequal so it reads as real
// usage data — a map of what's eating the disk — not a generic spinner or a
// perfectly quartered pie. Descending: the biggest hog leads, clockwise.
export const PROPORTIONS = [0.34, 0.26, 0.22, 0.18]

const GAP = 6 // degrees of empty background between wedges (the "tile" gaps)
const R_OUT = 82
const R_IN = 46 // thick ring, open center → clean donut, legible at 16px

function pol(r, deg) {
  const a = ((deg - 90) * Math.PI) / 180
  return [r * Math.cos(a), r * Math.sin(a)]
}

function sector(rIn, rOut, a0, a1) {
  const large = a1 - a0 > 180 ? 1 : 0
  const [x0, y0] = pol(rOut, a0)
  const [x1, y1] = pol(rOut, a1)
  const [x2, y2] = pol(rIn, a1)
  const [x3, y3] = pol(rIn, a0)
  const f = (n) => n.toFixed(2)
  return (
    `M${f(x0)} ${f(y0)} A${rOut} ${rOut} 0 ${large} 1 ${f(x1)} ${f(y1)} ` +
    `L${f(x2)} ${f(y2)} A${rIn} ${rIn} 0 ${large} 0 ${f(x3)} ${f(y3)} Z`
  )
}

export function buildWedges() {
  const wedges = []
  let angle = 0
  for (let i = 0; i < PROPORTIONS.length; i++) {
    const span = PROPORTIONS[i] * 360
    const a0 = angle + GAP / 2
    const a1 = angle + span - GAP / 2
    wedges.push({ d: sector(R_IN, R_OUT, a0, a1), fill: PALETTE.wedges[i] })
    angle += span
  }
  return wedges
}

export const brandMark = { wedges: buildWedges(), rIn: R_IN, rOut: R_OUT }

/** Transparent SVG of just the mark (favicon / inline logo source). */
export function markSVG(size = 512) {
  const paths = brandMark.wedges
    .map((w) => `<path d="${w.d}" fill="${w.fill}"/>`)
    .join('')
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="-100 -100 200 200" width="${size}" height="${size}" role="img" aria-label="Tessera">${paths}</svg>`
}

/**
 * App-icon SVG — the mark centered on a solid near-black rounded tile.
 * Uses the macOS icon-grid proportions (tile inset + corner radius), which
 * also render cleanly as a Windows .ico and a Linux PNG, so all three OSes
 * ship the identical icon.
 */
export function appIconSVG(size = 1024) {
  const S = 1024
  const inset = 100 // tile margin
  const tile = S - inset * 2 // 824
  const radius = 185 // squircle-ish corner
  // scale the -100..100 mark so its 164-unit diameter fills ~64% of the tile
  const scale = (tile * 0.64) / 164
  const paths = brandMark.wedges
    .map((w) => `<path d="${w.d}" fill="${w.fill}"/>`)
    .join('')
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${S} ${S}" width="${size}" height="${size}">
  <rect x="${inset}" y="${inset}" width="${tile}" height="${tile}" rx="${radius}" fill="${PALETTE.bg}"/>
  <rect x="${inset + 0.5}" y="${inset + 0.5}" width="${tile - 1}" height="${tile - 1}" rx="${radius - 0.5}" fill="none" stroke="${PALETTE.edge}" stroke-width="1"/>
  <g transform="translate(${S / 2} ${S / 2}) scale(${scale.toFixed(4)})">${paths}</g>
</svg>`
}
