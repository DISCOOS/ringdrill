import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://ringdrill.app',
  i18n: {
    defaultLocale: 'nb',
    locales: ['nb', 'en'],
    routing: {
      prefixDefaultLocale: false,
    },
  },
});
