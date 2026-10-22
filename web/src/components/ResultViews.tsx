import { Icon } from './Icon';
import { convertedName } from '../lib/bundle';
import type { ConversionResult, Mode } from '../types';

export function EmptyOutput() {
  return <div className="empty-output">
    <div className="empty-chart"><span/><span/><span/><span/><i/></div>
    <h3>A figure you can keep working on.</h3>
    <p>Convert your analysis to inspect the generated code and its statistical notes. Then preview a ggplot2 figure on
      your own data or simulated data.</p>
    <span className="empty-label">ggplot2 + emmeans · BetterGG · publication PNG</span>
  </div>;
}

export function StatusNotice({ status }: { status: ConversionResult['status'] }) {
  if (status === 'complete') return null;
  return <div className="notice">{status === 'partial'
    ? 'Some analyses need attention. Review Notes before using the output.'
    : 'No complete conversion is available. Your source is preserved; review Notes.'}</div>;
}

interface CodeProps { mode: Mode; text: string; onCopy: () => void }

export function CodeView({ mode, text, onCopy }: CodeProps) {
  return <>
    <div className="code-tools">
      <span>{convertedName(mode)}</span>
      <button onClick={onCopy}><Icon name="copy"/>Copy</button>
    </div>
    <pre className="generated-code" tabIndex={0}><code>{text}</code></pre>
  </>;
}

export function NotesView({ result }: { result: ConversionResult }) {
  return <div className="notes">
    <h3>Conversion coverage</h3>
    <ul className="coverage">
      {result.analyses.map(item => <li key={item.id}>
        <span>{item.heading ?? item.function_name}
          <small>{item.id} · {item.function_name} · line {item.line}</small></span>
        <strong className={item.status === 'converted' ? 'converted' : 'unsupported'}>{item.status}</strong>
      </li>)}
    </ul>
    {result.manifest.packages.length > 0 && <>
      <h3>R packages the new figures need</h3>
      <p className="package-list">{result.manifest.packages.join(', ')}</p>
    </>}
    <h3>Statistical and conversion notes</h3>
    {result.diagnostics.length ? result.diagnostics.map((item, index) => <article key={index}
      className={`diagnostic ${item.severity}`}>
      <strong>{item.analysis_id ?? 'Document'} · {item.code.replaceAll('_', ' ')}</strong>
      <p>{item.message}</p>
    </article>) : <p>No conversion warnings were recorded. Review the generated code before use.</p>}
  </div>;
}

interface DownloadProps { mode: Mode; onSource: () => void; onBundle: () => void }

export function Downloads({ mode, onSource, onBundle }: DownloadProps) {
  return <div className="download-row">
    <button onClick={onSource}><Icon name="download"/>{mode === 'rmd' ? 'Download Rmd' : 'Download R code'}</button>
    <button className="secondary" onClick={onBundle}><Icon name="download"/>Reproducibility bundle</button>
  </div>;
}
