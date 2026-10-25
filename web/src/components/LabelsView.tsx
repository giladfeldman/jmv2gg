import { useState } from 'react';
import { formatCategories, parseCategories, type LabelText, type LevelText } from '../lib/labels';

interface Props {
  /** Each figure column and its label in the generated code. */
  labels: LabelText;
  levels: LevelText;
  busy: boolean;
  onApply: (labels: LabelText, levels: LevelText) => void;
}

/** Edit the figure labels of the converted code: one row per column the figures use. */
export function LabelsView({ labels, levels, busy, onApply }: Props) {
  const columns = Object.keys(labels);
  const [text, setText] = useState<LabelText>(labels);
  const [categories, setCategories] = useState<Record<string, string>>(
    Object.fromEntries(columns.map(column => [column, formatCategories(levels[column])])));
  const [error, setError] = useState('');

  function apply() {
    const parsed: LevelText = {};
    for (const column of columns) {
      const result = parseCategories(categories[column] ?? '');
      if (result.error) { setError(`${column}: ${result.error}.`); return; }
      if (Object.keys(result.map).length) parsed[column] = result.map;
    }
    const cleaned = Object.fromEntries(columns.map(column => [column, (text[column] ?? '').trim() || column]));
    setError('');
    onApply(cleaned, parsed);
  }

  if (!columns.length) return <p className="help">The converted figures use no data columns to label.</p>;
  return <div className="labels-view">
    <p className="help">The text readers see instead of the column names: axis titles, legend titles, statistics lines
      and, under Categories, the names of a column's categories (write <code>code = label</code>, separated by
      semicolons, e.g. <code>ctrl = Control; tx = Treatment</code>). Applying rewrites the label block at
      the top of the generated code and is used by the figure previews; nothing is converted again.</p>
    <table className="labels-table">
      <thead><tr><th scope="col">Column</th><th scope="col">Label</th><th scope="col">Categories (optional)</th></tr></thead>
      <tbody>
        {columns.map(column => <tr key={column}>
          <th scope="row"><code>{column}</code></th>
          <td><input disabled={busy} aria-label={`Label for ${column}`} value={text[column] ?? ''}
            onChange={event => setText(current => ({ ...current, [column]: event.target.value }))}/></td>
          <td><input disabled={busy} aria-label={`Category labels for ${column}`} value={categories[column] ?? ''}
            placeholder="code = label; code = label"
            onChange={event => setCategories(current => ({ ...current, [column]: event.target.value }))}/></td>
        </tr>)}
      </tbody>
    </table>
    {error && <div className="error-banner" role="alert">{error}</div>}
    <div className="convert-row">
      <button className="primary" disabled={busy} onClick={apply}>Apply labels to the code</button>
    </div>
  </div>;
}
