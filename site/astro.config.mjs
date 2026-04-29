// @ts-check
import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';
import icon from 'astro-icon';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  site: 'https://chappygo-os.github.io',
  base: '/atomic-spec/',
  trailingSlash: 'ignore',
  output: 'static',
  build: { format: 'directory', assets: '_assets' },
  integrations: [
    mdx({ syntaxHighlight: 'shiki', shikiConfig: { theme: 'github-dark-dimmed' } }),
    react(),
    // Lucide allowlist — restrict to icons actually used in components.
    // Wildcard ('*') would bundle ~1,500 icons; explicit list keeps the build lean.
    icon({
      include: {
        lucide: [
          'activity',
          'alert-octagon',
          'alert-triangle',
          'arrow-right',
          'book-open',
          'brain',
          'check-circle-2',
          'check-square',
          'chevron-right',
          'cloud',
          'cpu',
          'credit-card',
          'database',
          'figma',
          'file-code',
          'file-text',
          'git-commit',
          'layers',
          'layout',
          'lock',
          'pen-tool',
          'play',
          'plug-zap',
          'scale',
          'shield',
          'terminal',
          'unlink',
          'unlock',
          'users',
        ],
      },
    }),
    sitemap(),
  ],
  vite: { plugins: [tailwindcss()] },
});
