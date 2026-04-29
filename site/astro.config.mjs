// @ts-check
import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';
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
    sitemap(),
  ],
  vite: { plugins: [tailwindcss()] },
});
