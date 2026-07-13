// Type surface for brand.js (the plain-ESM geometry source of truth).
export interface Wedge {
  d: string
  fill: string
}
export const PALETTE: {
  bg: string
  edge: string
  wedges: string[]
}
export const PROPORTIONS: number[]
export function buildWedges(): Wedge[]
export const brandMark: { wedges: Wedge[]; rIn: number; rOut: number }
export function markSVG(size?: number): string
export function appIconSVG(size?: number): string
