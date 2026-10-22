import { readFileSync } from 'node:fs';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { ReportFrame } from '../src/components/ReportFrame';
import {
  asArray, buildConversionRequest, cleanPackages, defaultSettings, normaliseResult, normaliseScan, previewPackages,
  rVector,
} from '../src/lib/requests';
import { checkDataFiles, sanitizeFileName } from '../src/lib/files';
import { canStart, confirmedCodes, idle, renderReducer, type RenderState } from '../src/lib/renderState';
import { bundledFigures } from '../src/lib/bundle';
import type { ConversionResult, PlotInfo, ScanResult } from '../src/types';

const csp = "default-src 'self'; script-src 'self' 'unsafe-eval' blob: https://webr.r-wasm.org; "
  + "worker-src 'self' blob: https://webr.r-wasm.org; "
  + "connect-src 'self' https://webr.r-wasm.org https://repo.r-wasm.org; "
  + "style-src 'self' 'unsafe-inline'; font-src 'self' data:; img-src 'self' blob: data:; object-src 'none'; "
  + "base-uri 'self'; frame-ancestors 'none'; form-action 'none'";

describe('report frame', () => {
  it('renders the sandbox attribute present and empty', () => {
    const html = renderToStaticMarkup(createElement(ReportFrame, { html: '<p>x</p>' }));
    const sandbox = html.match(/\ssandbox="([^"]*)"/);
    expect(sandbox).not.toBeNull();
    expect(sandbox![1]).toBe('');
    expect(html).toMatch(/referrerpolicy="no-referrer"/i);
    expect(html).toContain('title="Report preview"');
    expect(html).not.toMatch(/allow-/);
  });
});

describe('deployment headers', () => {
  it('keeps the Content Security Policy byte-for-byte', () => {
    const config = JSON.parse(readFileSync(new URL('../vercel.json', import.meta.url), 'utf8'));
    const header = config.headers[0].headers.find((item: { key: string }) => item.key === 'Content-Security-Policy');
    expect(header.value).toBe(csp);
  });
});

describe('conversion requests', () => {
  const base = { mode: 'code' as const, source: 'x', ...defaultSettings };
  it('sends the new style and figure shapes without retired options', () => {
    const request = buildConversionRequest(base);
    expect(Object.keys(request.style).sort())
      .toEqual(['grayscale', 'headings', 'palette', 'stats', 'styler', 'verbose']);
    expect(request.style)
      .toEqual({ stats: false, palette: 'nejm', grayscale: false, verbose: true, headings: false, styler: true });
    expect(Object.keys(request.figures).sort())
      .toEqual(['background', 'dpi', 'formats', 'height', 'optimize_png', 'size', 'width']);
    expect(request.figures).toMatchObject({ size: 'double', width: 7.2, formats: ['png'], background: 'white' });
    for (const retired of ['show_violin', 'show_jitter', 'jitter_width', 'jitter_height']) {
      expect(JSON.stringify(request)).not.toContain(retired);
    }
  });
  it('maps sizes, formats, palettes and R Markdown-only headings', () => {
    expect(buildConversionRequest({ ...base, size: 'single', width: 9 }).figures.width).toBe(3.5);
    expect(buildConversionRequest({ ...base, size: 'custom', width: 9 }).figures.width).toBe(9);
    expect(buildConversionRequest({ ...base, formats: ['tiff', 'pdf'] }).figures.formats)
      .toEqual(['png', 'pdf', 'tiff']);
    expect(buildConversionRequest({ ...base, palette: 'grey' }).style.grayscale).toBe(true);
    expect(buildConversionRequest({ ...base, headings: true }).style.headings).toBe(false);
    expect(buildConversionRequest({ ...base, mode: 'rmd', headings: true }).style.headings).toBe(true);
  });
  it('normalises one-element vectors that R sends as scalars', () => {
    expect(asArray('a')).toEqual(['a']);
    expect(asArray(null)).toEqual([]);
    const scan = normaliseScan({ refused: false,
      findings: [{ code: 'asis_output', message: 'm', lines: 4, refuse: false }], chunks: 2, inline_expressions: 0,
      packages: 'jmv' } as unknown as ScanResult);
    expect(scan.findings[0].lines).toEqual([4]);
    expect(scan.packages).toEqual(['jmv']);
    const result = normaliseResult({ status: 'complete', text: '', analyses: [], diagnostics: [],
      manifest: { plots: [{ id: 'p', files: 'figures/a.png', packages: 'ggdist' }], packages: 'ggdist' },
    } as unknown as ConversionResult);
    expect(result.manifest.plots[0].files).toEqual(['figures/a.png']);
    expect(result.manifest.packages).toEqual(['ggdist']);
  });
  it('installs only valid packages of ggplot2 figures for a preview', () => {
    const plots = [
      { analysis_id: 'a1', engine: 'ggplot2', packages: ['ggdist', 'BetterGG', 'ggrepel'] },
      { analysis_id: 'a1', engine: 'bettergg', packages: ['ggstatsplot'] },
      { analysis_id: 'a2', engine: 'ggplot2', packages: ['patchwork'] },
    ] as PlotInfo[];
    expect(previewPackages(plots, 'a1')).toEqual(['ggdist', 'ggrepel']);
    expect(cleanPackages(['jmv2gg', 'x"); system("y', 'knitr'])).toEqual(['knitr']);
    expect(rVector(['knitr', 'markdown'])).toBe('c("knitr", "markdown")');
  });
});

describe('report data files', () => {
  const MB = 1024 * 1024;
  it('sanitises names to letters, digits, dot, dash and underscore', () => {
    expect(sanitizeFileName('my data (v2).csv')).toBe('my_data__v2_.csv');
    expect(sanitizeFileName('../../etc/passwd')).toBe('passwd');
    expect(sanitizeFileName('C:\\Users\\me\\study.sav')).toBe('study.sav');
    expect(sanitizeFileName('..')).toBe('_');
    expect(sanitizeFileName('.hidden')).toBe('_hidden');
    expect(sanitizeFileName('')).toBe('data');
    expect(sanitizeFileName('données.csv')).toMatch(/^[A-Za-z0-9._-]+$/);
  });
  it('enforces 100 MB per file, 300 MB together, and distinct safe names', () => {
    expect(checkDataFiles([{ name: 'a.csv', size: 100 * MB }])).toEqual({ ok: true, names: ['a.csv'] });
    expect(checkDataFiles([{ name: 'a.csv', size: 100 * MB + 1 }]).ok).toBe(false);
    const three = [1, 2, 3].map(i => ({ name: `${i}.csv`, size: 100 * MB }));
    expect(checkDataFiles(three).ok).toBe(true);
    expect(checkDataFiles([...three, { name: '4.csv', size: 1 }]).ok).toBe(false);
    expect(checkDataFiles([{ name: 'a b.csv', size: 1 }, { name: 'a_b.csv', size: 1 }]).ok).toBe(false);
    expect(checkDataFiles([{ name: 'report.Rmd', size: 1 }]).ok).toBe(false);
    expect(checkDataFiles([])).toEqual({ ok: true, names: [] });
  });
});

describe('render state machine', () => {
  const finding = { code: 'source_or_download', message: 'm', lines: [3], refuse: false };
  const scan: ScanResult = {
    refused: false, findings: [finding, { ...finding, lines: [9] }], chunks: 3, inline_expressions: 1, packages: [],
  };
  const refused: ScanResult = {
    ...scan, refused: true, findings: [{ ...finding, code: 'other_engine', refuse: true }],
  };
  const run = (...events: Parameters<typeof renderReducer>[1][]) => events.reduce<RenderState>(renderReducer, idle);
  it('goes idle -> scanned -> confirmed -> rendering -> done', () => {
    expect(run({ type: 'scanned', scan }).phase).toBe('scanned');
    expect(canStart(run({ type: 'scanned', scan }))).toBe(false);
    expect(run({ type: 'scanned', scan }, { type: 'start' }).phase).toBe('scanned');
    expect(run({ type: 'scanned', scan }, { type: 'confirm', value: true }).phase).toBe('confirmed');
    const done = run({ type: 'scanned', scan }, { type: 'confirm', value: true }, { type: 'start' },
      { type: 'succeed', html: '<p/>' });
    expect(done).toEqual({ phase: 'done', scan, html: '<p/>' });
  });
  it('records failures and cancellations only while rendering', () => {
    const rendering = run({ type: 'scanned', scan }, { type: 'confirm', value: true }, { type: 'start' });
    expect(renderReducer(rendering, { type: 'fail', error: 'R error' }))
      .toMatchObject({ phase: 'failed', error: 'R error' });
    expect(renderReducer(rendering, { type: 'cancel', reason: 'stopped' })).toMatchObject({ phase: 'cancelled' });
    const cancelled = renderReducer(rendering, { type: 'cancel', reason: 'stopped' });
    // A late result from a cancelled render is ignored.
    expect(renderReducer(cancelled, { type: 'succeed', html: 'late' }).phase).toBe('cancelled');
    expect(renderReducer(cancelled, { type: 'fail', error: 'late' }).phase).toBe('cancelled');
    expect(canStart(cancelled)).toBe(true);
    expect(renderReducer(idle, { type: 'cancel', reason: 'x' })).toBe(idle);
  });
  it('never confirms or starts a refused document', () => {
    const state = run({ type: 'scanned', scan: refused }, { type: 'confirm', value: true }, { type: 'start' });
    expect(state.phase).toBe('scanned');
  });
  it('requires a new confirmation after unticking or a new scan', () => {
    const confirmed = run({ type: 'scanned', scan }, { type: 'confirm', value: true });
    expect(renderReducer(confirmed, { type: 'confirm', value: false }).phase).toBe('scanned');
    expect(renderReducer(confirmed, { type: 'scanned', scan }).phase).toBe('scanned');
    expect(renderReducer(confirmed, { type: 'reset' })).toBe(idle);
  });
  it('sends each confirmed finding code once', () => {
    expect(confirmedCodes(scan)).toEqual(['source_or_download']);
  });
});

describe('reproducibility bundle', () => {
  it('leaves simulated previews out of the ZIP', () => {
    const files = [{ path: 'figures/a.png', url: '', bytes: new Uint8Array(), simulated: true },
      { path: 'figures/b.png', url: '', bytes: new Uint8Array(), simulated: false }];
    expect(bundledFigures(files).map(file => file.path)).toEqual(['figures/b.png']);
  });
});

describe('version shown in the footer', () => {
  it('matches package.json', async () => {
    const { readFile } = await import('node:fs/promises');
    const pkg = JSON.parse(await readFile(new URL('../package.json', import.meta.url), 'utf8'));
    const layout = await readFile(new URL('../src/components/Layout.tsx', import.meta.url), 'utf8');
    expect(layout).toContain(`jmv2gg · version ${pkg.version}`);
  });
});
