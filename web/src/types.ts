export type Engine = 'ggplot2' | 'bettergg' | 'both';
export type Mode = 'code' | 'rmd';
export interface ConversionRequest {
  action: 'convert' | 'preview'; mode: Mode; source: string; engine: Engine;
  original_output: 'include' | 'hide'; html_preset: 'enhanced' | 'preserve';
  style: { show_violin: boolean; show_jitter: boolean; grayscale: boolean; jitter_width: number; jitter_height: number; verbose: boolean };
  figures: { dpi: number; width: number; height: number };
  analysis_id?: string; data_kind?: 'simulate' | 'file'; data_path?: string; n?: number; categorical?: string[];
}
export interface Analysis { id: string; function_name: string; status: string; line: number; heading?: string; mapping?: string }
export interface Diagnostic { severity: string; code: string; message: string; analysis_id?: string; line?: number }
export interface PlotInfo { id: string; analysis_id: string; engine: Engine; filename: string; statistical_note?: string }
export interface ConversionResult {
  status: 'complete' | 'partial' | 'failed'; text: string; analyses: Analysis[]; diagnostics: Diagnostic[];
  manifest: { version: string; engine: Engine; detected: number; converted: number; plots: PlotInfo[] };
}
export interface PreviewFile { path: string; url: string; bytes: Uint8Array; simulated: boolean }
