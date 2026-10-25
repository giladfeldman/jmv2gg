import { useEffect, useReducer, useRef, useState, type ChangeEvent } from 'react';
import { RWorkbench, convertPhases, previewPhases, scanPhases } from './runtime';
import { ReportRenderer, renderPhases, suggestedRenderLimit } from './reportRuntime';
import { ProgressPanel } from './components/ProgressPanel';
import { ProgressTracker, type PhaseSpec, type ProgressSnapshot } from './lib/progress';
import { Icon } from './components/Icon';
import { Explainer, Footer, Intro, SiteHeader } from './components/Layout';
import { SourceEditor } from './components/SourceEditor';
import { OptionsPanel } from './components/OptionsPanel';
import { CodeView, Downloads, EmptyOutput, NotesView, StatusNotice } from './components/ResultViews';
import { FiguresView, type DataKind } from './components/FiguresView';
import { RenderPanel } from './components/RenderPanel';
import { LabelsView } from './components/LabelsView';
import { replaceLabelBlock, type LabelText, type LevelText } from './lib/labels';
import { buildConversionRequest, defaultSettings, previewPackages, type ConversionSettings } from './lib/requests';
import { buildBundle, convertedName } from './lib/bundle';
import { checkDataFiles, download, limits } from './lib/files';
import { examples, loadBundledDataset, loadExample, starterCode, type Example } from './lib/examples';
import { confirmedCodes, idle, renderReducer } from './lib/renderState';
import type { ConversionRequest, ConversionResult, Mode, PreviewFile } from './types';

type Options = Omit<ConversionSettings, 'mode' | 'source'>;
type View = 'code' | 'labels' | 'figures' | 'notes' | 'report';

const message = (error: unknown, fallback: string) => error instanceof Error ? error.message : fallback;

export function App() {
  const [mode, setMode] = useState<Mode>('code');
  const [source, setSource] = useState(starterCode);
  const [filename, setFilename] = useState('analysis.R');
  const [example, setExample] = useState<Example | undefined>(examples[0]);
  const [options, setOptions] = useState<Options>(defaultSettings);
  const [result, setResult] = useState<ConversionResult>();
  const [snapshot, setSnapshot] = useState<ConversionRequest>();
  const [snapshotExample, setSnapshotExample] = useState<Example>();
  const [busy, setBusy] = useState(false);
  const [stage, setStage] = useState('Ready when you are');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [view, setView] = useState<View>('code');
  const [analysis, setAnalysis] = useState('');
  const [dataFile, setDataFile] = useState<File>();
  const [dataKind, setDataKind] = useState<DataKind>('simulate');
  const [simulationN, setSimulationN] = useState(100);
  const [categorical, setCategorical] = useState('');
  const [previews, setPreviews] = useState<PreviewFile[]>([]);
  const [render, dispatch] = useReducer(renderReducer, idle);
  const [progress, setProgress] = useState<ProgressSnapshot>();
  const [progressKind, setProgressKind] = useState<'work' | 'render'>('work');
  const [scanning, setScanning] = useState(false);
  const [renderFiles, setRenderFiles] = useState<File[]>([]);
  const [useBundled, setUseBundled] = useState(false);
  /** Minutes the render may take; null until chosen (then the suggestion for the report's size applies). */
  const [renderLimit, setRenderLimit] = useState<number | null>(null);
  const [workspaceKey, setWorkspaceKey] = useState(0);
  const worker = useRef<RWorkbench | null>(null);
  const renderer = useRef<ReportRenderer | null>(null);
  const job = useRef(0);
  const renderJob = useRef(0);
  const workTracker = useRef<ProgressTracker | null>(null);
  const renderTracker = useRef<ProgressTracker | null>(null);
  const progressBox = useRef<HTMLDivElement>(null);
  const showingProgress = Boolean(progress);

  useEffect(() => () => { worker.current?.close(); renderer.current?.close(); }, []);
  useEffect(() => () => { previews.forEach(file => URL.revokeObjectURL(file.url)); }, [previews]);
  // Bring the progress panel into view when a long job starts, so it is never off-screen.
  useEffect(() => {
    if (!showingProgress) return;
    const still = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    progressBox.current?.scrollIntoView?.({ block: 'nearest', behavior: still ? 'auto' : 'smooth' });
  }, [showingProgress]);

  const runtime = () => { worker.current ??= new RWorkbench(setStage); return worker.current; };
  /** A fresh tracker for one job; the previous job of the same kind stops reporting. */
  const track = (kind: 'work' | 'render', title: string, phases: PhaseSpec[]) => {
    const holder = kind === 'work' ? workTracker : renderTracker;
    holder.current?.cancel();
    const tracker = new ProgressTracker(title, phases, snapshot => { setProgressKind(kind); setProgress(snapshot); });
    holder.current = tracker;
    setProgressKind(kind);
    setProgress(tracker.snapshot);
    return tracker;
  };
  /** Ends a job's progress display; `ok` records its last step's duration for later estimates. */
  const untrack = (tracker: ProgressTracker, ok: boolean) => {
    if (ok) tracker.finish(); else tracker.cancel();
    if (workTracker.current === tracker || renderTracker.current === tracker) setProgress(undefined);
    if (workTracker.current === tracker) workTracker.current = null;
    if (renderTracker.current === tracker) renderTracker.current = null;
  };
  /** Stops a running report preview: invalidates its job and terminates its WebR instance. */
  const stopRender = (reason = 'Rendering was cancelled.') => {
    ++renderJob.current;
    dispatch({ type: 'cancel', reason });
    renderer.current?.close(reason);
    renderer.current = null;
    if (renderTracker.current) untrack(renderTracker.current, false);
  };
  const resetRender = () => {
    stopRender();
    dispatch({ type: 'reset' });
    setRenderFiles([]);
    setScanning(false);
  };
  const invalidate = () => {
    setResult(undefined); setSnapshot(undefined); setPreviews([]); setError(''); setNotice('');
    resetRender();
  };
  const updateOptions = (patch: Partial<Options>) => {
    invalidate();
    setOptions(current => ({ ...current, ...patch }));
  };

  async function convert() {
    setBusy(true); setError(''); setNotice(''); setPreviews([]); resetRender();
    const current = ++job.current;
    const tracker = track('work', 'Converting your analysis', convertPhases);
    let ok = false;
    try {
      const input = buildConversionRequest({ mode, source, ...options });
      const output = await runtime().convert(input, tracker);
      if (current !== job.current) return;
      ok = true;
      setResult(output); setSnapshot(input); setSnapshotExample(example); setView('code');
      setAnalysis(output.analyses.find(item => item.status === 'converted')?.id ?? '');
      setDataKind(example?.bundledData ? 'bundled' : 'simulate');
      setUseBundled(Boolean(example?.bundledData));
      setStage(output.status === 'failed' ? 'Review the conversion notes' : 'Conversion ready');
    } catch (e) {
      if (current === job.current) {
        setError(message(e, 'The R worker failed. Clear the workspace and try again.'));
        setStage('Conversion interrupted');
      }
    } finally {
      untrack(tracker, ok);
      if (current === job.current) setBusy(false);
    }
  }

  function reset() {
    ++job.current;
    worker.current?.close(); worker.current = null;
    if (workTracker.current) untrack(workTracker.current, false);
    resetRender();
    setBusy(false); setDataFile(undefined); setPreviews([]); setError(''); setNotice('');
    setResult(undefined); setSnapshot(undefined); setSnapshotExample(undefined); setExample(undefined);
    setSource(''); setFilename('analysis.R'); setCategorical(''); setUseBundled(false);
    setWorkspaceKey(key => key + 1); setStage('Workspace cleared');
  }

  async function upload(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    if (file.size > limits.source) {
      setError('Use a source file smaller than 5 MB, or convert it in local R.');
      return;
    }
    invalidate(); setExample(undefined); setSource(await file.text()); setFilename(file.name);
  }

  function changeMode(value: Mode) {
    invalidate(); setMode(value);
    setExample(value === 'code' ? examples[0] : undefined);
    setSource(value === 'code' ? starterCode : '');
  }

  async function chooseExample(item: Example) {
    try {
      const text = await loadExample(item);
      invalidate(); setMode(item.mode); setSource(text); setFilename(item.filename); setExample(item);
    } catch (e) { setError(message(e, 'The example could not be loaded.')); }
  }

  async function preview() {
    if (!snapshot || !analysis || !result) return;
    if (dataKind === 'file' && !dataFile) { setError('Select a local CSV or SAV dataset first.'); return; }
    setBusy(true); setError(''); setPreviews([]);
    const current = ++job.current;
    const tracker = track('work', 'Drawing figure previews', previewPhases);
    let ok = false;
    try {
      const file = dataKind === 'bundled' ? await loadBundledDataset() : dataKind === 'file' ? dataFile : undefined;
      const request: ConversionRequest = {
        ...snapshot, action: 'preview', analysis_id: analysis, data_kind: dataKind === 'simulate' ? 'simulate' : 'file',
        n: simulationN, categorical: categorical.split(',').map(x => x.trim()).filter(Boolean),
      };
      const files = await runtime().preview(request, previewPackages(result.manifest.plots, analysis), file,
        dataKind === 'bundled', tracker);
      if (current !== job.current) { files.forEach(item => URL.revokeObjectURL(item.url)); return; }
      ok = true;
      setPreviews(files); setStage('Figures ready to download');
    } catch (e) {
      if (current === job.current) setError(message(e, 'The preview failed. Your converted code is still available.'));
    } finally {
      untrack(tracker, ok);
      if (current === job.current) setBusy(false);
    }
  }

  async function bundle() {
    if (!result || !snapshot) return;
    try { download(await buildBundle(snapshot.mode, result, previews), 'jmv2gg-bundle.zip'); }
    catch { setError('The bundle could not be prepared. Download the source and figures separately.'); }
  }

  async function scanReport() {
    if (!result) return;
    setScanning(true); setError('');
    const current = renderJob.current;
    const tracker = track('work', 'Checking the report before rendering', scanPhases);
    let ok = false;
    try {
      const scan = await runtime().scan(result.text, tracker);
      ok = true;
      if (current === renderJob.current) { dispatch({ type: 'scanned', scan }); setStage('Report checked'); }
    } catch (e) {
      if (current === renderJob.current) {
        setError(message(e, 'The report check failed. Render it in native R instead.'));
      }
    } finally { untrack(tracker, ok); setScanning(false); }
  }

  async function startRender() {
    if (!result || render.phase === 'idle') return;
    setError('');
    const current = ++renderJob.current;
    dispatch({ type: 'start' });
    const tracker = track('render', 'Rendering the report preview', renderPhases);
    tracker.step('Reading the data files…');
    let ok = false;
    try {
      const chosen = useBundled ? [await loadBundledDataset()] : renderFiles;
      const check = checkDataFiles(chosen);
      if (!check.ok) throw new Error(check.error);
      const files = await Promise.all(chosen.map(async (file, index) => ({
        name: check.names[index], bytes: new Uint8Array(await file.arrayBuffer()),
      })));
      // Cancel may have been pressed while the files were being read.
      if (current !== renderJob.current) return;
      const session = new ReportRenderer(tracker);
      renderer.current = session;
      const html = await session.render({
        rmd: result.text, files, confirmed: confirmedCodes(render.scan),
        packages: [...render.scan.packages, ...result.manifest.packages],
        needsBetterGG: result.manifest.plots.some(plot => plot.engine === 'bettergg'),
        limitMinutes: renderLimit ?? suggestedRenderLimit(render.scan.chunks, result.manifest.plots.length),
      });
      ok = true;
      if (current === renderJob.current) dispatch({ type: 'succeed', html });
    } catch (e) {
      if (current === renderJob.current) {
        dispatch({ type: 'fail', error: message(e, 'The report could not be rendered.') });
      }
    } finally {
      if (current === renderJob.current) renderer.current = null;
      untrack(tracker, ok);
    }
  }

  async function copyCode() {
    if (!result) return;
    try { await navigator.clipboard.writeText(result.text); setNotice('Code copied.'); }
    catch { setError('Clipboard access failed. Download the code instead.'); }
  }

  /** New figure labels: rewrite the label block in the code; previews use them through the request. */
  function applyLabels(labels: LabelText, levels: LevelText) {
    if (!result || !snapshot) return;
    const text = replaceLabelBlock(result.text, labels, levels, options.labels === 'names');
    if (text === null) { setError('The label block was not found in the generated code. Convert again.'); return; }
    resetRender(); setPreviews([]);
    setResult({ ...result, text, manifest: { ...result.manifest, labels } });
    setSnapshot({ ...snapshot, style: { ...snapshot.style, label_text: labels, level_text: levels } });
    setOptions(current => ({ ...current, labelText: labels, levelText: levels }));
    setNotice('Labels applied to the generated code and to the figure previews.');
  }

  function downloadReport() {
    if (render.phase !== 'done') return;
    download(new Blob([render.html], { type: 'text/html;charset=utf-8' }), 'report-preview.html');
  }

  const ready = result && snapshot;
  const views: View[] = snapshot?.mode === 'rmd'
    ? ['code', 'labels', 'figures', 'report', 'notes'] : ['code', 'labels', 'figures', 'notes'];
  const viewLabel = (value: View) => value === 'code' ? 'Generated code' : value === 'labels' ? 'Figure labels'
    : value === 'figures' ? 'Preview figures'
    : value === 'report' ? 'Render report'
    : `Notes${result?.diagnostics.length ? ` (${result.diagnostics.length})` : ''}`;
  const shownView = views.includes(view) ? view : 'code';

  return <>
    <SiteHeader onReset={reset}/>
    <main id="main" key={workspaceKey}>
      <Intro/>
      <div className="workbench">
        <section className="input-panel panel" aria-labelledby="input-title">
          <div className="panel-heading">
            <div>
              <h2 id="input-title">Your analysis</h2>
              <p>Start with code copied from jamovi or an existing Rmd.</p>
            </div>
            <span className="language-label">R</span>
          </div>
          <SourceEditor mode={mode} source={source} filename={filename} busy={busy} example={example}
            onMode={changeMode} onSource={text => { invalidate(); setSource(text); }} onUpload={upload}
            onExample={chooseExample}/>
          <OptionsPanel mode={mode} options={options} busy={busy} onChange={updateOptions}/>
          <div className="convert-row">
            <span className={`runtime-state ${busy ? 'working' : ''}`} role="status">{stage}</span>
            {busy ? <button onClick={reset}>Cancel and reset</button>
              : <button className="primary" disabled={!source.trim()} onClick={convert}>
                Convert analysis <Icon name="arrow"/></button>}
          </div>
        </section>
        <section className="output-panel panel" aria-labelledby="output-title">
          <div className="panel-heading">
            <div>
              <h2 id="output-title">Your editable output</h2>
              <p>{ready ? `${result.manifest.converted} of ${result.manifest.detected} analyses converted · `
                + `${result.manifest.plots.length} requested figures`
                : 'Readable R code, with the details kept intact.'}</p>
            </div>
            <Icon name="chart"/>
          </div>
          <div className="output-tabs" role="group" aria-label="Output view">
            {views.map(value => <button key={value} aria-pressed={shownView === value} onClick={() => setView(value)}>
              {viewLabel(value)}</button>)}
          </div>
          <div ref={progressBox}>
            {progress && <ProgressPanel progress={progress}
              cancelLabel={progressKind === 'render' ? 'Cancel rendering' : 'Cancel and reset'}
              onCancel={progressKind === 'render'
                ? () => stopRender('Rendering was cancelled. The separate R session was closed.') : reset}/>}
          </div>
          {error && <div className="error-banner" role="alert">{error}</div>}
          {notice && <div className="notice" role="status">{notice}</div>}
          {!ready ? <EmptyOutput/> : <>
            <StatusNotice status={result.status}/>
            {shownView === 'code' && <CodeView mode={snapshot.mode} text={result.text} onCopy={copyCode}/>}
            {shownView === 'labels' && <LabelsView key={result.text.length + JSON.stringify(result.manifest.labels)}
              labels={result.manifest.labels} levels={options.levelText} busy={busy} onApply={applyLabels}/>}
            {shownView === 'notes' && <NotesView result={result}/>}
            {shownView === 'figures' && <FiguresView busy={busy || scanning || render.phase === 'rendering'} analyses={result.analyses} analysis={analysis}
              dataKind={dataKind} bundledAvailable={Boolean(snapshotExample?.bundledData)} simulationN={simulationN}
              categorical={categorical} previews={previews}
              onAnalysis={id => { setAnalysis(id); setPreviews([]); }}
              onDataKind={kind => { setDataKind(kind); setPreviews([]); }}
              onDataFile={file => { setDataFile(file); setPreviews([]); }}
              onSimulationN={setSimulationN} onCategorical={setCategorical} onPreview={preview}
              onDownload={file => download(new Blob([new Uint8Array(file.bytes)], { type: 'image/png' }),
                `${file.simulated ? 'simulated-' : ''}${file.path.split('/').at(-1)}`)}/>}
            {shownView === 'report' && <RenderPanel state={render} scanning={scanning}
              busy={busy} dataFiles={renderFiles} bundledAvailable={Boolean(snapshotExample?.bundledData)}
              useBundled={useBundled} onScan={scanReport} onConfirm={value => dispatch({ type: 'confirm', value })}
              onDataFiles={setRenderFiles} onUseBundled={setUseBundled} onRender={startRender}
              figures={result.manifest.plots.length} limitMinutes={renderLimit} onLimit={setRenderLimit}
              onCancel={() => stopRender('Rendering was cancelled. The separate R session was closed.')}
              onDownload={downloadReport}/>}
            <Downloads mode={snapshot.mode}
              onSource={() => download(new Blob([result.text], { type: 'text/plain;charset=utf-8' }),
                convertedName(snapshot.mode))}
              onBundle={bundle}/>
          </>}
        </section>
      </div>
      <Explainer/>
    </main>
    <Footer/>
  </>;
}
