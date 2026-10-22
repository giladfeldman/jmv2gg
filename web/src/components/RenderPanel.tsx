import { Icon } from './Icon';
import { ReportFrame } from './ReportFrame';
import { checkDataFiles } from '../lib/files';
import { isConfirmed, canStart, type RenderState } from '../lib/renderState';

const nativeCommand = 'jmv2gg::render_report("converted.Rmd")';

interface Props {
  state: RenderState;
  scanning: boolean;
  busy: boolean;
  dataFiles: File[];
  bundledAvailable: boolean;
  useBundled: boolean;
  onScan: () => void;
  onConfirm: (value: boolean) => void;
  onDataFiles: (files: File[]) => void;
  onUseBundled: (value: boolean) => void;
  onRender: () => void;
  onCancel: () => void;
  onDownload: () => void;
}

export function RenderPanel(props: Props) {
  const { state } = props;
  const files = props.useBundled ? [] : props.dataFiles;
  const check = checkDataFiles(files);
  return <div className="render-area">
    <div className="preview-notice">A browser preview of the converted report, rendered with knitr and markdown in a
      separate R session on this device. The reference report is rendered in native R. Nothing is uploaded.</div>
    {state.phase === 'idle' && <>
      <p>Before anything runs, jmv2gg checks the converted document for code that should be reviewed (for example
        file downloads, system commands, or chunks in other languages).</p>
      <button className="secondary" disabled={props.busy || props.scanning} onClick={props.onScan}>
        {props.scanning ? 'Checking…' : 'Check report before rendering'}</button>
    </>}
    {state.phase !== 'idle' && <ScanSummary {...props}/>}
    {state.phase !== 'idle' && !state.scan.refused && <>
      <fieldset className="render-data">
        <legend>Data files the report reads</legend>
        {props.bundledAvailable && <label className="inline-check">
          <input type="checkbox" disabled={state.phase === 'rendering'} checked={props.useBundled}
            onChange={event => props.onUseBundled(event.target.checked)}/> Use the bundled synthetic dataset
          (replication-study.csv, simulated values)
        </label>}
        {!props.useBundled && <label className="data-upload">Choose one or more data files
          <input type="file" multiple disabled={state.phase === 'rendering'}
            onChange={event => props.onDataFiles([...(event.target.files ?? [])])}/>
        </label>}
        {!props.useBundled && <p className="help">Each file up to 100 MB, 300 MB together. Files are placed next to the
          report under names made of letters, digits, dots, dashes and underscores (other characters become _);
          make sure these match the names the document reads.</p>}
        {check.ok && check.names.length > 0 && <ul className="file-list">
          {check.names.map(name => <li key={name}>{name}</li>)}</ul>}
        {!check.ok && <div className="error-inline" role="alert">{check.error}</div>}
      </fieldset>
      <div className="render-actions">
        {state.phase === 'rendering'
          ? <button onClick={props.onCancel}>Cancel rendering</button>
          : <button className="primary" disabled={!canStart(state) || !check.ok || props.busy} onClick={props.onRender}>
            Render report (browser preview)</button>}
        {state.phase === 'rendering' && <span className="help">Progress is shown above.</span>}
      </div>
      <p className="help">Rendering installs R packages in your browser and can take several minutes. It stops after
        15 minutes; Cancel stops it at once.</p>
    </>}
    {state.phase === 'failed' && <div className="error-banner" role="alert">
      <strong>The report could not be rendered.</strong>
      <pre className="error-text">{state.error}</pre></div>}
    {state.phase === 'cancelled' && <div className="notice" role="status">{state.reason}</div>}
    {state.phase === 'done' && <div className="report-result">
      <p className="report-label">Browser preview, rendered with knitr + markdown. The reference report is rendered in
        native R.</p>
      <ReportFrame html={state.html}/>
      <div className="html-download">
        <p className="warning">Opening the downloaded HTML file outside jmv2gg removes the browser protections used
          here (the script-free frame and the page's content rules). Open it only if you trust the document.</p>
        <button onClick={props.onDownload}><Icon name="download"/>Download HTML</button>
      </div>
    </div>}
  </div>;
}

function ScanSummary({ state, onConfirm, onScan, busy, scanning }: Props) {
  if (state.phase === 'idle') return null;
  const { scan } = state;
  if (scan.refused) return <div className="scan refused">
    <h3>This report is not rendered in the browser</h3>
    <ul>{scan.findings.filter(item => item.refuse).map(item => <li key={item.code + item.lines.join()}>
      {item.message} <small>Lines {item.lines.join(', ')}</small></li>)}</ul>
    <p>Render it in native R instead, after installing jmv2gg, with:</p>
    <pre className="command"><code>{nativeCommand}</code></pre>
  </div>;
  return <div className="scan">
    <h3>Review before rendering</h3>
    <p className="help">The check read {scan.chunks} code chunks and {scan.inline_expressions} inline R expressions.
      Line numbers refer to the converted report.</p>
    {scan.findings.length
      ? <ul>{scan.findings.map(item => <li key={item.code + item.lines.join()}>{item.message}
        <small>Lines {item.lines.join(', ')}</small></li>)}</ul>
      : <p>The check found nothing that needs special review.</p>}
    <label className="inline-check confirm">
      <input type="checkbox" checked={isConfirmed(state)} disabled={state.phase === 'rendering'}
        onChange={event => onConfirm(event.target.checked)}/>
      {scan.findings.length ? ' I have reviewed the items above and want to run this report\'s R code in my browser.'
        : ' I want to run this report\'s R code in my browser.'}
    </label>
    <button className="text-button" disabled={busy || scanning || state.phase === 'rendering'} onClick={onScan}>
      Check again</button>
  </div>;
}
