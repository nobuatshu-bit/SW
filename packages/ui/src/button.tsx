import { cva, type VariantProps } from 'class-variance-authority';
import type { ButtonHTMLAttributes } from 'react';

import { cn } from './utils';

const buttonVariants = cva(
  'inline-flex items-center justify-center gap-2 rounded-md text-sm font-semibold transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background disabled:pointer-events-none disabled:opacity-40 select-none',
  {
    variants: {
      variant: {
        default: [
          'bg-primary text-primary-foreground',
          'shadow-[0_0_16px_rgba(167,230,53,0.30)]',
          'hover:bg-[#bef264] hover:shadow-[0_0_28px_rgba(167,230,53,0.50)]',
          'active:scale-[0.97]',
        ].join(' '),
        secondary: [
          'bg-[#0D1A12] text-primary border border-[rgba(167,230,53,0.25)]',
          'hover:bg-[#111F16] hover:border-[rgba(167,230,53,0.55)] hover:shadow-[0_0_14px_rgba(167,230,53,0.18)]',
          'active:scale-[0.97]',
        ].join(' '),
        outline: [
          'border border-[rgba(167,230,53,0.30)] bg-transparent text-primary',
          'hover:bg-[rgba(167,230,53,0.06)] hover:border-[rgba(167,230,53,0.55)]',
          'active:scale-[0.97]',
        ].join(' '),
        ghost: [
          'bg-transparent text-foreground',
          'hover:bg-[rgba(167,230,53,0.07)] hover:text-primary',
        ].join(' '),
        destructive: [
          'bg-destructive text-destructive-foreground',
          'hover:bg-destructive/90',
        ].join(' '),
      },
      size: {
        sm:      'h-8  px-3   text-xs',
        default: 'h-10 px-4   py-2',
        lg:      'h-11 px-7   text-base',
        xl:      'h-13 px-9   text-base',
        icon:    'h-10 w-10',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  },
);

export interface ButtonProps
  extends ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {}

export function Button({ className, variant, size, ...props }: ButtonProps) {
  return (
    <button className={cn(buttonVariants({ variant, size, className }))} {...props} />
  );
}
