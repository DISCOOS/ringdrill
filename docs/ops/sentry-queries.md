# Sentry queries

A cookbook of queries we actually use against the tags and events RingDrill emits. [ADR-0042](../adrs/0042-feature-flags-and-sunset-telemetry.md) is the convention; this file is the practical reference.

Keep this file updated as new tags or events are added. If you find yourself running a query more than twice, write it down here and link to the saved Sentry view if you saved one.

## What's tagged

Every event from a release web build carries these scope tags (set in `lib/main.dart` after Sentry init):

| Tag | Values | Source |
|-----|--------|--------|
| `flag.MIGRATION_DISABLED` | `true` / `false` | dart-define, default `false` |
| `flag.RINGDRILL_FORCE_LEGACY_HOST` | `true` / `false` | dart-define, default `false` |
| `flag.RINGDRILL_LOCAL_BASE_URL` | `''` or local URL | dart-define, default empty |
| `app.origin` | `ringdrill.app`, `web.ringdrill.app`, `localhost:NNNN`, `native` | `Uri.base.host` on web, `'native'` elsewhere |
| `app.legacy_apex` | `true` / `false` | Output of `isLegacyHost()` |

Plus Sentry's default release/environment/user tags.

## Sunset telemetry

The headline use case. Tells us when a legacy code path is safe to delete.

### Are users still booting on legacy apex?

When the app boots and `isLegacyHost()` returns true, the client sends `captureMessage('boot on legacy apex', level: info)`. The Issue this creates aggregates all such boots.

**Issues view:**

```
level:info message:"boot on legacy apex"
```

(Default Issues filter hides info-level. Either widen the level filter or use Discover below.)

**Discover, raw counts over time:**

```
Event type:       error
Query:            message:"boot on legacy apex"
Group by:         release
Display:          count(), count_unique(user)
Time:             Last 30 days
```

**Sunset criterion (per ADR-0042):** 0 events over 30 consecutive days after Phase 3 cutover lands. When that holds:

* Delete `MIGRATION_DISABLED` from `lib/utils/app_flags.dart` and the deploy workflow
* Delete `RINGDRILL_FORCE_LEGACY_HOST` and the related dev override
* Delete the migration banner, drawer entry, migration page, ARB strings and tests
* Delete this Discover query — it has no purpose after the code is gone

Save as a Dashboard widget once Phase 3 is live so you can glance the trend without rebuilding the query each week.

### Errors on legacy apex

If something breaks for users still on legacy apex, this is where you find it.

**Issues view:**

```
app.legacy_apex:true level:[error, fatal]
```

Sort by frequency or by "last seen" depending on whether you are triaging an active spike or auditing the long tail.

## Bug triage by build state

### Issues by origin

Useful when you suspect an error only happens on one of the three origins.

**Issues view:**

```
app.origin:web.ringdrill.app
```

```
app.origin:ringdrill.app
```

```
app.origin:native
```

### Issues with the kill switch off

When `MIGRATION_DISABLED=false`, the migration UI is live in production. Errors in that flow are filtered with:

```
flag.MIGRATION_DISABLED:false app.legacy_apex:true
```

### Issues from local dev that slipped to prod

If `RINGDRILL_LOCAL_BASE_URL` is non-empty in any production event, that's a misconfiguration — debug builds should not report to the production Sentry project.

```
!flag.RINGDRILL_LOCAL_BASE_URL:""
```

(The exact "is set" syntax depends on Sentry's UI version. Use the tag distribution on any matching issue to see all observed values.)

## Lifecycle and rollout sanity

### Distribution of flag values across active issues

Useful right after flipping a feature flag in production to see who is still on the old value.

* Open any recent Issue
* Right sidebar → Tags → click `flag.MIGRATION_DISABLED`
* See the breakdown (e.g. 92% `true`, 8% `false`)

A skewed distribution often points to cached PWAs that have not picked up the new SW yet.

### Which releases are active per origin?

Discover:

```
Event type:       error or transaction
Group by:         release, app.origin
Display:          count_unique(user)
Time:             Last 7 days
```

Tells you which build numbers are alive on which origin. Helps decide when an old release can be retired from Sentry.

## Notes

* **Default level filter on Issues hides info events.** The sunset-telemetry event is info-level. Either widen the filter or use Discover.
* **Tag cardinality is bounded.** Three flags × small value sets + four origin values + a boolean. No tag-budget concern at our scale.
* **Free-tier limits matter.** Sentry's free tier caps Discover queries per month and dashboard widgets per project. Save only the queries you actually look at.
* **`app.origin` includes the port for localhost.** `localhost:5173` and `localhost:8000` count as different tag values. Filter with a wildcard or coerce in your query if you need to combine them.

## Related

* [ADR-0042](../adrs/0042-feature-flags-and-sunset-telemetry.md) — tagging convention and sunset criterion
* [ADR-0039](../adrs/0039-site-pwa-api-origins.md) — site/PWA/API split, source of the legacy-apex sunset
* [ADR-0006](../adrs/0006-sentry-behind-consent-gate.md) — Sentry only fires when consent is granted; some users will not show up here at all
