import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

/**
 * Merge conditional class names, resolving Tailwind conflicts.
 *
 * `components.json` maps the `@/lib/utils` alias here, so any UI component
 * sourced from the registries can use the standard `cn()` helper.
 */
export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}
