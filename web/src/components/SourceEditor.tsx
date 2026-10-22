import type { ChangeEvent } from 'react';
import { examples, type Example } from '../lib/examples';
import type { Mode } from '../types';

interface Props {
  mode: Mode;
  source: string;
  filename: string;
  busy: boolean;
  example?: Example;
  onMode: (mode: Mode) => void;
  onSource: (source: string) => void;
  onUpload: (event: ChangeEvent<HTMLInputElement>) => void;
  onExample: (example: Example) => void;
}

export function SourceEditor({ mode, source, filename, busy, example, onMode, onSource, onUpload, onExample }: Props) {
  return <>
    <div className="mode-switch" role="group" aria-label="Input mode">
      {(['code', 'rmd'] as Mode[]).map(value => <button disabled={busy} key={value} aria-pressed={mode === value}
        onClick={() => onMode(value)}>{value === 'code' ? 'Paste R code' : 'Convert an Rmd'}</button>)}
    </div>
    <div className="example-bar" role="group" aria-label="Examples">
      <span>Examples</span>
      {examples.map(item => <button key={item.id} disabled={busy} aria-pressed={example?.id === item.id}
        onClick={() => onExample(item)}>{item.label}</button>)}
    </div>
    {example?.bundledData && <p className="example-note">
      This example uses a bundled synthetic dataset (simulated values, not research results). Previews and the
      report preview use it without any upload.
    </p>}
    <div className="file-bar">
      <span>{mode === 'rmd' ? filename.replace(/\.R$/i, '.Rmd') : 'Analysis source'}</span>
      <label className="file-button">{mode === 'rmd' ? 'Choose .Rmd file' : 'Open .R file'}
        <input disabled={busy} type="file" accept={mode === 'rmd' ? '.Rmd,.rmd' : '.R,.r,.txt'} onChange={onUpload}/>
      </label>
    </div>
    <label className="sr-only" htmlFor="source">{mode === 'code' ? 'R analysis source' : 'R Markdown source'}</label>
    <textarea id="source" disabled={busy} className="source-editor" spellCheck={false} value={source}
      onChange={event => onSource(event.target.value)} placeholder="Choose an Rmd file, or paste its contents here…"/>
    <div className="input-foot">
      <span>{source.split('\n').length} lines · {new TextEncoder().encode(source).length.toLocaleString()} bytes</span>
      <span>Conversion does not run your source code</span>
    </div>
  </>;
}
