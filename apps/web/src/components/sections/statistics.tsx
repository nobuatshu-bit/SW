'use client';

import { motion } from 'framer-motion';

import { Separator } from '@/components/ui/separator';
import { STATS } from '@/lib/constants';

const FADE_UP = {
  hidden: { opacity: 0, y: 20 },
  show:   { opacity: 1, y: 0, transition: { duration: 0.5, ease: 'easeOut' } },
};

const STAGGER = {
  hidden: {},
  show: { transition: { staggerChildren: 0.1, delayChildren: 0.05 } },
};

export function Statistics() {
  return (
    <section className="border-y border-[rgba(167,230,53,0.10)] bg-[#08110A] py-12">
      <div className="mx-auto max-w-7xl px-6">
        <motion.dl
          variants={STAGGER}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true, margin: '-80px' }}
          className="grid grid-cols-2 gap-px bg-[rgba(167,230,53,0.08)] md:grid-cols-4"
        >
          {STATS.map((stat, index) => (
            <motion.div
              key={stat.label}
              variants={FADE_UP}
              className="relative flex flex-col gap-1 bg-[#08110A] px-8 py-8"
            >
              <dt className="text-sm font-medium text-[#7a9080]">{stat.label}</dt>
              <dd className="text-3xl font-black tracking-tight text-white sm:text-4xl">
                {stat.value}
              </dd>
              <span className="mt-1 inline-flex w-fit items-center gap-1 rounded-full bg-[rgba(167,230,53,0.10)] px-2.5 py-0.5 text-xs font-semibold text-[#A7E635]">
                <span className="h-1 w-1 rounded-full bg-[#A7E635]" />
                {stat.delta} this week
              </span>

              {index < STATS.length - 1 && (
                <Separator
                  orientation="vertical"
                  className="absolute right-0 top-1/4 hidden h-1/2 bg-[rgba(167,230,53,0.10)] md:block"
                />
              )}
            </motion.div>
          ))}
        </motion.dl>
      </div>
    </section>
  );
}
