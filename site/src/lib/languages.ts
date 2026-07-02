// Plan-content language support for the /catalog filter (ADR-0007 +
// ADR-0040 addenda). Scoped to the locales the app's own UI currently
// supports — extend this in lockstep with
// lib/views/program_form_screen.dart's kPlanLanguageNames (and
// netlify/functions/drills-preview.js's STRINGS[locale].languageNames)
// whenever a new UI locale (ARB file) is added.
export const LANGUAGE_NAMES: Record<string, string> = {
  nb: 'Norsk',
  en: 'English',
};

/**
 * Distinct, sorted language codes actually present across `items`. Nulls
 * (plan has no language set) are excluded — the filter's "All languages"
 * option covers those, not a per-code entry.
 */
export function distinctLanguageCodes(items: { languageCode: string | null }[]): string[] {
  return [...new Set(items.map((i) => i.languageCode).filter((c): c is string => Boolean(c)))].sort();
}
