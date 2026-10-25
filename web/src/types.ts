export type Engine = 'ggplot2' | 'bettergg' | 'both';
export type Mode = 'code' | 'rmd';
export type Palette = 'nejm' | 'okabe_ito' | 'grey' | 'viridis';
export type FigureSize = 'double' | 'single' | 'custom';
export type FigureFormat = 'png' | 'pdf' | 'tiff';
export type LabelMode = 'tidy' | 'names';

export interface StyleOptions {
  stats: boolean;
  palette: Palette;
  grayscale: boolean;
  verbose: boolean;
  headings: boolean;
  styler: boolean;
  /** Figure text: tidied column names (default) or the names as they are. */
  labels: LabelMode;
  label_text: Record<string, string>;
  level_text: Record<string, Record<string, string>>;
}

export interface FigureOptions {
  size: FigureSize;
  dpi: number;
  width: number;
  height: number;
  formats: FigureFormat[];
  background: string;
  optimize_png: boolean;
}

export interface ConversionRequest {
  action: 'convert' | 'preview';
  mode: Mode;
  source: string;
  engine: Engine;
  original_output: 'include' | 'hide';
  html_preset: 'enhanced' | 'preserve';
  style: StyleOptions;
  figures: FigureOptions;
  analysis_id?: string;
  data_kind?: 'simulate' | 'file';
  data_path?: string;
  n?: number;
  categorical?: string[];
}

export interface ScanRequest { action: 'scan'; source: string }

export interface Analysis {
  id: string; function_name: string; status: string; line: number; heading?: string; mapping?: string;
}
export interface Diagnostic { severity: string; code: string; message: string; analysis_id?: string; line?: number }
export interface PlotInfo {
  id: string;
  analysis_id: string;
  name: string;
  engine: Exclude<Engine, 'both'>;
  filename: string;
  files: string[];
  caption: string;
  packages: string[];
  preview: string;
  statistical_note?: string | null;
}
export interface ConversionResult {
  status: 'complete' | 'partial' | 'failed';
  text: string;
  analyses: Analysis[];
  diagnostics: Diagnostic[];
  manifest: {
    version: string; engine: Engine; detected: number; converted: number; plots: PlotInfo[]; packages: string[];
    /** Each figure column and the label the generated code gives it. */
    labels: Record<string, string>;
  };
}
export interface PreviewFile { path: string; url: string; bytes: Uint8Array; simulated: boolean }

export interface ScanFinding { code: string; message: string; lines: number[]; refuse: boolean }
export interface ScanResult {
  refused: boolean;
  findings: ScanFinding[];
  chunks: number;
  inline_expressions: number;
  packages: string[];
}
