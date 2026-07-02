import { defineConfig } from 'astro/config';
import cloudflare from '@astrojs/cloudflare';

// output stays the default 'static': every page is prerendered unless it
// opts out with `export const prerender = false`. The adapter is what makes
// that opt-out actually render on-demand (Cloudflare Pages Functions) instead
// of failing the build — it does not turn the whole site server-rendered.
export default defineConfig({
  site: 'https://ringdrill.app',
  adapter: cloudflare(),
  i18n: {
    defaultLocale: 'nb',
    locales: ['nb', 'en'],
    routing: {
      prefixDefaultLocale: false,
    },
  },
});
