import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { ConversionRequest } from './types';
import type { ProgressSnapshot } from './lib/progress';

const initMock = vi.hoisted(() => vi.fn(async () => {}));
const fake = vi.hoisted(() => ({
  r: [] as string[], install: [] as unknown[][], closed: 0, installed: ['base', 'utils', 'stats'] as string[],
  output: [] as { type: string; data: string }[], knitResult: '', knitDelay: 20,
}));
vi.mock('webr', () => ({ WebR: class {
  init = initMock;
  installPackages = async (...args: unknown[]) => { fake.install.push(args); };
  FS = {
    mkdir: async () => {}, writeFile: async () => {}, readFile: async () => new TextEncoder().encode('<p>ok</p>'),
  };
  evalRVoid = async (code: string) => { fake.r.push(code); };
  evalRRaw = async () => fake.installed;
  evalRString = async (code: string) => {
    fake.r.push(code);
    await new Promise(resolve => setTimeout(resolve, fake.knitDelay));
    return fake.knitResult;
  };
  read = () => {
    const next = fake.output.shift();
    return next ? Promise.resolve(next) : new Promise(() => {});
  };
  evalR = async () => ({ exec: async () => ({ toString: async () => JSON.stringify({
    status: 'complete', analyses: [], diagnostics: [], manifest: { converted: 1 },
  }) }) });
  destroy() { throw new Error("Can't find object in shelter."); }
  close() { fake.closed++; }
} }));
import { RWorkbench } from './runtime';
import { ReportRenderer } from './reportRuntime';
import { ProgressTracker } from './lib/progress';

// A small lock: ggplot2 needs rlang and scales; scales needs rlang; styler needs purrr.
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
  fake.r.length = 0; fake.install.length = 0; fake.output.length = 0;
  fake.installed = ['base', 'utils', 'stats']; fake.knitResult = ''; fake.knitDelay = 20;
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
    // Dependency order from the lock; yaml was already installed; ggstatsplot (BetterGG Depends) is not pulled.
    expect(installs()).toEqual(['rlang', 'scales', 'ggplot2', 'jsonlite', 'purrr', 'styler']);
    expect(fake.r.every(code => !code.includes('webr::install(') || code.includes('info=.jmv2gg_locked'))).toBe(true);
    expect(fake.install).toEqual([
      [['BetterGG'], { repos: 'http://localhost/r-packages', quiet: true }],
      [['jmv2gg'], { repos: 'http://localhost/r-packages', quiet: true }],
    ]);
    expect(steps).toContain('Installing R packages: 3 of 6 — ggplot2');
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
    expect(knit).toContain('time_limit = 600');
    expect(knit).toContain('asis_output');
    // BetterGG figures need ggstatsplot in the render session.
    expect(installs()).toContain('ggstatsplot');
    // jmv::contTables -> vcdExtra -> chromote needs the app repository's websocket placeholder.
    const placeholder = fake.install.find(args => JSON.stringify(args[0]) === '["websocket"]');
    expect(placeholder).toBeDefined();
    expect(String((placeholder![1] as { repos: string }).repos)).toMatch(/\/r-packages$/);
  });
  it('rejects with the R error text when the document fails', async () => {
    stubNetwork();
    fake.knitResult = 'object \'study\' not found';
    const renderer = new ReportRenderer(new ProgressTracker('t', [], () => {}, { store: null }));
    await expect(renderer.render({ rmd: '', files: [], packages: [], needsBetterGG: false, confirmed: [] }))
      .rejects.toThrow("object 'study' not found");
  });
});
