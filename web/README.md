# Tessera — landing site

Marketing site for the Tessera macOS app. Static, prerendered, deployed to
**GitHub Pages**. Tessera is **free & open source** (GPL-3.0) — there is no
checkout; the primary CTA is a direct `.dmg` download.

## Stack

- **TanStack Start** (Vite 8, React 19) — prerendered to static HTML
  (`prerender` in `vite.config.ts`, output in `dist/client`).
- **Tailwind v4** + **shadcn/ui** (new-york), reskinned to the app's dark
  "Liquid Glass" design system in `src/styles.css`.
- All copy + design tokens live in `src/data/spec.ts` (edit copy there).
- Runtime links (download / GitHub / Sponsors) resolve in `src/lib/site.ts`.

## Develop

```sh
pnpm install
pnpm dev      # http://localhost:3000
pnpm build    # → dist/client (static)
```

## Configuration (env)

Copy `.env.example` → `.env` to override anything locally. All client vars are
`VITE_`-prefixed and **optional** — each has a sensible default in
`src/lib/site.ts`, so the site builds and deploys with zero configuration.

| Var                 | Purpose                                                                                        |
| ------------------- | ---------------------------------------------------------------------------------------------- |
| `VITE_DOWNLOAD_URL` | Where the `.dmg` is served. Defaults to the latest GitHub Release asset on the `tessera` repo. |
| `VITE_GITHUB_URL`   | Source repository (the "Star on GitHub" / source links).                                       |
| `VITE_SPONSOR_URL`  | GitHub Sponsors page (the optional "Sponsor" button).                                          |

## The download artifact

The download button points at a **GitHub Release** asset, not a file bundled in
this site. The app build (`Tessera.dmg`) is published as a release on the
`tessera` repo, and `site.downloadUrl` defaults to its
`releases/latest/download/Tessera.dmg` URL — so **any** deploy (including
git-integration) gets a working download with no extra configuration.

To ship a new build, run the release script at the repo root (see the release
runbook / `RELEASING.md`), which builds the `.dmg`, signs the Sparkle appcast,
and publishes them as a `tessera` GitHub Release. No change to this site is
required.

## Deploy (GitHub Pages)

Deployment is automated. `.github/workflows/deploy-pages.yml` builds the site
and publishes `dist/client` to GitHub Pages on every push to `main`.

One-time setup (repo owner):

1. Make this repo **public** (GitHub Pages is free only for public repos).
2. **Settings → Pages → Build and deployment → Source: GitHub Actions.**

After that every push to `main` builds and deploys automatically.

The build resolves its asset prefix from the live Pages config (the workflow's
Configure Pages step feeds `BASE_PATH` into `vite.config.ts`), so it renders
correctly both at the project URL (`https://<user>.github.io/tessera/`) and at a
custom domain root — no rebuild needed when you attach one.

### Custom domain

When ready, add the domain under **Settings → Pages → Custom domain**. GitHub
writes a `CNAME` file into the published site and provisions HTTPS. Point the
domain's DNS at GitHub Pages (a `CNAME` record → `<user>.github.io`, or the four
Pages `A` records for an apex domain).
