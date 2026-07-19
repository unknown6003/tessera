// AUTO-GENERATED from the design/marketing workflow (do not lose: hand-edit copy here).
export const content = {
  brand: {
    name: 'Tessera',
    tagline: 'Reclaim your disk — and your trust.',
    oneLiner:
      'See every byte on your Mac in a beautiful interactive map, then reclaim the space. Free, open source, and 100% on your Mac.',
    voice:
      'Calm, confident, plain-spoken, and respectful. A knowledgeable friend who respects your machine, your intelligence, and your privacy. Never hypes, never scares, never nags.',
  },
  seo: {
    title: 'Tessera — See and reclaim your Mac’s disk. Free & open source.',
    description:
      'A beautiful interactive map of every file on your Mac, plus a fast duplicate finder, app uninstaller, and dev-junk cleaner. Free, open source, no account, no telemetry — nothing ever leaves your Mac.',
    ogTitle: 'Tessera — see every byte, reclaim the space. Free & open source.',
    ogDescription:
      'Visualize every byte, find duplicates, clean dev junk and app leftovers. Free, open source, 100% on-device. Nothing ever leaves your Mac.',
  },
  nav: [
    {
      label: 'Features',
      href: '#features',
    },
    {
      label: 'Privacy',
      href: '#privacy',
    },
    {
      label: 'Compare',
      href: '#compare',
    },
    {
      label: 'Download',
      href: '#download',
    },
    {
      label: 'FAQ',
      href: '#faq',
    },
  ],
  hero: {
    kicker: 'Native macOS · Apple Silicon · Free & open source',
    headline: 'See every byte on your Mac. Reclaim the space.',
    subhead:
      'A gorgeous interactive sunburst maps your whole disk, then helps you clear duplicates, dev junk, and app leftovers — with no account, no telemetry, and nothing leaving your Mac. Free and open source.',
    primaryCta: {
      label: 'Download for macOS',
      href: '#download',
    },
    secondaryCta: {
      label: 'See it in action',
      href: '#demo',
    },
    highlights: [
      'Free & open source (GPL-3.0)',
      'No account, no telemetry',
      'Nothing leaves your Mac',
      'Move to Trash by default',
    ],
    footnote:
      'Built by an indie developer and open source under GPL-3.0. Requires macOS 26 (Tahoe) or later, Apple Silicon. Direct download — not the App Store.',
  },
  trust: {
    headline: 'Built for people who read the permissions dialog.',
    items: [
      'No account, ever',
      'No telemetry or analytics',
      'No subscription',
      'Open source (GPL-3.0)',
      'Move to Trash by default',
      '100% on-device',
    ],
  },
  features: [
    {
      icon: 'PieChart',
      title: "See exactly what's using your disk",
      description:
        'A live, multi-color sunburst maps every file on any drive. Click a wedge to dive in; the biggest space hogs are impossible to miss.',
    },
    {
      icon: 'Gauge',
      title: 'Scans the whole disk, fast',
      description:
        "A parallel scan engine built on macOS's fastest low-level file APIs reads your whole drive in seconds. Switch between internal, external, cloud, and network volumes instantly from an in-memory cache.",
    },
    {
      icon: 'Copy',
      title: 'Find true duplicates',
      description:
        'A fast content fingerprint catches duplicate files at roughly scan speed, then verifies real copies before surfacing them. Every match goes to a review step, so you never delete a file you meant to keep.',
    },
    {
      icon: 'Code',
      title: 'Clear dev junk, keep your code',
      description:
        'Xcode DerivedData, node_modules, and package caches add up to gigabytes — all rebuilt automatically. Tessera finds them and leaves your actual projects alone.',
    },
    {
      icon: 'Layers',
      title: 'Group space by kind',
      description:
        "The By Kind lens groups everything as Video, Photo, App, Archive, Code, and more — so you can see at a glance whether it's media or apps eating your drive.",
    },
    {
      icon: 'FileSearch',
      title: 'Large & old files, on demand',
      description:
        'Filter by size, age, and kind to surface the forgotten 4 GB video and the installer you downloaded two years ago. Real numbers, no guessing.',
    },
    {
      icon: 'AppWindow',
      title: 'Uninstall apps completely',
      description:
        "Remove an app and the leftovers it scatters — Caches, Application Support, Preferences, Containers, LaunchAgents — with conservative matching that won't touch the wrong files.",
    },
    {
      icon: 'Eraser',
      title: 'Find leftovers from deleted apps',
      description:
        'Support files left behind by apps you removed long ago still sit on your disk. Tessera tracks them down so you can finally clear them.',
    },
    {
      icon: 'HardDrive',
      title: 'Explain the hidden space',
      description:
        "Read and clear purgeable caches, APFS local snapshots, and Full-Disk-Access-gated files — the space macOS won't explain, sometimes tens of gigabytes. Stop guessing where it went.",
    },
  ],
  howItWorks: [
    {
      title: 'Scan any drive',
      description:
        'Point Tessera at your internal disk, an external drive, a cloud folder, or a network share. The sunburst fills in as it reads, at full disk speed.',
    },
    {
      title: "See what's there",
      description:
        'Explore the map, group by kind, and find duplicates and large old files. Everything is computed on your Mac — nothing is ever uploaded.',
    },
    {
      title: 'Stage what to remove',
      description:
        'Suggested items land in a collector you review before anything happens. You decide what stays and what goes — Tessera never auto-deletes.',
    },
    {
      title: 'Reclaim the space',
      description:
        "Move to Trash by default, so it's recoverable. Delete Permanently is a separate, explicit, confirmed action. The space — and the decision — are yours.",
    },
  ],
  privacy: {
    kicker: 'Privacy as architecture, not a policy',
    headline: "We couldn't see your files if we wanted to.",
    body: 'Most "smart cleaners" need Full Disk Access and a network connection — and ask you to trust them with both. Tessera has no servers, no analytics, and no account, so there is nothing to leak and no one to leak it to. Everything runs on your hardware. The only time the app reaches the network on its own is when it checks for an update — and because it is open source, you can read exactly what it does, line by line.',
    points: [
      {
        title: 'No account, no telemetry',
        description:
          'You never sign in. We never collect usage data. There is no analytics SDK, no crash beacon, no "anonymous" tracking — nothing. You can audit it with Little Snitch and watch the silence.',
      },
      {
        title: "Open source, so you don't have to trust us",
        description:
          "Every line ships under the GPL-3.0 license. You don't have to take our word for the privacy claims — read the code, build it yourself, and verify every network call. Nothing about how Tessera works is hidden.",
      },
      {
        title: 'The network is almost always silent',
        description:
          'Tessera reaches the network on its own for exactly one thing — checking for updates — plus any network share you choose to mount. Your files are never part of that traffic.',
      },
      {
        title: 'Outside the App Store, on purpose',
        description:
          "We scan your whole disk and read APFS snapshots — impossible inside Apple's sandbox. So we ship as a direct download instead, distributed outside the App Store with full access to actually find your space.",
      },
    ],
  },
  comparison: {
    headline: 'One app instead of three — and it’s free.',
    subhead:
      'DaisyDisk shows your disk, Gemini de-dupes it, CleanMyMac cleans it — about $70 in year one. Tessera does all three, free.',
    columns: ['', 'Tessera', 'DaisyDisk', 'CleanMyMac', 'Gemini'],
    rows: [
      {
        label: 'Price',
        values: ['Free', '$9.99', '~$40/yr', '$19.95'],
      },
      {
        label: 'Disk map',
        values: ['Yes', 'Yes', 'No', 'No'],
      },
      {
        label: 'Duplicate finder',
        values: ['Yes', 'No', 'No', 'Yes'],
      },
      {
        label: 'Cleanup + uninstaller',
        values: ['Yes', 'No', 'Yes', 'No'],
      },
      {
        label: 'Explains hidden space',
        values: ['Yes', 'Partial', 'Partial', 'No'],
      },
      {
        label: 'Open source',
        values: ['Yes', 'No', 'No', 'No'],
      },
      {
        label: 'No account',
        values: ['Yes', 'Yes', 'No', 'Yes'],
      },
    ],
  },
  download: {
    kicker: 'Free. Open source. Yours.',
    headline: 'Download Tessera — free forever.',
    subhead:
      'No price, no account, no upsells — and nothing about your Mac ever leaves your Mac. Tessera is open source under GPL-3.0. If it saves you some space, a star on GitHub or a sponsorship is what keeps it going.',
    includes: [
      'Disk visualization (like DaisyDisk)',
      'Duplicate finder (like Gemini)',
      'Cleanup + app uninstaller (like CleanMyMac)',
      'Free and open source under GPL-3.0',
      'Updates itself automatically — no clicks',
      'No account, no telemetry, ever',
    ],
    ctaLabel: 'Download for macOS',
    starLabel: 'Star on GitHub',
    sponsorLabel: 'Sponsor',
    note: 'Requires macOS 26 (Tahoe) or later, Apple Silicon. The current build is unsigned — on first launch, right-click the app and choose Open (or System Settings → Privacy & Security → Open Anyway). You only do this once.',
  },
  faq: [
    {
      q: 'Is it really free?',
      a: 'Yes — completely. Tessera is free and open source under the GPL-3.0 license. No price, no subscription, no account, no upsells. If it helps you, starring the repo or sponsoring development is the best way to say thanks.',
    },
    {
      q: 'Is it really open source? Can I build it myself?',
      a: 'Yes. The full source is on GitHub under GPL-3.0. Clone it, read it, build it, and send patches. Nothing about how Tessera works is hidden — the privacy claims on this page are things you can verify yourself.',
    },
    {
      q: 'macOS says "unidentified developer" or won\'t open it. Is that safe?',
      a: "Yes. Tessera is a direct download outside the App Store, and the current build is unsigned, so macOS asks you to approve it on first launch. Drag Tessera to Applications, right-click it and choose Open (or open System Settings → Privacy & Security and click Open Anyway). You only do this once. Because it's open source, you can read exactly what it does — and watch it stay silent with a tool like Little Snitch.",
    },
    {
      q: "Why isn't it on the Mac App Store?",
      a: "Because the App Store sandbox makes it impossible to do the job right. Scanning your whole disk and reading APFS snapshots can't happen inside Apple's sandbox. We ship a direct download instead, with full access to actually find your space.",
    },
    {
      q: 'How is this different from CleanMyMac?',
      a: "Same useful jobs — cleanup, uninstalling, finding junk — without the two things people resent: the subscription and the surveillance. CleanMyMac is about $40 every year; Tessera is free and open source, with no telemetry. Plus you get a real disk visualization and a duplicate finder CleanMyMac doesn't offer.",
    },
    {
      q: 'How do updates work?',
      a: "Automatically, with nothing for you to do. Tessera checks on its own using Sparkle, then downloads, installs and relaunches the new version in the background — no store, no account, no clicks. It waits until you're not mid-scan so it never interrupts you. Every update is cryptographically signed and verified before it installs, so silent doesn't mean unchecked. It's the only thing the app does on the network without you asking.",
    },
    {
      q: 'What are the system requirements?',
      a: "macOS 26 (Tahoe) or later, on an Apple Silicon Mac. That's it.",
    },
    {
      q: 'Is my data safe? Can it delete the wrong thing?',
      a: "By design, no. Suggested items go to a collector you review before anything happens — Tessera never auto-deletes. The default is Move to Trash, which is recoverable. Delete Permanently is a separate, explicit, confirmed action. App-uninstall matching is deliberately conservative, and duplicate matches are verified before they're surfaced.",
    },
  ],
  finalCta: {
    headline: 'Reclaim your disk — and your trust.',
    subhead:
      'See every byte, clear what you don’t need, and never wonder where it goes — because nothing leaves your Mac. Free, open source, yours.',
    cta: {
      label: 'Download for macOS',
      href: '#download',
    },
  },
  footer: {
    tagline: 'See every byte. Reclaim the space. Nothing ever leaves your Mac.',
    legal:
      '© 2026 Tessera. Open source under GPL-3.0. Built for macOS. Not affiliated with Apple, DaisyDisk, MacPaw, or Gemini. macOS is a trademark of Apple Inc.',
    columns: [
      {
        title: 'Product',
        links: [
          {
            label: 'Features',
            href: '#features',
          },
          {
            label: 'Privacy',
            href: '#privacy',
          },
          {
            label: 'Compare',
            href: '#compare',
          },
          {
            label: 'Download',
            href: '#download',
          },
          {
            label: 'See it in action',
            href: '#demo',
          },
        ],
      },
      {
        title: 'Support',
        links: [
          {
            label: 'FAQ',
            href: '#faq',
          },
          {
            label: 'System requirements',
            href: '#faq',
          },
          {
            label: 'Contact',
            href: 'mailto:tessera@bdwy.xyz',
          },
        ],
      },
      {
        title: 'Open source',
        links: [
          {
            label: 'Source on GitHub',
            href: 'https://github.com/unknown6003/tessera',
          },
          {
            label: 'License (GPL-3.0)',
            href: 'https://github.com/unknown6003/tessera/blob/main/LICENSE',
          },
          {
            label: 'Sponsor',
            href: 'https://github.com/sponsors/unknown6003',
          },
        ],
      },
    ],
  },
} as const

// Design tokens — the single flat, single-accent dark system shared by the
// site and (as a spec) any future cross-platform app build. No "Liquid Glass",
// no gradients, no glows, no frosted materials: solid fills + hairline borders,
// so it renders identically on macOS, Windows, and Linux. The live CSS values
// live in src/styles.css; these mirror them for docs/tooling. See DESIGN.md.
export const design = {
  mood: 'Flat, single-accent dark. A near-black neutral void as the canvas, low-saturation surfaces, hairline borders, and one electric-cyan accent used sparingly (~10% of the surface). Calm, premium, legible — an instrument, not a SaaS gradient. Pure tokens, not platform materials, so every OS looks the same.',
  palette: {
    bg: '#0a0b0d', // 60% — dominant neutral void
    surface: '#101216', // secondary surfaces / pills
    card: '#131418', // panels
    elevated: '#17191e', // raised panels
    foreground: '#f3f4f6', // primary text
    mutedForeground: '#969ba4', // secondary text
    border: 'rgba(255,255,255,0.08)', // hairline
    borderStrong: 'rgba(255,255,255,0.14)',
    brand: '#1be6ff', // 10% — the single accent
    brandInk: '#04171c', // text/icon on top of the accent
    destructive: '#ff5c7a',
  },
  radius: { sm: '8px', md: '11px', lg: '14px', xl: '20px' },
  shadow: {
    sm: '0 1px 2px rgba(0,0,0,0.4)',
    lg: '0 24px 60px -30px rgba(0,0,0,0.8)',
  },
  // Sunburst chart palette. The first four match the app-icon wedges
  // (src/lib/brand.js) so the product and its icon read as one thing.
  sunburstColors: [
    '#1BE6FF',
    '#37E0C8',
    '#5B8CFF',
    '#9E6BFF',
    '#5BE36B',
    '#FF5CC8',
    '#FFB13C',
  ],
  motion:
    'Subtle, slow. Honor prefers-reduced-motion: disable sunburst rotation and fade-up (snap to final state); keep only opacity crossfades.',
} as const
