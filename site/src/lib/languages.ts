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
