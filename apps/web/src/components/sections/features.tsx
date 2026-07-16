'use client';

import { motion } from 'framer-motion';

import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { FEATURES } from '@/lib/constants';

const STAGGER = {
  hidden: {},
  show: { transition: { staggerChildren: 0.09 } },
};

const FADE_UP = {
  hidden: { opacity: 0, y: 20 },
  show:   { opacity: 1, y: 0, transition: { duration: 0.45, ease: 'easeOut' } },
};

export function Features() {
  return (
    <section id="features" className="bg-[#08110A] py-20 px-6">
      <div className="mx-auto max-w-7xl">
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-60px' }}
          transition={{ duration: 0.5 }}
          className="mb-12 text-center"
        >
          <p className="mb-2 text-xs font-bold uppercase tracking-widest text-[#A7E635]">
            Protocol design
          </p>
          <h2 className="text-3xl font-black tracking-tight text-white sm:text-4xl">
            Built to protect every participant
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-[#7a9080]">
            Every design decision in SHERWOOD favours transparency and buyer protection — not
            protocol complexity.
          </p>
        </motion.div>

        <motion.div
          variants={STAGGER}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true, margin: '-40px' }}
          className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3"
        >
          {FEATURES.map((feature) => (
            <motion.div key={feature.title} variants={FADE_UP}>
              <Card className="group h-full rounded-2xl border-[rgba(167,230,53,0.10)] bg-[#111814] transition-all duration-300 hover:border-[rgba(167,230,53,0.35)] hover:shadow-[0_0_24px_rgba(167,230,53,0.07)]">
                <CardHeader className="pb-3">
                  <div className="mb-3 flex h-11 w-11 items-center justify-center rounded-xl border border-[rgba(167,230,53,0.20)] bg-[rgba(167,230,53,0.08)] text-xl transition-colors duration-200 group-hover:bg-[rgba(167,230,53,0.12)]">
                    {feature.icon}
                  </div>
                  <CardTitle className="text-base text-white">{feature.title}</CardTitle>
                </CardHeader>
                <CardContent className="pt-0">
                  <CardDescription className="text-sm leading-relaxed text-[#7a9080]">
                    {feature.description}
                  </CardDescription>
                </CardContent>
              </Card>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
