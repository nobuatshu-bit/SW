import { Features } from '@/components/sections/features';
import { Hero } from '@/components/sections/hero';
import { HowItWorks } from '@/components/sections/how-it-works';
import { Statistics } from '@/components/sections/statistics';
import { TrendingLaunches } from '@/components/sections/trending-launches';
import { Footer } from '@/components/layout/footer';
import { Navbar } from '@/components/layout/navbar';

export default function HomePage() {
  return (
    <>
      <Navbar />
      <main>
        <Hero />
        <Statistics />
        <TrendingLaunches />
        <HowItWorks />
        <Features />
      </main>
      <Footer />
    </>
  );
}
