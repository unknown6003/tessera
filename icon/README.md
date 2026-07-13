# Tessera app icon

A **simplified sunburst** — one bold donut of four unequal wedges on a near-black
rounded tile. It reads instantly as "a map of your used space" and stays legible
down to 16px. (The old mark was a two-ring, ~19-segment burst that blurred to
mush at small sizes.)

## One source, every size, every OS

Everything here is **generated from a single vector**: `web/src/lib/brand.js`
(`appIconSVG()` / `markSVG()`). Because every raster comes from that one source,
the icon is **identical on macOS, Windows, and Linux**.

```
cd web
npm install        # first time only (needs sharp + png-to-ico, in devDependencies)
npm run icons      # regenerate everything below
```

### Generated files

| Path | What | Consumed by |
|------|------|-------------|
| `icon/tessera-icon.svg` | master app icon (tile + mark) | design source |
| `icon/tessera-mark.svg` | transparent mark only | inline logo source |
| `icon/build/icon_<n>.png` | 16 → 1024 app-icon PNGs | Linux, general |
| `icon/Tessera.iconset/` | Apple @1x/@2x matrix | macOS `.icns` (see below) |
| `icon/tessera.ico` | multi-size Windows icon | Windows |
| `web/public/favicon.svg` | crisp vector favicon | site |
| `web/public/favicon.ico` | 16/32/48 favicon | site |
| `web/public/logo192.png`, `logo512.png` | PWA + OpenGraph image | site |

### Per-OS packaging

- **macOS** — on a Mac, turn the iconset into an `.icns`:
  ```
  iconutil -c icns icon/Tessera.iconset -o icon/Tessera.icns
  ```
  (`iconutil` is macOS-only; the iconset itself is produced on any platform.)
  Then add an `AppIcon` asset catalog to the app referencing these PNGs — the
  Xcode build already expects `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.
- **Windows** — ship `icon/tessera.ico`.
- **Linux** — ship `icon/build/icon_512.png` (and smaller) per the hicolor icon
  theme, or point your packager at `icon/build/`.

## Changing the icon

Edit **only** `web/src/lib/brand.js` — the palette (`PALETTE.wedges`), the wedge
sizes (`PROPORTIONS`), the ring thickness, or the tile — then run `npm run icons`.
The site mark and every OS icon update together, staying in sync by construction.
