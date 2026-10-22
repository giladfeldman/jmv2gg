import type { ConversionSettings } from '../lib/requests';
import { sizeWidths } from '../lib/requests';
import type { Engine, FigureFormat, FigureSize, Palette } from '../types';

type Options = Omit<ConversionSettings, 'mode' | 'source'>;
interface Props {
  mode: ConversionSettings['mode'];
  options: Options;
  busy: boolean;
  onChange: (patch: Partial<Options>) => void;
}

const palettes: { value: Palette; label: string }[] = [
  { value: 'nejm', label: 'NEJM (default)' },
  { value: 'okabe_ito', label: 'Okabe-Ito (colour-blind safe)' },
  { value: 'grey', label: 'Greyscale' },
  { value: 'viridis', label: 'Viridis' },
];
const sizes: { value: FigureSize; label: string }[] = [
  { value: 'double', label: '2-column, 7.2 in wide (default)' },
  { value: 'single', label: '1-column, 3.5 in wide' },
  { value: 'custom', label: 'Custom width and height' },
];
const formats: { value: FigureFormat; label: string }[] = [
  { value: 'png', label: 'PNG (always)' },
  { value: 'pdf', label: 'PDF (vector, fonts embedded)' },
  { value: 'tiff', label: 'TIFF (LZW compressed)' },
];
const engineLabel = (value: Engine) => value === 'both' ? 'Both' : value === 'bettergg' ? 'BetterGG' : 'ggplot2';

export function OptionsPanel({ mode, options, busy, onChange }: Props) {
  const setSize = (size: FigureSize) => onChange(size === 'custom' ? { size }
    : { size, height: Math.round(sizeWidths[size] * 75) / 100 });
  const toggleFormat = (format: FigureFormat, on: boolean) => onChange({
    formats: on ? [...options.formats, format] : options.formats.filter(item => item !== format),
  });
  return <div className="settings">
    <fieldset>
      <legend>Figures to generate</legend>
      <div className="engine-options">
        {(['ggplot2', 'bettergg', 'both'] as Engine[]).map(value => <label key={value}>
          <input disabled={busy} type="radio" name="engine" checked={options.engine === value}
            onChange={() => onChange({ engine: value })}/>
          <span>{engineLabel(value)}</span>
        </label>)}
      </div>
      <p className="help">BetterGG calls ggstatsplot with APA formatting. BetterGG figures are not previewed one by one
        here; they are drawn when the report is rendered (browser preview or local R).</p>
    </fieldset>
    {mode === 'rmd' && <div className="two-fields">
      <label>Existing jamovi tables and figures
        <select disabled={busy} value={options.original}
          onChange={event => onChange({ original: event.target.value as Options['original'] })}>
          <option value="include">Keep alongside new plots</option>
          <option value="hide">Show new plots only</option>
        </select>
        <small>Calculations are retained so later report code keeps working.</small>
      </label>
      <label>HTML presentation
        <select disabled={busy} value={options.html}
          onChange={event => onChange({ html: event.target.value as Options['html'] })}>
          <option value="enhanced">Floating navigation + folded code</option>
          <option value="preserve">Keep my HTML settings</option>
        </select>
        <small>Download and knit the complete report in local R.</small>
      </label>
    </div>}
    <div className="toggle-row">
      <label className="toggle">
        <input disabled={busy} type="checkbox" checked={options.stats}
          onChange={event => onChange({ stats: event.target.checked })}/>
        <span><strong>Statistics on figures</strong>
          <small>Off by default, which keeps figures clean. When on, the tests shown on the new plots are recomputed in
            R and match jamovi's tables.</small></span>
      </label>
      {mode === 'rmd' && <label className="toggle">
        <input disabled={busy} type="checkbox" checked={options.headings}
          onChange={event => onChange({ headings: event.target.checked })}/>
        <span><strong>Insert a heading before each figure chunk</strong>
          <small>R Markdown only. Adds a heading so each new figure appears in the table of contents.</small></span>
      </label>}
    </div>
    <details>
      <summary>Style and publication export</summary>
      <div className="option-grid">
        <label>Colour palette
          <select disabled={busy} value={options.palette}
            onChange={event => onChange({ palette: event.target.value as Palette })}>
            {palettes.map(item => <option key={item.value} value={item.value}>{item.label}</option>)}
          </select>
        </label>
        <label>Figure size
          <select disabled={busy} value={options.size} onChange={event => setSize(event.target.value as FigureSize)}>
            {sizes.map(item => <option key={item.value} value={item.value}>{item.label}</option>)}
          </select>
        </label>
        <label>PNG resolution
          <select disabled={busy} value={options.dpi} onChange={event => onChange({ dpi: Number(event.target.value) })}>
            <option value="300">300 dpi</option>
            <option value="600">600 dpi</option>
          </select>
        </label>
        {options.size === 'custom' && <label>Width (in)
          <input disabled={busy} type="number" min="1" max="30" step="0.1" value={options.width}
            onChange={event => onChange({ width: Number(event.target.value) })}/>
        </label>}
        <label>Height (in)
          <input disabled={busy} type="number" min="1" max="30" step="0.1" value={options.height}
            onChange={event => onChange({ height: Number(event.target.value) })}/>
        </label>
        <label className="inline-check">
          <input disabled={busy} type="checkbox" checked={options.verbose}
            onChange={event => onChange({ verbose: event.target.checked })}/> Explanatory comments
        </label>
      </div>
      <fieldset className="formats">
        <legend>File formats saved by the downloaded code</legend>
        <div className="format-options">
          {formats.map(item => <label key={item.value} className="inline-check">
            <input disabled={busy || item.value === 'png'} type="checkbox"
              checked={item.value === 'png' || options.formats.includes(item.value)}
              onChange={event => toggleFormat(item.value, event.target.checked)}/> {item.label}
          </label>)}
        </div>
      </fieldset>
      <p className="help">White background. Every generated plot is followed by a save step into figures/. These
        formats apply when you run the downloaded code in R; previews in this browser are always PNG.</p>
    </details>
  </div>;
}
