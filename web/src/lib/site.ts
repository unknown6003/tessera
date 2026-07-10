// Runtime site configuration, sourced from env (see .env.example).
// Tessera is free & open source — there is no checkout and no price.

const GITHUB_OWNER = 'unknown6003'

export const site = {
  /**
   * Direct download for the macOS build. Defaults to the latest `tessera`
   * GitHub Release asset (works on any deploy, no env needed); override with
   * VITE_DOWNLOAD_URL if you host the .dmg elsewhere.
   */
  downloadUrl:
    (import.meta.env.VITE_DOWNLOAD_URL as string) ||
    `https://github.com/${GITHUB_OWNER}/tessera/releases/latest/download/Tessera.dmg`,
  /** Source repository — public once open-sourced. */
  githubUrl:
    (import.meta.env.VITE_GITHUB_URL as string) ||
    `https://github.com/${GITHUB_OWNER}/tessera`,
  /** GitHub Sponsors page, for optional support. */
  sponsorUrl:
    (import.meta.env.VITE_SPONSOR_URL as string) ||
    `https://github.com/sponsors/${GITHUB_OWNER}`,
}
