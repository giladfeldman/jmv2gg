import { useEffect, useRef, useState, type ChangeEvent } from 'react';
import JSZip from 'jszip';
import { RWorkbench } from './runtime';
import type { ConversionRequest, ConversionResult, Engine, Mode, PreviewFile } from './types';

const example = `# Paste the R code copied from jamovi here.\n# Preview on your local dataset or explicitly simulated data.\njmv::ANOVA(\n  data = my_data,\n  dep = "score",\n  factors = c("condition"),\n  modelTerms = list("condition"),\n  emMeans = list("condition"),\n  emmWeights = TRUE\n)`;
const renderInstructions = `# Run in native R after installing jmv2gg and the plotting packages.\n# Retain the data files referenced by your document.\njmv2gg::render_report("converted.Rmd", output_dir = "report")\n`;
function download(blob: Blob, name: string) {
  const url = URL.createObjectURL(blob); const link = document.createElement('a');
  link.href = url; link.download = name; document.body.append(link); link.click(); link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
function Icon({ name }: { name: 'download' | 'arrow' | 'shield' | 'copy' | 'chart' }) {
  const paths = { download: 'M12 3v12m-5-5 5 5 5-5M5 16v4h14v-4', arrow: 'M4 12h16m-6-6 6 6-6 6', shield: 'M12 3 4 6v6c0 5 8 9 8 9s8-4 8-9V6l-8-3Zm-4 9 3 3 5-6', copy: 'M9 8h11v13H9zM4 16V3h11', chart: 'M4 3v17h17M7 15l4-6 4 3 5-7' };
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden="true"><path d={paths[name]} strokeLinejoin="round" strokeLinecap="round"/></svg>;
}
export function App() {
  const [mode, setMode] = useState<Mode>('code'); const [source, setSource] = useState(example);
  const [filename, setFilename] = useState('analysis.R'); const [engine, setEngine] = useState<Engine>('both');
  const [original, setOriginal] = useState<'include' | 'hide'>('include'); const [html, setHtml] = useState<'enhanced' | 'preserve'>('enhanced');
  const [violin, setViolin] = useState(true); const [points, setPoints] = useState(true); const [grayscale, setGrayscale] = useState(false); const [verbose, setVerbose] = useState(true);
  const [jitter, setJitter] = useState(.15); const [jitterHeight, setJitterHeight] = useState(0); const [dpi, setDpi] = useState(600); const [width, setWidth] = useState(7.2); const [height, setHeight] = useState(5.4);
  const [result, setResult] = useState<ConversionResult>(); const [snapshot, setSnapshot] = useState<ConversionRequest>();
  const [busy, setBusy] = useState(false); const [stage, setStage] = useState('Ready when you are'); const [error, setError] = useState(''); const [notice, setNotice] = useState('');
  const [view, setView] = useState<'code' | 'figures' | 'notes'>('code'); const [analysis, setAnalysis] = useState('');
  const [dataFile, setDataFile] = useState<File>(); const [dataKind, setDataKind] = useState<'simulate' | 'file'>('simulate'); const [simulationN, setSimulationN] = useState(100); const [categorical, setCategorical] = useState('');
  const [previews, setPreviews] = useState<PreviewFile[]>([]); const worker = useRef<RWorkbench | null>(null); const job = useRef(0);
  const [workspaceKey, setWorkspaceKey] = useState(0);
  useEffect(() => () => { worker.current?.close(); }, []);
  useEffect(() => () => { previews.forEach(file => URL.revokeObjectURL(file.url)); }, [previews]);
  const invalidate = () => { setResult(undefined); setSnapshot(undefined); setPreviews([]); setError(''); setNotice(''); };
  const runtime = () => { worker.current ??= new RWorkbench(setStage); return worker.current; };
  const request = (): ConversionRequest => ({ action: 'convert', mode, source, engine, original_output: original, html_preset: html,
    style: { show_violin: violin, show_jitter: points, grayscale, jitter_width: jitter, jitter_height: jitterHeight, verbose }, figures: { dpi, width, height } });
  async function convert() {
    setBusy(true); setError(''); setNotice(''); setPreviews([]); const current = ++job.current;
    try { const input = request(); const output = await runtime().convert(input); if (current !== job.current) return;
      setResult(output); setSnapshot(input); setView('code'); setAnalysis(output.analyses.find(item => item.status === 'converted')?.id ?? '');
      setStage(output.status === 'failed' ? 'Review the conversion notes' : 'Conversion ready');
    } catch (e) { if (current === job.current) { setError(e instanceof Error ? e.message : 'The R worker failed. Clear the workspace and try again.'); setStage('Conversion interrupted'); } }
    finally { if (current === job.current) setBusy(false); }
  }
  function reset() { ++job.current; worker.current?.close(); worker.current = null; setBusy(false); setDataFile(undefined); setPreviews([]); setError(''); setNotice(''); setResult(undefined); setSnapshot(undefined); setSource(''); setFilename('analysis.R'); setCategorical(''); setWorkspaceKey(x => x + 1); setStage('Workspace cleared'); }
  async function upload(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]; if (!file) return;
    if (file.size > 5 * 1024 * 1024) { setError('Use a source file smaller than 5 MB, or convert it in local R.'); return; }
    invalidate(); setSource(await file.text()); setFilename(file.name);
  }
  async function preview() {
    if (!snapshot || !analysis) return;
    if (dataKind === 'file' && !dataFile) { setError('Select a local CSV or SAV dataset first.'); return; }
    setBusy(true); setError(''); setPreviews([]); const current = ++job.current;
    try { const files = await runtime().preview({ ...snapshot, action: 'preview', analysis_id: analysis, data_kind: dataKind, n: simulationN, categorical: categorical.split(',').map(x => x.trim()).filter(Boolean) }, dataKind === 'file' ? dataFile : undefined);
      if (current !== job.current) { files.forEach(file => URL.revokeObjectURL(file.url)); return; } setPreviews(files); setStage('Figures ready to download');
    } catch (e) { if (current === job.current) setError(e instanceof Error ? e.message : 'The preview failed. Your converted code is still available.'); }
    finally { if (current === job.current) setBusy(false); }
  }
  async function bundle() {
    if (!result || !snapshot) return;
    try { const zip = new JSZip(); zip.file(snapshot.mode === 'rmd' ? 'converted.Rmd' : 'converted.R', result.text);
      zip.file('conversion.json', JSON.stringify({ analyses: result.analyses, diagnostics: result.diagnostics, manifest: result.manifest }, null, 2));
      const environment = await fetch('/locks/packages.json');
      const build = await fetch('/r-packages/build-manifest.json');
      if (!environment.ok || !build.ok) throw new Error('Runtime provenance could not be loaded.');
      zip.file('browser-environment.json', JSON.stringify({ dependencies: await environment.json(), converter: await build.json() }, null, 2));
      if (snapshot.mode === 'rmd') zip.file('render.R', renderInstructions);
      zip.file('README.txt', 'jmv2gg reproducibility bundle\n\nInput data is not included. Retain the data files referenced by your source.\nComplete HTML knitting and BetterGG execution require native R.\nInspect conversion.json for limitations and additional tests.\n');
      for (const file of previews.filter(x => !x.simulated)) zip.file(file.path, file.bytes);
      download(await zip.generateAsync({ type: 'blob', compression: 'DEFLATE' }), 'jmv2gg-bundle.zip');
    } catch { setError('The bundle could not be prepared. Download the source and figures separately.'); }
  }
  const ready = result && snapshot;
  return <><header className="site-header"><a className="brand" href="#main"><span className="brand-mark"><Icon name="chart"/></span>jmv<span>2</span>gg</a><nav aria-label="Project links"><a href="https://github.com/giladfeldman/jmv2gg" target="_blank" rel="noreferrer">R package ↗</a><a href="#how-it-works">How it works</a><button className="text-button" onClick={reset}>Clear workspace</button></nav></header>
    <main id="main" key={workspaceKey}><section className="intro"><div><p className="intro-label">Editable figures. Reproducible research.</p><h1>Make the figure yours.</h1><p className="lead">Turn jamovi analysis code into ggplot2 and BetterGG figures you can edit, share, and reproduce.</p></div><div className="privacy"><Icon name="shield"/><p><strong>Your work stays on your device.</strong><span>Code and data are processed locally in your browser. No account needed.</span></p></div></section>
      <div className="workbench"><section className="input-panel panel" aria-labelledby="input-title"><div className="panel-heading"><div><h2 id="input-title">Your analysis</h2><p>Start with code copied from jamovi or an existing Rmd.</p></div><span className="language-label">R</span></div>
        <div className="mode-switch" role="group" aria-label="Input mode">{(['code', 'rmd'] as Mode[]).map(value => <button disabled={busy} key={value} aria-pressed={mode === value} onClick={() => { invalidate(); setMode(value); setSource(value === 'code' ? example : ''); }}>{value === 'code' ? 'Paste R code' : 'Convert an Rmd'}</button>)}</div>
        <div className="file-bar"><span>{mode === 'rmd' ? filename.replace(/\.R$/i, '.Rmd') : 'Analysis source'}</span><label className="file-button">{mode === 'rmd' ? 'Choose .Rmd file' : 'Open .R file'}<input disabled={busy} type="file" accept={mode === 'rmd' ? '.Rmd,.rmd' : '.R,.r,.txt'} onChange={upload}/></label></div>
        <label className="sr-only" htmlFor="source">{mode === 'code' ? 'R analysis source' : 'R Markdown source'}</label><textarea id="source" disabled={busy} className="source-editor" spellCheck={false} value={source} onChange={e => { invalidate(); setSource(e.target.value); }} placeholder="Choose an Rmd file, or paste its contents here…"/>
        <div className="input-foot"><span>{source.split('\n').length} lines · {new TextEncoder().encode(source).length.toLocaleString()} bytes</span><span>Conversion does not run your source code</span></div>
        <div className="settings"><fieldset><legend>Figures to generate</legend><div className="engine-options">{(['ggplot2', 'bettergg', 'both'] as Engine[]).map(value => <label key={value}><input disabled={busy} type="radio" name="engine" checked={engine === value} onChange={() => { invalidate(); setEngine(value); }}/><span>{value === 'both' ? 'Both' : value === 'bettergg' ? 'BetterGG' : 'ggplot2'}</span></label>)}</div><p className="help">BetterGG calls ggstatsplot with APA formatting. Its previews and complete reports run in local R.</p></fieldset>
          {mode === 'rmd' && <div className="two-fields"><label>Existing jamovi tables and figures<select disabled={busy} value={original} onChange={e => { invalidate(); setOriginal(e.target.value as typeof original); }}><option value="include">Keep alongside new plots</option><option value="hide">Show new plots only</option></select><small>Calculations are retained so later report code keeps working.</small></label><label>HTML presentation<select disabled={busy} value={html} onChange={e => { invalidate(); setHtml(e.target.value as typeof html); }}><option value="enhanced">Floating navigation + folded code</option><option value="preserve">Keep my HTML settings</option></select><small>Download and knit the complete report in local R.</small></label></div>}
          <details><summary>Style and publication export</summary><div className="option-grid"><label><input disabled={busy} type="checkbox" checked={violin} onChange={e => { invalidate(); setViolin(e.target.checked); }}/> Show distributions</label><label><input disabled={busy} type="checkbox" checked={points} onChange={e => { invalidate(); setPoints(e.target.checked); }}/> Show data points</label><label><input disabled={busy} type="checkbox" checked={grayscale} onChange={e => { invalidate(); setGrayscale(e.target.checked); }}/> Grayscale</label><label><input disabled={busy} type="checkbox" checked={verbose} onChange={e => { invalidate(); setVerbose(e.target.checked); }}/> Explanatory comments</label><label>Jitter width<input disabled={busy} type="number" min="0" max="1" step="0.05" value={jitter} onChange={e => { invalidate(); setJitter(Number(e.target.value)); }}/></label><label>Jitter height<input disabled={busy} type="number" min="0" max="1" step="0.05" value={jitterHeight} onChange={e => { invalidate(); setJitterHeight(Number(e.target.value)); }}/></label><label>Width (in)<input disabled={busy} type="number" min="1" max="30" step="0.1" value={width} onChange={e => { invalidate(); setWidth(Number(e.target.value)); }}/></label><label>Height (in)<input disabled={busy} type="number" min="1" max="30" step="0.1" value={height} onChange={e => { invalidate(); setHeight(Number(e.target.value)); }}/></label><label>PNG resolution<select disabled={busy} value={dpi} onChange={e => { invalidate(); setDpi(Number(e.target.value)); }}><option value="300">300 dpi</option><option value="600">600 dpi</option></select></label></div><p className="help">White-background, lossless PNG. Every generated plot is followed by ggsave() into figures/.</p></details>
        </div><div className="convert-row"><span className={`runtime-state ${busy ? 'working' : ''}`} role="status">{stage}</span>{busy ? <button onClick={reset}>Cancel and reset</button> : <button className="primary" disabled={!source.trim()} onClick={convert}>Convert analysis <Icon name="arrow"/></button>}</div>
      </section><section className="output-panel panel" aria-labelledby="output-title"><div className="panel-heading"><div><h2 id="output-title">Your editable output</h2><p>{ready ? `${result.manifest.converted} of ${result.manifest.detected} analyses converted · ${result.manifest.plots.length} requested figures` : 'Readable R code, with the details kept intact.'}</p></div><Icon name="chart"/></div>
        <div className="output-tabs" role="group" aria-label="Output view">{(['code', 'figures', 'notes'] as const).map(value => <button key={value} aria-pressed={view === value} onClick={() => setView(value)}>{value === 'code' ? 'Generated code' : value === 'figures' ? 'Preview figures' : `Notes${result?.diagnostics.length ? ` (${result.diagnostics.length})` : ''}`}</button>)}</div>
        {error && <div className="error-banner" role="alert">{error}</div>}{notice && <div className="notice" role="status">{notice}</div>}
        {!ready ? <div className="empty-output"><div className="empty-chart"><span/><span/><span/><span/><i/></div><h3>A figure you can keep working on.</h3><p>Convert your analysis to inspect the generated code and its statistical notes. Then preview a ggplot2 figure on your own data or simulated data.</p><span className="empty-label">ggplot2 + emmeans · BetterGG · publication PNG</span></div> : <>
          {result.status !== 'complete' && <div className="notice">{result.status === 'partial' ? 'Some analyses need attention. Review Notes before using the output.' : 'No complete conversion is available. Your source is preserved; review Notes.'}</div>}
          {view === 'code' && <><div className="code-tools"><span>{snapshot.mode === 'rmd' ? 'converted.Rmd' : 'converted.R'}</span><button onClick={async () => { try { await navigator.clipboard.writeText(result.text); setNotice('Code copied.'); } catch { setError('Clipboard access failed. Download the code instead.'); } }}><Icon name="copy"/>Copy</button></div><pre className="generated-code" tabIndex={0}><code>{result.text}</code></pre></>}
          {view === 'notes' && <div className="notes"><h3>Conversion coverage</h3><ul className="coverage">{result.analyses.map(item => <li key={item.id}><span>{item.heading ?? item.function_name}<small>{item.id} · {item.function_name} · line {item.line}</small></span><strong className={item.status === 'converted' ? 'converted' : 'unsupported'}>{item.status}</strong></li>)}</ul><h3>Statistical and conversion notes</h3>{result.diagnostics.length ? result.diagnostics.map((item, i) => <article key={i} className={`diagnostic ${item.severity}`}><strong>{item.analysis_id ?? 'Document'} · {item.code.replaceAll('_', ' ')}</strong><p>{item.message}</p></article>) : <p>No conversion warnings were recorded. Review the generated code before use.</p>}</div>}
          {view === 'figures' && <div className="preview-area"><div className="preview-notice">ggplot2 previews run here. BetterGG figures and complete HTML reports run in local R.</div><label>Analysis<select disabled={busy} value={analysis} onChange={e => { setAnalysis(e.target.value); setPreviews([]); }}>{result.analyses.filter(item => item.status === 'converted').map(item => <option key={item.id} value={item.id}>{item.id} · {item.heading ?? item.function_name}</option>)}</select></label><div className="data-choice"><label><input disabled={busy} type="radio" name="data" checked={dataKind === 'simulate'} onChange={() => { setDataKind('simulate'); setPreviews([]); }}/> Simulated data</label><label><input disabled={busy} type="radio" name="data" checked={dataKind === 'file'} onChange={() => { setDataKind('file'); setPreviews([]); }}/> My local dataset</label></div>{dataKind === 'simulate' ? <label>Simulated participants<input disabled={busy} type="number" min="10" max="5000" value={simulationN} onChange={e => setSimulationN(Number(e.target.value))}/></label> : <><label className="data-upload">Choose a CSV or SAV file<input disabled={busy} type="file" accept=".csv,.sav" onChange={e => { setDataFile(e.target.files?.[0]); setPreviews([]); }}/></label><p className="help">Select prepared analysis data. Rmd setup and case-weight attributes are not reconstructed here; use native R for weighted analyses.</p><label>Categorical column overrides<small>Comma-separated names; optional</small><input disabled={busy} value={categorical} onChange={e => setCategorical(e.target.value)} placeholder="condition, group"/></label></>}
            <button className="secondary" disabled={busy || !analysis} onClick={preview}><Icon name="chart"/>Preview ggplot2</button>{previews.map(file => <figure key={file.path}>{file.simulated && <div className="simulation-label">SIMULATED DATA — not research results</div>}<img src={file.url} alt={`${file.simulated ? 'Simulated' : 'Local data'} preview for ${analysis}`}/><figcaption>{file.path}<button onClick={() => download(new Blob([new Uint8Array(file.bytes)], { type: 'image/png' }), `${file.simulated ? 'simulated-' : ''}${file.path.split('/').at(-1)}`)}><Icon name="download"/>PNG</button></figcaption></figure>)}
          </div>}
          <div className="download-row"><button onClick={() => download(new Blob([result.text], { type: 'text/plain;charset=utf-8' }), snapshot.mode === 'rmd' ? 'converted.Rmd' : 'converted.R')}><Icon name="download"/>{snapshot.mode === 'rmd' ? 'Download Rmd' : 'Download R code'}</button><button className="secondary" onClick={bundle}><Icon name="download"/>Reproducibility bundle</button></div>
        </>}
      </section></div>
      <section className="explainer" id="how-it-works"><h2>Built for the next person who opens your analysis.</h2><div><article><h3>Explicit, editable code</h3><p>Keep the data preparation, model, and figure in R. Adjust the generated code as your research develops.</p></article><article><h3>Statistical differences made visible</h3><p>When a BetterGG plot introduces a different test, the notes explain it. Your existing analyses remain available.</p></article><article><h3>A report that travels</h3><p>Download an Rmd with floating navigation, folded code, and publication exports. Knit it with your data in local R.</p></article></div></section>
    </main><footer><span>jmv2gg · version 0.1.0</span><span>WebR 0.6.0 · R runs locally · no research data uploads</span></footer></>;
}
