import { cva, type VariantProps } from 'class-variance-authority';
import type { HTMLAttributes } from 'react';

import { cn } from '@/lib/utils';

const badgeVariants = cva(
  'inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2',
  {
    variants: {
      variant: {
        default:
          'border-transparent bg-[#A7E635] text-[#050805]',
        secondary:
          'border-[rgba(167,230,53,0.15)] bg-[rgba(167,230,53,0.08)] text-[#7a9080]',
        outline:
          'border-[rgba(167,230,53,0.25)] text-[#A7E635]',
        success:
          'border-transparent bg-[rgba(167,230,53,0.12)] text-[#A7E635]',
        warning:
          'border-transparent bg-[rgba(251,191,36,0.12)] text-amber-400',
        destructive:
          'border-transparent bg-destructive/15 text-destructive',
      },
    },
    defaultVariants: { variant: 'default' },
  },
);

export interface BadgeProps
  extends HTMLAttributes<HTMLSpanElement>,
    VariantProps<typeof badgeVariants> {}

export function Badge({ className, variant, ...props }: BadgeProps) {
  return <span className={cn(badgeVariants({ variant }), className)} {...props} />;
}
