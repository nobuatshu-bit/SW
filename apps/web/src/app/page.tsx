import { ConnectButton } from '@rainbow-me/rainbowkit';

export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-5xl flex-col px-6 py-12">
      <header className="flex items-center justify-between">
        <span className="text-lg font-semibold tracking-tight">SHERWOOD</span>
        <ConnectButton />
      </header>
      <section className="flex flex-1 flex-col justify-center gap-6">
        <p className="text-sm font-medium uppercase tracking-[0.24em] text-primary">Web3 platform</p>
        <h1 className="max-w-3xl text-5xl font-semibold tracking-tight sm:text-7xl">
          A scalable foundation for what comes next.
        </h1>
        <p className="max-w-xl text-lg text-foreground/70">
          SHERWOOD is ready for wallet connectivity, API integration, and Base Sepolia development.
        </p>
      </section>
    </main>
  );
}
