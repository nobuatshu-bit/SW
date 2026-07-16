'use client';

import { motion } from 'framer-motion';

import { HOW_IT_WORKS_STEPS } from '@/lib/constants';

const STAGGER = {
  hidden: {},
  show: { transition: { staggerChildren: 0.12 } },
};

const FADE_UP = {
  hidden: { opacity: 0, y: 24 },
  show:   { opacity: 1, y: 0, transition: { duration: 0.5, ease: 'easeOut' } },
};

export function HowItWorks() {
  return (
    <section id="how-it-works" className="bg-[#08110A] py-20 px-6">
      <div className="mx-auto max-w-7xl">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-60px' }}
          transition={{ duration: 0.5 }}
          className="mb-14 text-center"
        >
          <p className="mb-2 text-xs font-bold uppercase tracking-widest text-[#A7E635]">
            Simple by design
          </p>
          <h2 className="text-3xl font-black tracking-tight text-white sm:text-4xl">
            How it works
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-[#7a9080]">
            SHERWOOD removes complexity from token launches. Four steps from wallet to tokens.
          </p>
        </motion.div>

        {/* Steps */}
        <motion.ol
          variants={STAGGER}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true, margin: '-40px' }}
          className="relative grid gap-8 md:grid-cols-4"
        >
          {/* Connector line */}
          <div
            className="pointer-events-none absolute left-0 right-0 top-10 hidden h-px bg-gradient-to-r from-transparent via-[rgba(167,230,53,0.25)] to-transparent md:block"
            aria-hidden
          />

          {HOW_IT_WORKS_STEPS.map((step) => (
            <motion.li
              key={step.step}
              variants={FADE_UP}
              className="relative flex flex-col gap-4"
            >
              {/* Step bubble */}
              <div
                className="flex h-20 w-20 shrink-0 items-center justify-center self-start rounded-2xl border border-[rgba(167,230,53,0.20)] bg-[#0D1A12] shadow-[0_0_16px_rgba(167,230,53,0.08)] md:mx-auto md:self-auto"
              >
                <span className="font-mono text-2xl font-black text-[#A7E635]">
                  {step.step}
                </span>
              </div>

              <div className="md:text-center">
                <h3 className="mb-1.5 text-base font-bold leading-snug text-white">
                  {step.title}
                </h3>
                <p className="text-sm leading-relaxed text-[#7a9080]">{step.description}</p>
              </div>
            </motion.li>
          ))}
        </motion.ol>
      </div>
    </section>
  );
}
