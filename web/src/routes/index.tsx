import { createFileRoute } from '@tanstack/react-router'

import { Header } from '../components/landing/Header'
import { Hero } from '../components/landing/Hero'
import { Trust } from '../components/landing/Trust'
import { ProductTour } from '../components/landing/ProductTour'
import { Features } from '../components/landing/Features'
import { HowItWorks } from '../components/landing/HowItWorks'
import { Privacy } from '../components/landing/Privacy'
import { Compare } from '../components/landing/Compare'
import { Download } from '../components/landing/Download'
import { FAQ } from '../components/landing/FAQ'
import { FinalCta } from '../components/landing/FinalCta'
import { Footer } from '../components/landing/Footer'

export const Route = createFileRoute('/')({
  component: Home,
})

function Home() {
  return (
    <>
      <a href="#main" className="skip-link">
        Skip to content
      </a>
      <Header />
      <main id="main">
        <Hero />
        <Trust />
        <ProductTour />
        <Features />
        <HowItWorks />
        <Privacy />
        <Compare />
        <Download />
        <FAQ />
        <FinalCta />
      </main>
      <Footer />
    </>
  )
}
