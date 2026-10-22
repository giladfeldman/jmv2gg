import JSZip from 'jszip';
import type { ConversionResult, Mode, PreviewFile } from '../types';

export const renderInstructions = `# Run in native R after installing jmv2gg and the plotting packages.
# Retain the data files referenced by your document.
jmv2gg::render_report("converted.Rmd", output_dir = "report")
`;

const readme = `jmv2gg reproducibility bundle

Input data is not included. Retain the data files referenced by your source.
The reference HTML report is rendered in native R; the in-browser report is a preview.
Inspect conversion.json for limitations and additional tests.
`;

export function convertedName(mode: Mode) {
  return mode === 'rmd' ? 'converted.Rmd' : 'converted.R';
}

/** Figures that go into the ZIP: never ones drawn from simulated values. */
export function bundledFigures(previews: PreviewFile[]) {
  return previews.filter(file => !file.simulated);
}

/**
 * The ZIP holds the converted source, the conversion record, the runtime provenance and
 * figures drawn from the user's own data. It never holds the user's data files.
 */
export async function buildBundle(mode: Mode, result: ConversionResult, previews: PreviewFile[]) {
  const zip = new JSZip();
  zip.file(convertedName(mode), result.text);
  zip.file('conversion.json', JSON.stringify({
    analyses: result.analyses, diagnostics: result.diagnostics, manifest: result.manifest,
  }, null, 2));
  const environment = await fetch('/locks/packages.json');
  const build = await fetch('/r-packages/build-manifest.json');
  if (!environment.ok || !build.ok) throw new Error('Runtime provenance could not be loaded.');
  zip.file('browser-environment.json', JSON.stringify({
    dependencies: await environment.json(), converter: await build.json(),
  }, null, 2));
  if (mode === 'rmd') zip.file('render.R', renderInstructions);
  zip.file('README.txt', readme);
  for (const file of bundledFigures(previews)) zip.file(file.path, file.bytes);
  return zip.generateAsync({ type: 'blob', compression: 'DEFLATE' });
}
