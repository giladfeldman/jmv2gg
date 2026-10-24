import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { ConversionRequest } from './types';
import type { ProgressSnapshot } from './lib/progress';

const initMock = vi.hoisted(() => vi.fn(async () => {}));
const fake = vi.hoisted(() => ({
  r: [] as string[], install: [] as unknown[][], closed: 0, installed: ['base', 'utils', 'stats'] as string[],
  output: [] as { type: string; data: string }[], knitResult: '', execFail: '', knitDelay: 20, files: {} as Record<string, string>,
}));
vi.mock('webr', () => ({ WebR: class {
  init = initMock;
  installPackages = async (...args: unknown[]) => { fake.install.push(args); };
  FS = {
    mkdir: async () => {},
    writeFile: async (path: string, bytes: Uint8Array) => { fake.files[path] = new TextDecoder().decode(bytes); }, readFile: async () => new TextEncoder().encode('<p>ok</p>'),
  };
  evalRVoid = async (code: string) => { fake.r.push(code); };
  evalRRaw = async () => fake.installed;
  evalRString = async (code: string) => {
    fake.r.push(code);
    await new Promise(resolve => setTimeout(resolve, fake.knitDelay));
    if (code.includes('browser_request')) {
      return JSON.stringify({ status: 'complete', analyses: [], diagnostics: [], manifest: { converted: 1 } });
    }
    return fake.knitResult;
  };
  read = () => {
    const next = fake.output.shift();
    return next ? Promise.resolve(next) : new Promise(() => {});
  };
  evalR = async () => ({ exec: async () => {
    if (fake.execFail) { const error = fake.execFail; fake.execFail = ''; throw new Error(error); }
    return { toString: async () => JSON.stringify({
    status: 'complete', analyses: [], diagnostics: [], manifest: { converted: 1 },
  }) };
  } });
  destroy() { throw new Error("Can't find object in shelter."); }
  close() { fake.closed++; }
} }));
import { RWorkbench } from './runtime';
import { ReportRenderer, isLargeReport, suggestedRenderLimit } from './reportRuntime';
import { ProgressTracker } from './lib/progress';

// A small lock: ggplot2 needs rlang and scales; scales needs rlang.
const lock = [
  'Package: rlang', '', 'Package: scales\nImports: rlang', '', 'Package: ggplot2\nImports: rlang, scales (>= 1.0)',
  '', 'Package: jsonlite', '', 'Package: yaml', '', 'Package: purrr\nImports: rlang',
  '', 'Package: styler\nImports: purrr',
  '', 'Package: knitr\nImports: yaml', '', 'Package: markdown', '', 'Package: jmv\nImports: ggplot2',
  '', 'Package: ggstatsplot\nImports: ggplot2',
].join('\n');
const appIndex = 'Package: BetterGG\nDepends: R (>= 4.5.0), ggstatsplot (>= 1.1.2)\nImports: ggplot2, rlang, tools\n\n'
  + 'Package: jmv2gg\nImports: jsonlite, yaml, BetterGG (>= 0.2.0)\n';

function stubNetwork() {
  vi.stubGlobal('location', { origin: 'http://localhost' });
  vi.stubGlobal('fetch', async (url: string) => {
    const text = url.includes('packages.dcf') ? lock : url.includes('PACKAGES') ? appIndex : '';
    return { ok: true, text: async () => text, arrayBuffer: async () => new TextEncoder().encode(text).buffer };
  });
}
const installs = () => fake.r.map(code => /webr::install\("([^"]+)"/.exec(code)?.[1]).filter(Boolean);

beforeEach(() => {
  fake.r.length = 0; fake.install.length = 0; fake.output.length = 0; fake.files = {};
  fake.installed = ['base', 'utils', 'stats']; fake.knitResult = ''; fake.execFail = ''; fake.knitDelay = 20;
});

describe('workbench transport', () => {
  it('retains successful results from unmanaged function calls', async () => {
    stubNetwork();
    const runtime = new RWorkbench(() => {});
    const request = { source: '', mode: 'code', action: 'convert', engine: 'ggplot2' } as ConversionRequest;
    const result = await runtime.convert(request);
    expect(result.status).toBe('complete');
    expect(result.manifest.converted).toBe(1);
  });
  it('starts a fresh R session after R itself aborts, so the next request does not hang (d-636774)', async () => {
    stubNetwork();
    const runtime = new RWorkbench(() => {});
    await runtime.scan('x <- 1');
    const starts = initMock.mock.calls.length;
    const closed = fake.closed;
    fake.execFail = 'RuntimeError: unreachable';
    await expect(runtime.scan('x <- 1')).rejects.toThrow('unreachable');
    expect(fake.closed).toBe(closed + 1);
    // the next request starts a new R session and succeeds
    const scan = await runtime.scan('x <- 1');
    expect(scan).toBeDefined();
    expect(initMock.mock.calls.length).toBe(starts + 1);
    // control: an ordinary request reuses the session
    await runtime.scan('x <- 1');
    expect(initMock.mock.calls.length).toBe(starts + 1);
  });
  it('streams conversion progress: document chunks', async () => {
    stubNetwork();
    fake.output.push({ type: 'stderr', data: 'jmv2gg-progress 1 3 chunk' },
      { type: 'stderr', data: 'jmv2gg-progress 3 3 chunk' });
    const seen: ProgressSnapshot[] = [];
    const tracker = new ProgressTracker('t', [{ id: 'convert', label: 'Convert' }],
      snapshot => seen.push(snapshot), { store: null });
    const request = { source: 'x <- 1', mode: 'rmd', action: 'convert', engine: 'both' } as ConversionRequest;
    const result = await new RWorkbench(() => {}).convert(request, tracker);
    expect(result.manifest.converted).toBe(1);
    const messages = seen.map(item => item.message);
    expect(messages).toContain('Reading the document: chunk 3 of 3');
    expect(seen.at(-1)!.phases.map(phase => phase.status)).toEqual(['current']);
    // The request reaches R through a file, with progress switched on.
    expect(JSON.parse(fake.files['/workspace/request.json'])).toMatchObject({ source: 'x <- 1', progress: true });
    expect(fake.r.find(code => code.includes('browser_request'))).toContain('/workspace/request.json');
  });
  it('estimates the whole job even when an optional phase never ran', () => {
    const data: Record<string, string> = { 'jmv2gg.timing.phase.convert': '[1000]' };
    const store = { getItem: (k: string) => data[k] ?? null, setItem: (k: string, v: string) => { data[k] = v; } };
    let last: ProgressSnapshot | undefined;
    const phases = (optional: boolean) => [{ id: 'convert', label: 'Convert' }, { id: 'style', label: 'Tidy', optional }];
    const run = (optional: boolean) => {
      new ProgressTracker('t', phases(optional), snapshot => { last = snapshot; }, { store }).phase('convert');
      return last!.jobEndsAt;
    };
    expect(run(true)).toBeTypeOf('number');
    expect(run(false)).toBeUndefined();
  });
  it('reports a startup timeout instead of waiting indefinitely', async () => {
    vi.useFakeTimers();
    initMock.mockImplementationOnce(() => new Promise<void>(() => {}));
    const runtime = new RWorkbench(() => {});
    const pending = expect(runtime.initialize()).rejects.toThrow('within three minutes');
    await vi.advanceTimersByTimeAsync(180_000);
    await pending;
    vi.useRealTimers();
  });
  it('installs converter dependencies one at a time, then BetterGG and jmv2gg from the app repository', async () => {
    stubNetwork();
    fake.installed = ['base', 'utils', 'yaml'];
    const steps: string[] = [];
    const tracker = new ProgressTracker('t', [], snapshot => steps.push(snapshot.message), { store: null });
    await new RWorkbench(() => {}).initialize(tracker);
    // Dependency order from the lock; yaml was already installed; ggstatsplot (BetterGG Depends) is not
    // pulled; styler is not installed (the browser keeps jmv2gg's own layout).
    expect(installs()).toEqual(['rlang', 'scales', 'ggplot2', 'jsonlite']);
    expect(fake.r.every(code => !code.includes('webr::install(') || code.includes('info=.jmv2gg_locked'))).toBe(true);
    expect(fake.install).toEqual([
      [['BetterGG'], { repos: 'http://localhost/r-packages', quiet: true }],
      [['jmv2gg'], { repos: 'http://localhost/r-packages', quiet: true }],
    ]);
    expect(steps).toContain('Installing R packages: 3 of 4 — ggplot2');
  });
  it('terminates the report WebR instance when rendering is cancelled', async () => {
    stubNetwork();
    initMock.mockImplementationOnce(() => new Promise<void>(resolve => setTimeout(resolve, 10)));
    const before = fake.closed;
    const renderer = new ReportRenderer(new ProgressTracker('t', [], () => {}, { store: null }));
    const pending = renderer.render({ rmd: '', files: [], packages: [], needsBetterGG: false, confirmed: [] });
    renderer.close('stopped by test');
    await expect(pending).rejects.toThrow('stopped by test');
    await new Promise(resolve => setTimeout(resolve, 20));
    expect(fake.closed).toBeGreaterThan(before);
  });
  it('streams chunk progress while rendering and resolves with the HTML', async () => {
    stubNetwork();
    fake.output.push({ type: 'stdout', data: 'unrelated output' },
      { type: 'stderr', data: 'jmv2gg-progress 1 2 setup' },
      { type: 'stderr', data: 'jmv2gg-progress 2 2 confirmatory' });
    const seen: ProgressSnapshot[] = [];
    const tracker = new ProgressTracker('t', [{ id: 'knit', label: 'Render' }], snapshot => seen.push(snapshot),
      { store: null });
    const html = await new ReportRenderer(tracker).render({
      rmd: '', files: [], packages: [], needsBetterGG: true, confirmed: ['asis_output'],
    });
    expect(html).toBe('<p>ok</p>');
    expect(seen.map(item => item.message)).toContain('Rendering: chunk 2 of 2 (confirmatory)');
    const knit = fake.r.find(code => code.includes('render_browser_preview'))!;
    expect(knit).toContain('progress = TRUE');
    // R's own limit is the chosen limit (15 minutes by default), not a shorter one of its own.
    expect(knit).toContain('time_limit = 900');
    expect(knit).toContain('asis_output');
    // BetterGG figures need ggstatsplot in the render session.
    expect(installs()).toContain('ggstatsplot');
    // jmv::contTables -> vcdExtra -> chromote needs the app repository's websocket placeholder.
    const placeholder = fake.install.find(args => JSON.stringify(args[0]) === '["websocket"]');
    expect(placeholder).toBeDefined();
    expect(String((placeholder![1] as { repos: string }).repos)).toMatch(/\/r-packages$/);
  });
  it('gives R the limit chosen for a long report', async () => {
    stubNetwork();
    const tracker = new ProgressTracker('t', [], () => {}, { store: null });
    await new ReportRenderer(tracker).render({
      rmd: '', files: [], packages: [], needsBetterGG: false, confirmed: [], limitMinutes: 60,
    });
    const knit = fake.r.filter(code => code.includes('render_browser_preview')).at(-1)!;
    expect(knit).toContain('time_limit = 3600');
    expect(suggestedRenderLimit(21, 26)).toBe(15);
    expect(suggestedRenderLimit(85, 120)).toBe(60);
    expect(isLargeReport(41, 0)).toBe(true);
  });
  it('installs jmv only for a report that uses it (d-797897)', async () => {
    stubNetwork();
    const render = (rmd: string) => new ReportRenderer(new ProgressTracker('t', [], () => {}, { store: null }))
      .render({ rmd, files: [], packages: [], needsBetterGG: false, confirmed: [] });
    await render('x <- 1');
    expect(installs()).not.toContain('jmv');
    fake.r.length = 0;
    // control: a document naming jmv (here through a loader the scan does not read) still gets it
    await render('pacman::p_load(jmv)');
    expect(installs()).toContain('jmv');
  });
  it('rejects with the R error text when the document fails', async () => {
    stubNetwork();
    fake.knitResult = 'object \'study\' not found';
    const renderer = new ReportRenderer(new ProgressTracker('t', [], () => {}, { store: null }));
    await expect(renderer.render({ rmd: '', files: [], packages: [], needsBetterGG: false, confirmed: [] }))
      .rejects.toThrow("object 'study' not found");
  });
});
