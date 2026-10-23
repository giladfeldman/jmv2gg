import type { WebR } from 'webr';
import { cleanPackages } from './lib/requests';
import { parseProgressLine, type PhaseSpec, type ProgressTracker } from './lib/progress';
import { converterDependencies, installConverter, installFromLock, installPlaceholders, startWebR, streamR,
  type Session } from './runtime';

export const renderTimeLimitMs = 15 * 60 * 1000;
/** R's own limit inside the document run; the 15-minute browser limit also covers installs. */
export const rTimeLimitSeconds = 600;

export const renderPhases: PhaseSpec[] = [
  { id: 'start', label: 'Start a separate R session' },
  { id: 'packages', label: 'Install R packages for the report' },
  { id: 'converter', label: 'Install jmv2gg and BetterGG' },
  { id: 'files', label: 'Copy the report and data files' },
  { id: 'knit', label: 'Render the report' },
];

export interface RenderInput {
  rmd: string;
  files: { name: string; bytes: Uint8Array }[];
  packages: string[];
  needsBetterGG: boolean;
  confirmed: string[];
}

/** Applies one line of R output to the tracker; returns true for a chunk progress line. */
export function applyRenderOutput(line: string, tracker: ProgressTracker) {
  const progress = parseProgressLine(line);
  if (!progress) return false;
  const label = progress.label ? ` (${progress.label})` : '';
  tracker.count(progress.done, progress.total, progress.label,
    `Rendering: chunk ${progress.done} of ${progress.total}${label}`);
  return true;
}

/**
 * One report preview in its own, fresh WebR instance: never the conversion worker,
 * so the document's code cannot reach the converter's session (and jmv works here,
 * because styler is not loaded). close() terminates the instance.
 */
export class ReportRenderer {
  private runtime?: WebR;
  private closed = false;
  private stop?: (error: Error) => void;
  constructor(private tracker: ProgressTracker) {}
  /** Resolves with the preview HTML; rejects on an R error, the time limit or close(). */
  render(input: RenderInput): Promise<string> {
    let timer: ReturnType<typeof setTimeout> | undefined;
    const stopped = new Promise<never>((_, reject) => { this.stop = reject; });
    const limit = new Promise<never>((_, reject) => {
      timer = setTimeout(() => reject(new Error('The report did not finish within 15 minutes, so the preview '
        + 'was stopped. Render it in native R instead.')), renderTimeLimitMs);
    });
    return Promise.race([this.run(input), stopped, limit]).finally(() => { clearTimeout(timer); this.close(); });
  }
  private async run(input: RenderInput) {
    const session = await startWebR(this.tracker, () => this.closed);
    this.runtime = session.runtime;
    if (this.closed) throw new Error('Rendering was cancelled.');
    this.tracker.phase('packages', 'Finding the R packages the report needs…');
    const own = await converterDependencies(input.needsBetterGG);
    const roots = cleanPackages(['jsonlite', 'yaml', 'knitr', 'markdown', 'jmv', ...own, ...input.packages,
      ...(input.needsBetterGG ? ['ggstatsplot'] : [])]);
    await installPlaceholders(session, this.tracker);
    await installFromLock(session, roots, this.tracker, 'Installing R packages for the report');
    await installConverter(session, this.tracker);
    this.tracker.phase('files', 'Copying the report and its data files into the browser R session…');
    await session.runtime.FS.mkdir('/workspace/render');
    await session.runtime.FS.writeFile('/workspace/render/report.Rmd', new TextEncoder().encode(input.rmd));
    for (const file of input.files) await session.runtime.FS.writeFile(`/workspace/render/${file.name}`, file.bytes);
    this.tracker.phase('knit', 'Rendering the report in your browser with knitr and markdown…');
    const error = await this.knit(session, input.confirmed);
    if (error) throw new Error(error);
    this.tracker.step('Reading the rendered page…');
    const html = await session.runtime.FS.readFile('/workspace/render/report.html');
    this.tracker.finish();
    return new TextDecoder().decode(html);
  }
  /**
   * Runs the render with R's output streamed (not captured) so the per-chunk progress lines
   * that render_browser_preview(progress = TRUE) writes with message() reach the output queue,
   * which is read while R works. Errors come back as the returned string.
   */
  private async knit(session: Session, confirmed: string[]) {
    const code = `tryCatch({
      jmv2gg::render_browser_preview("/workspace/render/report.Rmd", "/workspace/render/report.html",
        confirmed = jsonlite::fromJSON(${JSON.stringify(JSON.stringify(confirmed))}),
        time_limit = ${rTimeLimitSeconds}, progress = TRUE); ""
    }, error = function(e) conditionMessage(e))`;
    return streamR(session.runtime, code, line => applyRenderOutput(line, this.tracker), () => this.closed);
  }
  /** Cancels: the pending render rejects at once and the WebR instance is terminated. */
  close(reason = 'Rendering was cancelled.') {
    if (this.closed) return;
    this.closed = true;
    this.tracker.cancel();
    this.stop?.(new Error(reason));
    this.runtime?.close();
    this.runtime = undefined;
  }
}
