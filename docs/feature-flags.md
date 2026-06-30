# Build-time feature flags

This is the living index of every dart-define flag the app reads at
build time. Update this file in the same commit that introduces,
changes or removes a flag.

The shape of this index and the conventions are defined in
[ADR-0042](./adrs/0042-feature-flags-and-sunset-telemetry.md).

| Name | Type | Kind | Default | Purpose | Introduced by | Sunset criterion |
|------|------|------|---------|---------|---------------|------------------|
| `MIGRATION_DISABLED` | `bool` | Temporary | `false` | Kill switch that hides the in-app migration banner, drawer entry and explainer when the new `web.ringdrill.app` PWA is not yet ready. | [ADR-0039](./adrs/0039-site-pwa-api-origins.md) Phase 1 | Remove when sunset telemetry reports 0 legacy-apex sessions over 30 consecutive days after Phase 3 cutover. |
| `RINGDRILL_FORCE_LEGACY_HOST` | `bool` | Temporary | `false` | Dev-only override that makes `isLegacyHost()` return true regardless of the actual host. Used to exercise the migration UI on `localhost` during development. | [ADR-0039](./adrs/0039-site-pwa-api-origins.md) Phase 1 | Remove together with `MIGRATION_DISABLED`. Same sunset criterion. |
| `RINGDRILL_LOCAL_BASE_URL` | `String` | Permanent | `''` | Debug-only override that points the catalog client at a local `netlify dev` instance. Documented in [ADR-0013](./adrs/0013-local-catalog-testing.md). | [ADR-0013](./adrs/0013-local-catalog-testing.md) | — |
