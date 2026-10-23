import { WebR, type RFunction, type RCharacter } from 'webr';
import { cleanPackages, normaliseResult, normaliseScan } from './lib/requests';
import { limits } from './lib/files';
import { installOrder, packageDb, runtimeDependencies, type PackageDb } from './lib/packages';
import { ProgressTracker, parseProgressLine, type PhaseSpec } from './lib/progress';
import type { ConversionRequest, ConversionResult, PreviewFile, ScanRequest, ScanResult } from './types';

export const webrBaseUrl = 'https://webr.r-wasm.org/v0.6.0/';
/** The app's own binary repository (jmv2gg and BetterGG only). */
export const appRepositoryIndex = '/r-packages/bin/emscripten/contrib/4.6/PACKAGES';

export const setupPhases: PhaseSpec[] = [
  { id: 'start', label: 'Start R in your browser' },
  { id: 'packages', label: 'Install R packages' },
  { id: 'converter', label: 'Install jmv2gg and BetterGG' },
];
export const convertPhases: PhaseSpec[] = [...setupPhases, { id: 'convert', label: 'Convert your analysis' }];
export const scanPhases: PhaseSpec[] = [...setupPhases, { id: 'scan', label: 'Check the report before rendering' }];
export const previewPhases: PhaseSpec[] = [...setupPhases,
  { id: 'plot-packages', label: 'Install plotting packages' },
  { id: 'data', label: 'Read the data' },
  { id: 'draw', label: 'Draw the figures' }];

/** A tracker that reports nowhere, for callers that do not show progress (tests). */
export const silentTracker = () => new ProgressTracker('', [], () => {}, { store: null });

export interface Session { runtime: WebR; lock: PackageDb }

/** Starts a WebR instance and loads the pinned dependency index as `.jmv2gg_locked` (and in JS). */
export async function startWebR(tracker: ProgressTracker, isClosed: () => boolean): Promise<Session> {
  tracker.phase('start', 'Starting R (WebR 0.6.0) in your browser…');
  const runtime = new WebR({ baseUrl: webrBaseUrl });
  await runtime.init();
  if (isClosed()) { runtime.close(); throw new Error('Workspace cleared.'); }
  await runtime.FS.mkdir('/workspace');
  const response = await fetch('/locks/packages.dcf');
  if (!response.ok) throw new Error('The pinned R package dependency index could not be loaded.');
  const bytes = new Uint8Array(await response.arrayBuffer());
  await runtime.FS.writeFile('/workspace/packages.dcf', bytes);
  await runtime.evalRVoid('.jmv2gg_locked <- read.dcf("/workspace/packages.dcf"); '
    + 'rownames(.jmv2gg_locked) <- .jmv2gg_locked[, "Package"]');
  return { runtime, lock: packageDb(new TextDecoder().decode(bytes)) };
}

/**
 * Installs `roots` and their dependencies from the lock, ONE package at a time in dependency
 * order, so each step can be counted. Packages R already has are skipped.
 */
export async function installFromLock(session: Session, roots: string[], tracker: ProgressTracker,
  label = 'Installing R packages') {
  const installed = await session.runtime.evalRRaw('rownames(installed.packages())', 'string[]');
  const { order } = installOrder(cleanPackages(roots, []), session.lock, installed);
  tracker.begin(order);
  for (let i = 0; i < order.length; i++) {
    tracker.step(`${label}: ${i + 1} of ${order.length} — ${order[i]}`);
    tracker.advance(i);
    await session.runtime.evalRVoid(`webr::install(${JSON.stringify(order[i])}, info=.jmv2gg_locked, quiet=TRUE)`);
  }
  tracker.advance(order.length);
  return order;
}

/**
 * R packages jmv2gg and BetterGG need before they can be loaded, read from the app repository
 * index. Imports and LinkingTo only: R loads a namespace without its Depends (checked in native
 * R 4.4), so conversion does not pull BetterGG's ggstatsplot stack. `withDepends` adds those
 * for code that draws BetterGG figures.
 */
export async function converterDependencies(withDepends = false) {
  const response = await fetch(appRepositoryIndex);
  if (!response.ok) throw new Error('The jmv2gg package index could not be loaded.');
  const db = packageDb(await response.text());
  const own = ['BetterGG', 'jmv2gg'];
  return own.flatMap(name => runtimeDependencies(db.get(name), withDepends)).filter(name => !own.includes(name));
}

/**
 * Installs BetterGG, then jmv2gg, from the app's own repository, one step each. Their
 * dependencies are installed from the lock beforehand, so webr::install() finds nothing left to
 * fetch except packages that are neither installed nor in this repository (for conversion:
 * BetterGG's Depends, ggstatsplot), which it cannot fetch from here.
 */
export async function installConverter(session: Session, tracker: ProgressTracker) {
  tracker.phase('converter', 'Installing BetterGG from the jmv2gg site…');
  await session.runtime.installPackages(['BetterGG'], { repos: `${location.origin}/r-packages`, quiet: true });
  tracker.step('Installing jmv2gg from the jmv2gg site…');
  await session.runtime.installPackages(['jmv2gg'], { repos: `${location.origin}/r-packages`, quiet: true });
}

/**
 * Report previews only: the app repository's placeholder for 'websocket', which has no WebR
 * build. jmv::contTables needs vcdExtra, whose imports reach chromote -> websocket; with the
 * placeholder they load (it opens no connections and errors on use). Installed before the lock
 * packages so their install order treats it as present.
 */
export async function installPlaceholders(session: Session, tracker: ProgressTracker) {
  tracker.step('Installing the jmv2gg placeholder for the websocket package…');
  await session.runtime.installPackages(['websocket'], { repos: `${location.origin}/r-packages`, quiet: true });
}

/**
 * Runs R code with its output streamed instead of captured, and passes each line R writes to
 * `onLine` while R works (the "jmv2gg-progress" lines R writes with message()). Resolves with
 * the code's string result.
 */
export async function streamR(runtime: WebR, code: string, onLine: (line: string) => void, isClosed: () => boolean) {
  let finished = false;
  const result = runtime.evalRString(code, { captureStreams: false, captureConditions: false })
    .finally(() => { finished = true; });
  const ended = result.then(() => undefined, () => undefined);
  let pending = '';
  while (!finished && !isClosed()) {
    const message = await Promise.race([runtime.read(), ended]);
    if (!message) break;
    if (message.type !== 'stdout' && message.type !== 'stderr') continue;
    pending += `${String(message.data)}\n`;
    const lines = pending.split('\n');
    pending = lines.pop() ?? '';
    for (const line of lines) onLine(line);
  }
  return result;
}

/** Applies one line of R output during a conversion: chunks of the document as they are read. */
export function applyConvertOutput(line: string, tracker: ProgressTracker) {
  const progress = parseProgressLine(line);
  if (!progress) return false;
  tracker.count(progress.done, progress.total, '', `Reading the document: chunk ${progress.done} of ${progress.total}`);
  return true;
}

/** The conversion call: the request is read from a file, so long documents need no escaping in R code. */
const convertCall = 'tryCatch(as.character(jmv2gg::browser_request(paste(readLines("/workspace/request.json", '
  + 'warn = FALSE, encoding = "UTF-8"), collapse = "\\n"))), error = function(e) '
  + 'as.character(jsonlite::toJSON(list(error = conditionMessage(e)), auto_unbox = TRUE)))';

export async function withTimeout<T>(work: Promise<T>, ms: number, message: string): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const limit = new Promise<never>((_, reject) => { timer = setTimeout(() => reject(new Error(message)), ms); });
  try { return await Promise.race([work, limit]); } finally { clearTimeout(timer); }
}

export class RWorkbench {
  private session?: Session;
  private bridge?: RFunction;
  private ready?: Promise<void>;
  private closed = false;
  private tracker = silentTracker();
  private status: (message: string) => void;
  constructor(status: (message: string) => void) {
    this.status = message => { if (!this.closed) status(message); };
  }
  private use(tracker?: ProgressTracker) { if (tracker) this.tracker = tracker; return this.tracker; }
  async initialize(tracker?: ProgressTracker) {
    this.use(tracker);
    this.ready ??= this.load();
    try { await this.ready; } catch (error) { this.close(); throw error; }
  }
  private async load() {
    this.status('Starting WebR 0.6.0 on your device…');
    // The three-minute limit covers starting R only; installs are counted and may take longer.
    const session = await withTimeout(startWebR(this.tracker, () => this.closed), 180_000, 'WebR could not start '
      + 'within three minutes. Check runtime downloads or use the native R package. Clear the workspace to retry.');
    this.session = session;
    this.tracker.phase('packages', 'Finding the R packages the converter needs…');
    this.status('Installing the R packages the converter needs…');
    const needed = ['jsonlite', 'yaml', 'rlang', ...await converterDependencies()];
    // No styler: the browser keeps jmv2gg's own code layout (styler took about a minute per analysis in WebR).
    await installFromLock(session, needed, this.tracker, 'Installing R packages');
    this.status('Loading the R conversion package…');
    await installConverter(session, this.tracker);
    await session.runtime.evalRVoid('setwd("/workspace"); options(webr.show_menu=FALSE)');
    this.bridge = await session.runtime.evalR('function(x) tryCatch(jmv2gg::browser_request(x), '
      + 'error=function(e) jsonlite::toJSON(list(error=conditionMessage(e)),auto_unbox=TRUE))') as RFunction;
  }
  private async call<T>(request: ConversionRequest | ScanRequest): Promise<T> {
    const value = await this.bridge!.exec(JSON.stringify(request)) as RCharacter;
    const response = JSON.parse(await value.toString());
    // exec() results are not registered in WebR's root shelter. Destroying one
    // there throws and discards an otherwise successful conversion.
    if (response.error) throw new Error(response.error);
    return response as T;
  }
  async convert(request: ConversionRequest, tracker?: ProgressTracker) {
    await this.initialize(tracker);
    this.tracker.phase('convert', 'Converting with the jmv2gg R package…');
    this.status('Converting with the installed jmv2gg R package…');
    const runtime = this.session!.runtime;
    await runtime.FS.writeFile('/workspace/request.json',
      new TextEncoder().encode(JSON.stringify({ ...request, progress: true })));
    const json = await streamR(runtime, convertCall, line => applyConvertOutput(line, this.tracker), () => this.closed);
    const response = JSON.parse(json);
    if (response.error) throw new Error(response.error);
    return normaliseResult(response as ConversionResult);
  }
  /** Lists what a document would do before it is rendered; nothing in it is executed. */
  async scan(source: string, tracker?: ProgressTracker) {
    await this.initialize(tracker);
    this.tracker.phase('scan', 'Checking the converted report before rendering…');
    this.status('Checking the converted report before rendering…');
    return normaliseScan(await this.call<ScanResult>({ action: 'scan', source }));
  }
  /**
   * Draws the ggplot2 figures of one analysis. `packages` are those figures' manifest packages;
   * `simulated` marks previews drawn from simulated values (labelled, and left out of the ZIP).
   */
  async preview(request: ConversionRequest, packages: string[], file?: File,
    simulated = false, tracker?: ProgressTracker): Promise<PreviewFile[]> {
    await this.initialize(tracker);
    const session = this.session!;
    this.tracker.phase('plot-packages', 'Checking the plotting packages…');
    this.status('Loading plotting packages. The first preview takes longer…');
    const sav = Boolean(file?.name.toLowerCase().endsWith('.sav'));
    await installFromLock(session, ['ggplot2', 'emmeans', ...cleanPackages(packages), ...(sav ? ['haven'] : [])],
      this.tracker, 'Installing plotting packages');
    this.tracker.phase('data', file ? `Reading ${file.name}…` : 'Preparing simulated data…');
    if (file) {
      if (file.size > limits.previewData) {
        throw new Error('This preview is limited to 100 MB data files. Use local R for larger datasets.');
      }
      request.data_path = `/workspace/input.${sav ? 'sav' : 'csv'}`;
      await session.runtime.FS.writeFile(request.data_path, new Uint8Array(await file.arrayBuffer()));
    }
    this.tracker.phase('draw', 'Drawing the figures in your browser…');
    this.status('Drawing figures locally and preparing PNG downloads…');
    const response = await this.call<{ files: { path: string }[] | { path: string }; simulated: boolean }>(request);
    const files: PreviewFile[] = [];
    for (const { path } of Array.isArray(response.files) ? response.files : [response.files]) {
      const bytes = await session.runtime.FS.readFile(`/workspace/${path}`);
      if (bytes.length < 8 || bytes[0] !== 137 || bytes[1] !== 80) {
        throw new Error('The graphics device did not produce a valid PNG.');
      }
      const url = URL.createObjectURL(new Blob([new Uint8Array(bytes)], { type: 'image/png' }));
      files.push({ path, url, bytes, simulated: response.simulated || simulated });
    }
    return files;
  }
  close() {
    this.closed = true;
    this.tracker.cancel();
    this.session?.runtime.close();
    this.session = undefined;
    this.ready = undefined;
    this.bridge = undefined;
  }
}
