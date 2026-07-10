import { HeadContent, Scripts, createRootRoute } from '@tanstack/react-router'
import type { ReactNode } from 'react'

import appCss from '../styles.css?url'
import { content } from '../data/spec'

const { seo } = content

export const Route = createRootRoute({
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { name: 'color-scheme', content: 'dark' },
      { name: 'theme-color', content: '#06121A' },
      { title: seo.title },
      { name: 'description', content: seo.description },
      { property: 'og:type', content: 'website' },
      { property: 'og:site_name', content: content.brand.name },
      { property: 'og:title', content: seo.ogTitle },
      {
        property: 'og:description',
        content: seo.ogDescription,
      },
      { property: 'og:image', content: '/logo512.png' },
      { property: 'og:image:alt', content: `${content.brand.name} app icon` },
      { name: 'twitter:card', content: 'summary_large_image' },
      { name: 'twitter:title', content: seo.ogTitle },
      {
        name: 'twitter:description',
        content: seo.ogDescription,
      },
      { name: 'twitter:image', content: '/logo512.png' },
    ],
    links: [{ rel: 'stylesheet', href: appCss }],
  }),
  shellComponent: RootDocument,
})

function RootDocument({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className="dark">
      <head>
        {/* mark JS available before first paint so scroll-reveal can hide
            initial state without flashing for JS users, while no-JS users
            keep fully-visible prerendered content */}
        <script
          dangerouslySetInnerHTML={{
            __html: "document.documentElement.classList.add('js')",
          }}
        />
        <HeadContent />
      </head>
      <body>
        {children}
        <Scripts />
      </body>
    </html>
  )
}
