// Resolve a path that lives under `public/` against Vite's configured base
// URL, so the asset loads correctly whether the site is served from the domain
// root ("/") or a project sub-path ("/tessera/" on GitHub Pages). Vite
// guarantees `import.meta.env.BASE_URL` ends with a trailing slash. Absolute
// URLs (http(s):, data:, protocol-relative) are returned unchanged.
export function asset(path: string): string {
  if (/^(?:[a-z]+:)?\/\//i.test(path) || path.startsWith('data:')) return path
  return `${import.meta.env.BASE_URL}${path.replace(/^\//, '')}`
}
