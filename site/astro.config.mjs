import { defineConfig } from 'astro/config';
import cloudflare from '@astrojs/cloudflare';

// output stays the default 'static': every page is prerendered unless it
// opts out with `export const prerender = false`. The adapter is what makes
// that opt-out actually render on-demand (Cloudflare Pages Functions) instead
// of failing the build — it does not turn the whole site server-rendered.
export default defineConfig({
  site: 'https://ringdrill.app',
  adapter: cloudflare(),
  markdown: {
    // Shiki ships its own theme as inline styles on the <pre>, which would win over
    // the .prose code/pre rules in BaseLayout.astro and leave one dark block on an
    // otherwise light page (and no way to answer prefers-color-scheme). The snippets
    // on /mcp are a URL and a few lines of JSON, so highlighting buys nothing worth
    // a second, competing colour system.
    syntaxHighlight: false,
  },
  i18n: {
    defaultLocale: 'nb',
    locales: ['nb', 'en'],
    routing: {
      prefixDefaultLocale: false,
    },
  },
});
