/**
 * Figure labels in the generated code: one `figure_labels` vector and one `figure_level_labels` list
 * in the figure setup (R/labels.R writes them). The Labels view edits them in place, so a change
 * needs no new conversion; previews get the same labels through the request's style options.
 */
export type LabelText = Record<string, string>;
export type LevelText = Record<string, Record<string, string>>;

const reserved = new Set(['if', 'else', 'repeat', 'while', 'function', 'for', 'next', 'break', 'TRUE', 'FALSE',
  'NULL', 'Inf', 'NaN', 'NA', 'NA_integer_', 'NA_real_', 'NA_character_', 'NA_complex_', 'in']);

/** A name as R code: bare when syntactic (as R's make.names() keeps it), backticked otherwise. */
export function rSym(name: string) {
  const syntactic = /^([A-Za-z]|[.](?![0-9]))[A-Za-z0-9._]*$|^[.]$/.test(name) && !reserved.has(name);
  return syntactic ? name : '`' + name.replace(/\\/g, '\\\\').replace(/`/g, '\\`') + '`';
}

/** An R string literal; JSON escapes (\" \\ \n \uXXXX) are valid R escapes. */
export function rString(text: string) {
  return JSON.stringify(text);
}

const namedText = (values: Record<string, string>) =>
  Object.entries(values).map(([name, text]) => `${rSym(name)} = ${rString(text)}`);

/** The two assignments, written exactly as R/labels.R writes them. */
export function labelBlock(labels: LabelText, levels: LevelText, keepNames = false) {
  const shown = Object.fromEntries(Object.entries(labels).filter(([name, text]) => !keepNames || text !== name));
  const lines = namedText(shown);
  const first = lines.length
    ? ['figure_labels <- c(', ...lines.map((line, i) => `  ${line}${i < lines.length - 1 ? ',' : ''}`), ')']
    : ['figure_labels <- c()'];
  const columns = Object.entries(levels).filter(([, map]) => Object.keys(map).length);
  const second = columns.length
    ? ['figure_level_labels <- list(', ...columns.map(([name, map], i) =>
      `  ${rSym(name)} = c(${namedText(map).join(', ')})${i < columns.length - 1 ? ',' : ''}`), ')']
    : ['figure_level_labels <- list()'];
  return { labels: first.join('\n'), levels: second.join('\n') };
}

const labelsPattern = /^figure_labels <- c\((?:\)|\n[\s\S]*?\n\))$/m;
const levelsPattern = /^figure_level_labels <- list\((?:\)|\n[\s\S]*?\n\))$/m;

/** The generated code with its label block replaced; null when the block is not found. */
export function replaceLabelBlock(text: string, labels: LabelText, levels: LevelText, keepNames = false) {
  if (!labelsPattern.test(text) || !levelsPattern.test(text)) return null;
  const block = labelBlock(labels, levels, keepNames);
  return text.replace(labelsPattern, () => block.labels).replace(levelsPattern, () => block.levels);
}

/** "ctrl = Control; tx = Treatment" -> { ctrl: 'Control', tx: 'Treatment' }. */
export function parseCategories(text: string): { map: Record<string, string>; error?: string } {
  const map: Record<string, string> = {};
  for (const part of text.split(';').map(item => item.trim()).filter(Boolean)) {
    const at = part.indexOf('=');
    if (at <= 0) return { map, error: `"${part}" needs the form category = label` };
    const category = part.slice(0, at).trim();
    const label = part.slice(at + 1).trim();
    if (!category || !label) return { map, error: `"${part}" needs the form category = label` };
    map[category] = label;
  }
  return { map };
}

export function formatCategories(map: Record<string, string> | undefined) {
  return Object.entries(map ?? {}).map(([category, label]) => `${category} = ${label}`).join('; ');
}
