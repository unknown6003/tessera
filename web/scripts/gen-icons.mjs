// ---------------------------------------------------------------------------
// Tessera icon build — regenerates every raster icon from ONE vector source
// (src/lib/brand.js). Run from web/:  `npm run icons`  (or `node scripts/gen-icons.mjs`).
//
// Emits (paths relative to repo root):
//   icon/tessera-icon.svg           master app icon (tile + mark)
//   icon/tessera-mark.svg           transparent mark only
//   icon/build/icon_<n>.png         app icon PNGs (16…1024)
//   icon/Tessera.iconset/           macOS iconset (feed to `iconutil` on a Mac)
//   icon/tessera.ico                Windows icon
//   web/public/favicon.ico          site favicon (16/32/48)
//   web/public/favicon.svg          crisp vector favicon
//   web/public/logo192.png          PWA / og:image
//   web/public/logo512.png          PWA / og:image
//
// macOS .icns: on a Mac run `iconutil -c icns icon/Tessera.iconset -o icon/Tessera.icns`
// (iconutil is macOS-only). Everything else is produced here on any platform.
// ---------------------------------------------------------------------------
import { mkdir, writeFile, rm } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import sharp from 'sharp'
import pngToIco from 'png-to-ico'
import { appIconSVG, markSVG } from '../src/lib/brand.js'

const here = dirname(fileURLToPath(import.meta.url)) // web/scripts
const web = join(here, '..') // web
const repo = join(web, '..') // repo root
const iconDir = join(repo, 'icon')
const buildDir = join(iconDir, 'build')
const iconsetDir = join(iconDir, 'Tessera.iconset')
const webPublic = join(web, 'public')
const appIconSet = join(
  repo,
  'Tessera',
  'Assets.xcassets',
  'AppIcon.appiconset',
)

const iconSVG = appIconSVG(1024)
const mark = markSVG(512)

const png = (svg, size) =>
  sharp(Buffer.from(svg))
    .resize(size, size, { fit: 'contain' })
    .png()
    .toBuffer()

async function main() {
  await rm(buildDir, { recursive: true, force: true })
  await rm(iconsetDir, { recursive: true, force: true })
  await mkdir(buildDir, { recursive: true })
  await mkdir(iconsetDir, { recursive: true })

  await writeFile(join(iconDir, 'tessera-icon.svg'), iconSVG)
  await writeFile(join(iconDir, 'tessera-mark.svg'), mark)

  for (const s of [16, 32, 64, 128, 256, 512, 1024]) {
    await writeFile(join(buildDir, `icon_${s}.png`), await png(iconSVG, s))
  }

  // macOS iconset + the Xcode asset catalog the app builds against
  // (ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon). Written from the same
  // vector, so the app icon can never drift from the site's mark.
  const iconset = [
    [16, 1],
    [16, 2],
    [32, 1],
    [32, 2],
    [128, 1],
    [128, 2],
    [256, 1],
    [256, 2],
    [512, 1],
    [512, 2],
  ]
  await mkdir(appIconSet, { recursive: true })
  const catalogImages = []
  for (const [base, scale] of iconset) {
    const name = `icon_${base}x${base}${scale === 2 ? '@2x' : ''}.png`
    const buf = await png(iconSVG, base * scale)
    await writeFile(join(iconsetDir, name), buf)
    await writeFile(join(appIconSet, name), buf)
    catalogImages.push({
      filename: name,
      idiom: 'mac',
      scale: `${scale}x`,
      size: `${base}x${base}`,
    })
  }
  await writeFile(
    join(appIconSet, 'Contents.json'),
    JSON.stringify(
      { images: catalogImages, info: { author: 'xcode', version: 1 } },
      null,
      2,
    ),
  )

  const icoPngs = await Promise.all(
    [16, 32, 48, 64, 128, 256].map((s) => png(iconSVG, s)),
  )
  await writeFile(join(iconDir, 'tessera.ico'), await pngToIco(icoPngs))

  await writeFile(join(webPublic, 'favicon.svg'), iconSVG)
  const favPngs = await Promise.all([16, 32, 48].map((s) => png(iconSVG, s)))
  await writeFile(join(webPublic, 'favicon.ico'), await pngToIco(favPngs))
  await writeFile(join(webPublic, 'logo192.png'), await png(iconSVG, 192))
  await writeFile(join(webPublic, 'logo512.png'), await png(iconSVG, 512))

  console.log('✓ icons generated from src/lib/brand.js')
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})
