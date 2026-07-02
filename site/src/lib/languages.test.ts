import { describe, expect, it } from 'vitest';
import { distinctLanguageCodes, LANGUAGE_NAMES } from './languages';

describe('distinctLanguageCodes', () => {
  it('dedupes and sorts codes present in the items', () => {
    const items = [
      { languageCode: 'en' },
      { languageCode: 'nb' },
      { languageCode: 'en' },
    ];
    expect(distinctLanguageCodes(items)).toEqual(['en', 'nb']);
  });

  it('excludes null (unset) languages', () => {
    const items = [{ languageCode: 'nb' }, { languageCode: null }];
    expect(distinctLanguageCodes(items)).toEqual(['nb']);
  });

  it('returns an empty array for an empty list', () => {
    expect(distinctLanguageCodes([])).toEqual([]);
  });

  it('returns an empty array when every item is unset', () => {
    expect(distinctLanguageCodes([{ languageCode: null }, { languageCode: null }])).toEqual([]);
  });
});

describe('LANGUAGE_NAMES', () => {
  it('covers nb and en', () => {
    expect(LANGUAGE_NAMES.nb).toBe('Norsk');
    expect(LANGUAGE_NAMES.en).toBe('English');
  });
});
