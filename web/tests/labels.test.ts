import { describe, expect, it } from 'vitest';
import { formatCategories, labelBlock, parseCategories, replaceLabelBlock, rSym } from '../src/lib/labels';

// Printed by R/labels.R (figure_labels_code) for the same input, 2026-10-25.
const fromR = `figure_labels <- c(
  framing = "Framing",
  \`Preference(continuous)\` = "Preference \\"slider\\"",
  \`if\` = "If"
)
# Category labels: for a column, the text shown for each of its categories, e.g.
#   figure_level_labels <- list(condition = c(ctrl = "Control", tx = "Treatment"))
figure_level_labels <- list(
  framing = c(Gain = "Gain frame", Neutral = "Neutral frame")
)`;
const labels = { framing: 'Framing', 'Preference(continuous)': 'Preference "slider"', if: 'If' };
const levels = { framing: { Gain: 'Gain frame', Neutral: 'Neutral frame' } };

describe('figure label block', () => {
  it('is written exactly as the R converter writes it', () => {
    const block = labelBlock(labels, levels);
    expect(fromR).toContain(block.labels);
    expect(fromR).toContain(block.levels);
  });

  it('replaces the block in generated code and leaves the rest alone', () => {
    const code = `x <- 1\nfigure_labels <- c()\n# note\nfigure_level_labels <- list()\ny <- 2`;
    const out = replaceLabelBlock(code, labels, levels);
    expect(out).toContain('`Preference(continuous)` = "Preference \\"slider\\""');
    expect(out).toContain('framing = c(Gain = "Gain frame", Neutral = "Neutral frame")');
    expect(out?.startsWith('x <- 1\n')).toBe(true);
    expect(out?.endsWith('\ny <- 2')).toBe(true);
    // and back again, from a multi-line block
    expect(replaceLabelBlock(out ?? '', {}, {})).toBe(code);
    expect(replaceLabelBlock('no block here', labels, levels)).toBeNull();
  });

  it('keeps only changed labels when column names are kept', () => {
    expect(labelBlock({ age: 'age', sex: 'Sex' }, {}, true).labels).toBe('figure_labels <- c(\n  sex = "Sex"\n)');
  });

  it('writes names as R does', () => {
    expect(rSym('trust_score')).toBe('trust_score');
    expect(rSym('.hidden')).toBe('.hidden');
    expect(rSym('2x')).toBe('`2x`');
    expect(rSym('.2x')).toBe('`.2x`');
    expect(rSym('TRUE')).toBe('`TRUE`');
    expect(rSym('a b')).toBe('`a b`');
  });

  it('reads and writes category labels', () => {
    expect(parseCategories('Gain = Gain frame; Neutral=Neutral frame;')).toEqual({
      map: { Gain: 'Gain frame', Neutral: 'Neutral frame' } });
    expect(parseCategories('Gain frame').error).toMatch(/category = label/);
    expect(parseCategories('').map).toEqual({});
    expect(formatCategories({ Gain: 'Gain frame', Neutral: 'No' })).toBe('Gain = Gain frame; Neutral = No');
  });
});
