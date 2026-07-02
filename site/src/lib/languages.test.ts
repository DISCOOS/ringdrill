import { describe, expect, it } from 'vitest';
import { LANGUAGE_NAMES } from './languages';

describe('LANGUAGE_NAMES', () => {
  it('covers nb and en', () => {
    expect(LANGUAGE_NAMES.nb).toBe('Norsk');
    expect(LANGUAGE_NAMES.en).toBe('English');
  });
});
