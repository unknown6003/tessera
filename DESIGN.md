# Tessera Design System

The one design language for everything Tessera — the landing site today, and any
future cross-platform app (macOS / Windows / Linux) tomorrow. It replaces the old
Apple "Liquid Glass" look (frosted materials, desktop-refracting windows, tinted
depth) with a **flat, single-accent dark system**.

Why flat: Liquid Glass is an Apple-platform material. It cannot be reproduced
identically on Windows or Linux, so an app built on it looks different on every
OS. This system is **pure tokens** — solid fills, hairline borders, one accent —
implemented in web tech (React + Tailwind v4 + shadcn/Radix). The same tokens and
the same components render **pixel-identical on every OS**. That is the whole point.

> Source of truth for live values: `web/src/styles.css` (CSS variables + `@theme`).
> Mirrored for docs/tooling in `web/src/data/spec.ts` (`design`). Brand mark
> geometry: `web/src/lib/brand.js`. Keep these in sync.

---

## 1. Principles

1. **Flat only.** No gradients, no glows, no frosted glass, no platform
   materials. Surfaces are solid fills separated by 1px hairline borders.
2. **60 / 30 / 10 by area.** ~60% near-black void, ~30% neutral structure
   (panels, borders, text), ~10% the single cyan accent. The accent is a
   wayfinding cue — it marks the one thing that matters in a view, never
   decoration.
3. **One accent.** Electric cyan `#1be6ff`. If two things are cyan, ask which one
   the user should act on; usually only one should be.
4. **Legible, calm, premium.** High contrast, generous spacing, quiet motion. An
   instrument, not a marketing gradient.
5. **Identical across OS.** Anything that can't render the same on Windows/Linux
   (vibrancy, `NSVisualEffectView`, backdrop refraction, SF-only materials) is
   banned. Tokens and web-standard CSS only.
6. **Intuitive by default.** Every control is self-explanatory; destructive
   actions are staged and reversible (see §8).

---

## 2. Color tokens

Dark is the only theme. Values are the live ones in `web/src/styles.css`.

| Role | Token | Value | Use |
|------|-------|-------|-----|
| Void (60%) | `--bg` | `#0a0b0d` | page + largest surfaces |
| Surface | `--surface` | `#101216` | pills, insets, secondary fills |
| Card | `--card` | `#131418` | panels, cards |
| Elevated | `--elevated` | `#17191e` | raised panels, popovers |
| Text | `--foreground` | `#f3f4f6` | primary text |
| Muted text | `--muted-foreground` | `#969ba4` | secondary text |
| Hairline | `--border` | `rgba(255,255,255,.08)` | default 1px borders |
| Hairline strong | `--border-strong` | `rgba(255,255,255,.14)` | emphasis borders |
| **Accent (10%)** | `--brand` | `#1be6ff` | the single accent |
| On-accent | `--brand-ink` | `#04171c` | text/icons on accent fills |
| Danger | `--destructive` | `#ff5c7a` | delete / irreversible only |

**Contrast:** `--foreground` on `--bg` ≈ 17:1, `--muted-foreground` on `--bg` ≈
6:1 — both pass WCAG AA. Never put body text below `--muted-foreground` on the
void. On a `--brand` fill, always use `--brand-ink` (dark), never white.

### Sunburst / data palette

The app's disk-usage chart and any categorical viz use, in order:
`#1BE6FF · #37E0C8 · #5B8CFF · #9E6BFF · #5BE36B · #FF5CC8 · #FFB13C`
(`design.sunburstColors`). The **first four** are also the app-icon wedges, so the
product and its icon read as one thing.

---

## 3. Typography

- **Display** (`--font-display`): Clash Display → SF Pro Display → system. Used
  for `h1–h3`, letter-spacing `-0.02em`. Headlines, section titles, numerals.
- **Text** (`--font-sans`): SF Pro Text → Inter → system. Body, UI, labels.
- **Kicker**: uppercase, `0.18em` tracking, `0.7rem`, `--brand` — the small accent
  label above section titles. One per section; it's the wayfinding accent.
- Scale is fluid (`clamp`) on the site; in an app, use a fixed 4px-step ramp.

---

## 4. Shape, spacing, elevation, motion

- **Radius:** `--radius: 14px` base; `sm 8 / md 11 / lg 14 / xl 20`. Pills use
  `rounded-full`. Consistent rounding = one product.
- **Spacing:** 4px base grid. Section vertical rhythm `clamp(4rem, 9vw, 7.5rem)`.
  Content max width 1140px (`.container-wrap`).
- **Elevation** comes from **border + a soft shadow**, never a glow. `--shadow`
  for cards, `--shadow-lg` for the hero screenshot. No colored/brand shadows.
- **Motion:** subtle and slow. Scroll fade-up (`.reveal`) and the optional mark
  rotation (`.spin-slow`, 48s). **All motion is disabled under
  `prefers-reduced-motion`** — content snaps to its final state.

---

## 5. Brand mark & app icon

A **simplified sunburst**: one bold donut of four unequal wedges (34/26/22/18%) in
the cyan-forward palette, on a near-black rounded tile. It reads instantly as "a
map of your used space" and stays crisp at 16px — unlike the old two-ring,
~19-segment burst that turned to mush at favicon size.

- **Geometry (single source):** `web/src/lib/brand.js` — `PALETTE`,
  `PROPORTIONS`, `brandMark`, `markSVG()`, `appIconSVG()`. Typed via `brand.d.ts`.
- **In the site:** `Sunburst.tsx` renders `brandMark` (header, footer).
- **All raster icons** (favicon, PWA logos, `.ico`, macOS `.iconset`, app PNGs)
  are generated from that one source: `cd web && npm run icons`
  (`scripts/gen-icons.mjs`). Outputs land in `icon/` and `web/public/`. See
  `icon/README.md`. Because every size comes from one vector, the icon is
  identical on macOS, Windows, and Linux.

---

## 6. Components (shadcn/ui + Radix)

The system is built on **shadcn/ui primitives over Radix** (`web/src/components/ui/`)
styled with the tokens above — the agreed foundation for both site and app.

- `button` — variants `default` (brand fill, `--brand-ink` text), `outline`
  (transparent + hairline), `secondary`, `ghost`, `link`, `destructive`. Sizes
  `sm/default/lg/icon`. Pills (`rounded-full`) for CTAs. All have `focus-visible`
  rings — never remove them.
- `card` — panel: solid `--card`, hairline border, soft shadow. The one container.
- `tabs`, `accordion`, `table`, `badge`, `separator` — Radix behavior, token
  styling. Active tab = brand fill.
- App-only additions to build the same way: `dialog`/`alert-dialog` (confirm
  destructive actions), `tooltip`, `progress`, `checkbox`, `dropdown-menu`,
  `toast`. Use Radix primitives + these tokens; do not hand-roll.

Rule: **new UI composes existing primitives.** If a primitive is missing, add it
from shadcn and theme it with tokens — don't fork styles inline.

---

## 7. Accessibility (non-negotiable)

- **Visible focus** on every interactive element. Buttons/badges/Radix ship rings;
  bare links get a global `:focus-visible` brand outline (`styles.css`).
- **Skip-to-content** link is the first focusable element (`index.tsx` →
  `#main`).
- **Landmarks:** one `<main id="main">`, labeled `<nav aria-label="Primary">`,
  `<header>`, `<footer>`.
- **Mobile nav** is a real disclosure: `aria-expanded` + `aria-controls`,
  Esc-to-close, closes on selection (`Header.tsx`). Never hide navigation with no
  replacement.
- **Contrast** meets WCAG AA (see §2). **Motion** respects reduced-motion (§4).
- Every image has `alt`; every icon-only control has an `aria-label`.

---

## 8. Product-UX rules (for the app)

Carry the site's clarity into the app:

- **Safe by default.** Suggestions are staged in a collector the user reviews;
  nothing auto-deletes. Default action is **Move to Trash** (reversible);
  **Delete Permanently** is a separate, explicitly-confirmed action in a
  `destructive` alert-dialog.
- **Always show state.** Every long task (scan, dedupe) shows determinate
  progress; every list has an empty state that says what to do next; every result
  says what it means in plain language (real byte counts, not jargon).
- **Plain words over jargon.** Prefer "Space macOS won't explain" to "purgeable";
  keep the technical term as a secondary hint, not the label.
- **One primary action per view**, marked with the accent. Everything else is
  neutral.
- **No further explanation needed.** A first-time, non-technical user should
  understand each screen from its labels, empty states, and one primary button
  alone.

See **[the app usability audit](#9-app-usability-audit)** below for the concrete,
screen-by-screen backlog that applies these rules to the current SwiftUI app.

---

## 9. App migration status

The SwiftUI app has been **migrated onto this flat system**. All Liquid-Glass
APIs are gone (§9.3 is complete): no `.glassEffect`, no `GlassEffectContainer`,
no `NSVisualEffectView` vibrancy, no transparent window, no `.plusLighter`
specular lips, no `.buttonStyle(.glass/.glassProminent)`. The app now paints
solid `Theme` tokens with hairline borders, on an **opaque** window.

Key pieces: `Theme.swift` holds the tokens (identical values to `styles.css`),
a contrast-safe `Theme.ink(on:)`, and two flat button styles (`.flat`,
`.flatProminent`) that track `.controlSize`. `GlassSurfaces.swift` is reduced to
an opaque-window configurator + one solid panel modifier.

> ⚠️ The app is native SwiftUI and was **not compiled** as part of this change
> (no macOS/Xcode available in the authoring environment). Build in Xcode to
> confirm. Braces/symbols were statically verified.

### 9.1 Usability fixes — done ✅ / backlog ⬜

**Done in the app:**
- ✅ **Chart interactions are now taught on-screen** — a persistent hint strip:
  "Click a slice to open it · Click the middle to go back · Drag a slice to the
  list below to remove it." The hub also picks up an accent ring when it's
  actually clickable.
- ✅ **"Collector" → "Cleanup List"**, with an always-visible line: *"Nothing here
  is deleted until you click Move to Trash."*
- ✅ **Destructive actions made safe.** "Clear" → **"Empty List"** (it empties the
  list, it does not delete files); **Delete Permanently** demoted out of the
  button row into an overflow menu; the confirm dialog now offers **Move to
  Trash first, as the default**.
- ✅ **Hidden Space snapshot deletion is confirmed** (both "Delete all" and
  per-snapshot) — it previously deleted with no confirmation at all.
- ✅ **Keyboard focus restored** (`.focusEffectDisabled()` removed).
- ✅ **Error card offers "Try Again"**, not just "Dismiss".
- ✅ **De-jargoned:** tool bar ("Apps"→"Uninstall Apps", "By Kind"→"Browse by
  Type", "Large & Old"→"Big & Old Files", "Search"→"Search Files"); Hidden Space
  ("Purgeable caches"→"Space macOS frees on its own", "Local snapshots"→"Backup
  snapshots"); clearer empty state.

**Still backlog (needs refactors beyond a restyle):**
- ⬜ **Scan CTA in the empty state** — needs the source selection lifted from
  `Sidebar`'s local `@State` into `ScanViewModel`.
- ⬜ **Freeze the inspector on selection instead of hover** (`InspectorView.swift:6`).
- ⬜ **Empty/loading states + off-main-thread computes** for Clean Up, Big & Old,
  Browse by Type (`LargeOldFilesView.swift:63`, `ByKindView.swift:113`).
- ⬜ **Per-wedge VoiceOver** — the chart is still one opaque accessibility element.
- ⬜ **Menu commands** for Zoom Out / Clear Selection (still invisible shortcuts).
- ⬜ **Tool bar overflow** (tools still scroll off-screen) and **source-card status
  soup** (selected / Viewing / Cached / green ring).
- ⬜ **App Uninstaller wording** — "Uninstall" still only *stages*.

### 9.2 Original audit — top 10 (ranked by impact)

1. **Teach the core interactions on-screen.** Nothing tells the user they can
   click a wedge to zoom, drag a wedge to the dock, or click the center to zoom
   out. Add a persistent plain-language hint around the chart. (`SunburstChart.swift`, `ContentView.swift`)
2. **Rename "Collector" → "Cleanup List" and explain it.** Every tool funnels
   into it, but the stage→review→delete model is never stated. (`CollectorDock.swift`)
3. **Make Move to Trash the obvious primary; demote Delete Permanently.** The
   confirm dialog emphasizes permanent delete and sits it next to the safe
   option. Trash should be the default; permanent delete behind an advanced
   control. (`ContentView.swift:92`, `CollectorDock.swift:130`)
4. **Co-locate the primary Scan CTA with the empty-state guidance.** The empty
   state says "press Scan" while Scan lives in the sidebar footer. Put a
   "Scan [source]" button in the center. (`ContentView.swift:219`, `Sidebar.swift:251`)
5. **Restore visible keyboard focus + real menu commands.** `.focusEffectDisabled()`
   removes all focus indication; Zoom Out / Clear Selection exist only as
   invisible shortcuts. Add a flat focus ring and menu items. (`ContentView.swift:72`, `:460`)
6. **Guard Hidden Space snapshot deletion + surface the feature.** "Delete all"
   snapshots deletes with **no confirmation** (unlike everything else) and is
   buried behind a jargon wedge. Add a confirm dialog; promote to the tool bar. (`HiddenSpaceView.swift:65`)
7. **Freeze the inspector on selection, not hover.** The right rail flickers
   through every hovered wedge, so Collect/Reveal target a moving item. (`InspectorView.swift:6`)
8. **Give every tool panel empty / loading / result states, off the main
   thread.** Clean Up hides itself when empty; Large & Old and By Kind compute
   synchronously in `body` with no spinner. (`CleanupSuggestionsView.swift:17`, `LargeOldFilesView.swift:63`, `ByKindView.swift:113`)
9. **De-jargon every label.** "Collector", "leftovers/orphans", "purgeable
   caches", "APFS snapshots", "reclaimable", "By Kind", "Large & Old", "keeper",
   synthetic wedges ("Other/Hidden Space/Cross-volume") → everyday words + short
   info popovers. (all tool views)
10. **Fix hidden tool-bar affordances + the source-card status soup.** Six tools
    silently scroll off-screen (wrap/overflow to "More" instead); source cards
    stack three overlapping states (selected / Viewing / Cached / green ring) —
    collapse to one clear per-row status. (`CleanupActionBar.swift:22`, `Sidebar.swift` `VolumeCard`)

### 9.3 Screen-by-screen notes (original audit)

- **Shell (`ContentView.swift`)** — fixed 3-column, hard `minWidth:920`, no
  responsive rail collapse; thin empty/error states (error offers only
  "Dismiss", shows raw `localizedDescription`).
- **Sidebar / sources (`Sidebar.swift`, `StorageSources.swift`)** — Scan button
  divorced from the center guidance; three overlapping status systems per card;
  "Back" actually means "return to current view"; Connect-to-Server sheet is
  expert-only (SMB/NFS jargon, no validation); icon-only refresh.
- **Sunburst (`SunburstChart.swift`)** — interactions undiscoverable; hub is
  sometimes a button with no affordance; synthetic wedges are jargon; **chart is
  one opaque a11y element — unusable via VoiceOver** (no per-wedge label/actions).
- **Inspector (`InspectorView.swift`)** — content tracks hover (flickers); terse
  empty state; "Collect" jargon; buttons silently disabled for synthetic nodes.
- **Tool bar (`CleanupActionBar.swift`)** — six equal glass buttons scroll off
  with no affordance; inconsistent labels ("Apps", "By Kind", "Large & Old").
- **Cleanup Suggestions (`CleanupSuggestionsView.swift`)** — whole panel hidden
  when empty (no "all clean"); no loading; two-step staging never explained.
- **Collector dock (`CollectorDock.swift`)** — "COLLECTOR" jargon; three
  destructive-ish buttons in a row; "Clear" (list) vs "Delete" (disk) is a
  dangerous label pair; drag model taught only in the empty hint; no subset
  selection / undo affordance.
- **Duplicate Finder** — opaque keeper heuristic (can't re-pick); progress lacks
  context; results capped at 20 with no way to see the rest.
- **Large & Old / By Kind** — synchronous recompute in `body`, no spinner;
  zero-result state can't distinguish "too-strict filter" from "clean".
- **File Search** — NL parsing sets expectations with no grammar hints after the
  first search; unparseable input gives no correction guidance.
- **App Uninstaller** — "Uninstall" only *stages* (mixed message); "leftovers /
  orphans / bundle-id / containers" jargon; depends on the unexplained collector.
- **Hidden Space (`HiddenSpaceView.swift`)** — buried behind a jargon wedge;
  destructive actions unguarded; heavy jargon; errors shown as a caption not an
  alert.
- **Scan progress** — shown in two out-of-sync places; `PulsingRings` is a
  decorative animated Canvas (off-brand); indeterminate state reads as "stuck".
- **Full Disk Access onboarding** — the clearest screen in the app (numbered
  steps, plain language). **Use it as the model** for the rest.

### 9.4 Liquid-Glass removal checklist — ✅ COMPLETE

All of the following have been removed and replaced with solid surface fills,
hairline borders, a solid selected-state, flat categorical chart fills, the
`.flat`/`.flatProminent` button styles, and neutral (never colored) shadows:

- **Core infra — `GlassSurfaces.swift`:** `GlassTuning` materials/tints (`:11`);
  `TransparentWindowConfigurator` (`:83`) → opaque window; `DesktopGlass`
  `NSVisualEffectView` wrapper (`:122`) → remove; `desktopGlassPanel(...)` (`:163`)
  → solid fill + border.
- **Depth/highlight — `Theme.swift`:** `liquidGlassDepth(...)` (`:187`),
  `glassHighlightStroke` (`:98`), `windowTint`/`baseTint` (`:18`), `selectionTint`
  (`:108`), wedge glass shaders `wedgeRadialGradient`/`wedgeRim` (`:57`,`:67`),
  translucent synthetic colors (`:76`).
- **Root — `ContentView.swift`:** full-window `DesktopGlass` + tint (`:55`),
  `TransparentWindowConfigurator` (`:65`), `centeredCard`→`desktopGlassPanel`
  (`:212`), breadcrumb `GlassEffectContainer`/`.glassEffect` (`:285`,`:324`),
  `PulsingRings` glass core (`:447`), FDA card glass (`:560`), and every
  `.buttonStyle(.glass/.glassProminent)`.
- **Per-view:** `Sidebar.swift` rail glass + capacity specular (`:61`,`:551`);
  `InspectorView.swift` rail + icon-badge gradient/highlight (`:24`,`:56`);
  `SunburstChart.swift` HUD plate, hub halo/lip, wedge rim, glass tooltip
  (`:64`,`:275`,`:323`); `CollectorDock.swift` dock material + chip/drag glow
  (`:87`,`:236`,`:328`); all `.glass` buttons across the tool popovers
  (`CleanupActionBar`, `CleanupSuggestionsView`, `DuplicateFinderView`,
  `LargeOldFilesView`, `FileSearchView`, `AppUninstallerView`, `HiddenSpaceView`).

> The site already proves the target: these same jobs render flat, legible, and
> identically cross-platform with tokens + shadcn/Radix (§2–§6). The app follows.
