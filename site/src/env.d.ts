/// <reference types="astro/client" />

interface ImportMetaEnv {
  /** API origin for the on-demand routes (/catalog). Defaults to production when unset. */
  readonly PUBLIC_RINGDRILL_API_BASE?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
