import { defineConfig } from 'vite'
import { devtools } from '@tanstack/devtools-vite'

import { tanstackStart } from '@tanstack/react-start/plugin/vite'

import viteReact from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// GitHub Pages serves a project site under `/<repo>/` but a custom domain at
// `/`. The deploy workflow feeds the correct prefix in via BASE_PATH (from
// actions/configure-pages), so assets resolve in both cases with no rebuild
// churn. Defaults to root for local dev/build.
const rawBase = process.env.BASE_PATH || '/'
const base = rawBase.endsWith('/') ? rawBase : `${rawBase}/`

const config = defineConfig({
  base,
  resolve: { tsconfigPaths: true },
  plugins: [
    devtools(),
    tailwindcss(),
    // Marketing site: prerender the single route to static HTML at build time
    // (SEO-friendly, deployable as a pure static site to GitHub Pages).
    // crawlLinks MUST stay false — crawling follows external anchors and can
    // corrupt binary assets in the output. We prerender '/' explicitly.
    tanstackStart({
      prerender: { enabled: true, crawlLinks: false },
      pages: [{ path: '/' }],
    }),
    viteReact(),
  ],
})

export default config
