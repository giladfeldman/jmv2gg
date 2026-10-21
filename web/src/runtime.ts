import { WebR, type RFunction, type RCharacter } from 'webr';
import type { ConversionRequest, ConversionResult, PreviewFile } from './types';

export class RWorkbench {
  private runtime?: WebR;
  private bridge?: RFunction;
  private ready?: Promise<void>;
  private plotsReady = false;
  private closed = false;
  private progress: (message: string) => void;
  constructor(progress: (message: string) => void) { this.progress = message => { if (!this.closed) progress(message); }; }
  async initialize() {
    if (this.ready) return this.ready;
    let timeout: ReturnType<typeof setTimeout> | undefined;
    this.ready = Promise.race([this.load(), new Promise<never>((_, reject) => {
      timeout = setTimeout(() => reject(new Error('WebR could not start within three minutes. Check runtime downloads or use the native R package. Clear the workspace to retry.')), 180_000);
    })]);
    try { await this.ready; } catch (error) { this.close(); throw error; }
    finally { clearTimeout(timeout); }
  }
  private async load() {
    this.progress('Starting WebR 0.6.0 on your device…');
    const runtime = new WebR({ baseUrl: 'https://webr.r-wasm.org/v0.6.0/' });
    this.runtime = runtime;
    await runtime.init();
    if (this.closed) throw new Error('Workspace cleared.');
    this.progress('Loading the R conversion package…');
    await runtime.FS.mkdir('/workspace');
    const lock = await fetch('/locks/packages.dcf');
    if (!lock.ok) throw new Error('The pinned R package dependency index could not be loaded.');
    await runtime.FS.writeFile('/workspace/packages.dcf', new Uint8Array(await lock.arrayBuffer()));
    await runtime.evalRVoid('.jmv2gg_locked <- read.dcf("/workspace/packages.dcf"); rownames(.jmv2gg_locked) <- .jmv2gg_locked[, "Package"]; webr::install(c("jsonlite", "yaml"), info=.jmv2gg_locked, quiet=TRUE)');
    await runtime.installPackages(['jmv2gg'], { repos: `${location.origin}/r-packages`, quiet: true });
    await runtime.evalRVoid('setwd("/workspace"); options(webr.show_menu=FALSE)');
    this.bridge = await runtime.evalR('function(x) tryCatch(jmv2gg::browser_request(x), error=function(e) jsonlite::toJSON(list(error=conditionMessage(e)),auto_unbox=TRUE))') as RFunction;
  }
  private async call<T>(request: ConversionRequest): Promise<T> {
    await this.initialize();
    const value = await this.bridge!.exec(JSON.stringify(request)) as RCharacter;
    const response = JSON.parse(await value.toString());
    // exec() results are not registered in WebR's root shelter. Destroying one
    // there throws and discards an otherwise successful conversion.
    if (response.error) throw new Error(response.error);
    return response as T;
  }
  async convert(request: ConversionRequest) {
    this.progress('Converting with the installed jmv2gg R package…');
    return this.call<ConversionResult>(request);
  }
  async preview(request: ConversionRequest, file?: File): Promise<PreviewFile[]> {
    await this.initialize();
    if (!this.plotsReady) {
      this.progress('Loading plotting packages. The first preview takes longer…');
      await this.runtime!.evalRVoid('webr::install(c("ggplot2", "emmeans"), info=.jmv2gg_locked, quiet=TRUE)');
      this.plotsReady = true;
    }
    if (file) {
      if (file.size > 100 * 1024 * 1024) throw new Error('This preview is limited to 100 MB data files. Use local R for larger datasets.');
      const sav = file.name.toLowerCase().endsWith('.sav');
      if (sav) { this.progress('Loading the local SAV reader…'); await this.runtime!.evalRVoid('webr::install("haven", info=.jmv2gg_locked, quiet=TRUE)'); }
      request.data_path = `/workspace/input.${sav ? 'sav' : 'csv'}`;
      await this.runtime!.FS.writeFile(request.data_path, new Uint8Array(await file.arrayBuffer()));
    }
    this.progress('Drawing figures locally and preparing PNG downloads…');
    const response = await this.call<{ files: { path: string }[]; simulated: boolean }>(request);
    const files: PreviewFile[] = [];
    for (const { path } of response.files) {
      const bytes = await this.runtime!.FS.readFile(`/workspace/${path}`);
      if (bytes.length < 8 || bytes[0] !== 137 || bytes[1] !== 80) throw new Error('The graphics device did not produce a valid PNG.');
      const url = URL.createObjectURL(new Blob([new Uint8Array(bytes)], { type: 'image/png' }));
      files.push({ path, url, bytes, simulated: response.simulated });
    }
    return files;
  }
  close() { this.closed = true; this.runtime?.close(); this.runtime = undefined; this.ready = undefined; this.bridge = undefined; this.plotsReady = false; }
}
