import type {
  ConversionRequest, ConversionResult, Engine, FigureFormat, FigureOptions, FigureSize, LabelMode, Mode, Palette, PlotInfo,
  ScanFinding, ScanResult, StyleOptions,
} from '../types';

/** Everything the user can set before converting. */
export interface ConversionSettings {
  mode: Mode;
  source: string;
  engine: Engine;
  original: 'include' | 'hide';
  html: 'enhanced' | 'preserve';
  stats: boolean;
  palette: Palette;
  verbose: boolean;
  headings: boolean;
  size: FigureSize;
  width: number;
  height: number;
  dpi: number;
  formats: FigureFormat[];
  labels: LabelMode;
  labelText: Record<string, string>;
  levelText: Record<string, Record<string, string>>;
}

export const sizeWidths: Record<Exclude<FigureSize, 'custom'>, number> = { double: 7.2, single: 3.5 };

export const defaultSettings: Omit<ConversionSettings, 'mode' | 'source'> = {
  engine: 'both', original: 'include', html: 'enhanced', stats: false, palette: 'nejm', verbose: true,
  headings: false, size: 'double', width: 7.2, height: 5.4, dpi: 600, formats: ['png'],
  labels: 'tidy', labelText: {}, levelText: {},
};

/** Width sent to R: fixed for the journal column sizes, the user's value for custom. */
export function figureWidth(size: FigureSize, custom: number) {
  return size === 'custom' ? custom : sizeWidths[size];
}

/** PNG is always produced; PDF and TIFF are optional extras, in a stable order. */
export function normaliseFormats(formats: FigureFormat[]): FigureFormat[] {
  return (['png', 'pdf', 'tiff'] as FigureFormat[]).filter(format => format === 'png' || formats.includes(format));
}

export function buildConversionRequest(settings: ConversionSettings): ConversionRequest {
  const style: StyleOptions = {
    stats: settings.stats,
    palette: settings.palette,
    // R treats grayscale as the grey palette; sending both keeps the request explicit.
    grayscale: settings.palette === 'grey',
    verbose: settings.verbose,
    headings: settings.mode === 'rmd' && settings.headings,
    styler: true,
    labels: settings.labels,
    label_text: settings.labelText,
    level_text: settings.levelText,
  };
  const figures: FigureOptions = {
    size: settings.size,
    dpi: settings.dpi,
    width: figureWidth(settings.size, settings.width),
    height: settings.height,
    formats: normaliseFormats(settings.formats),
    background: 'white',
    optimize_png: false,
  };
  return {
    action: 'convert', mode: settings.mode, source: settings.source, engine: settings.engine,
    original_output: settings.original, html_preset: settings.html, style, figures,
  };
}

// jsonlite's auto_unbox turns one-element vectors into scalars; the UI always wants arrays.
export function asArray<T>(value: T | T[] | null | undefined): T[] {
  if (value === null || value === undefined) return [];
  return Array.isArray(value) ? value : [value];
}

export function normaliseResult(raw: ConversionResult): ConversionResult {
  const manifest = raw.manifest ?? ({} as ConversionResult['manifest']);
  const plots = asArray(manifest.plots).map((plot): PlotInfo => ({
    ...plot, files: asArray(plot.files), packages: asArray(plot.packages),
  }));
  return {
    ...raw,
    analyses: asArray(raw.analyses),
    diagnostics: asArray(raw.diagnostics),
    // jsonlite writes an empty named list as [], not {}.
    manifest: { ...manifest, plots, packages: asArray(manifest.packages),
      labels: Array.isArray(manifest.labels) || !manifest.labels ? {} : manifest.labels },
  };
}

export function normaliseScan(raw: ScanResult): ScanResult {
  const findings = asArray(raw.findings).map((finding): ScanFinding => ({ ...finding, lines: asArray(finding.lines) }));
  return { ...raw, refused: raw.refused === true, findings, packages: asArray(raw.packages) };
}

const packageName = /^[A-Za-z][A-Za-z0-9.]*$/;

/** Valid, unique R package names, without the ones the app installs from its own repository. */
export function cleanPackages(names: string[], exclude: string[] = ['BetterGG', 'jmv2gg']) {
  return [...new Set(names)].filter(name => packageName.test(name) && !exclude.includes(name)).sort();
}

/** Packages the ggplot2 figures of one analysis need in the browser preview. */
export function previewPackages(plots: PlotInfo[], analysisId: string) {
  return cleanPackages(plots.filter(plot => plot.analysis_id === analysisId && plot.engine === 'ggplot2')
    .flatMap(plot => plot.packages));
}

/** An R character vector literal; only names that passed cleanPackages() reach this. */
export function rVector(names: string[]) {
  return `c(${names.map(name => JSON.stringify(name)).join(', ')})`;
}
