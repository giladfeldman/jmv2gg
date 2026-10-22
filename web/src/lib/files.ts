const MB = 1024 * 1024;

export const limits = {
  source: 5 * MB,
  previewData: 100 * MB,
  renderFile: 100 * MB,
  renderTotal: 300 * MB,
};

// The render folder already holds these; a data file must not replace them.
const reservedNames = ['report.Rmd', 'report.html', 'report.preview.md'];

/** Keep only [A-Za-z0-9._-]; anything else becomes "_" so names stay inside the render folder. */
export function sanitizeFileName(name: string) {
  const base = name.split(/[\\/]/).at(-1) ?? '';
  const clean = base.replace(/[^A-Za-z0-9._-]/g, '_').replace(/^\.+/, '_');
  return clean.length ? clean.slice(0, 200) : 'data';
}

export interface NamedSize { name: string; size: number }
export type DataFileCheck = { ok: true; names: string[] } | { ok: false; error: string };

/** Checks the files a report reads: each <= 100 MB, together <= 300 MB, distinct safe names. */
export function checkDataFiles(files: NamedSize[]): DataFileCheck {
  const names = files.map(file => sanitizeFileName(file.name));
  const large = files.find(file => file.size > limits.renderFile);
  if (large) return { ok: false, error: `${large.name} is larger than 100 MB. Render this report in native R.` };
  const total = files.reduce((sum, file) => sum + file.size, 0);
  if (total > limits.renderTotal) {
    return { ok: false, error: 'The data files are larger than 300 MB together. Render this report in native R.' };
  }
  const reserved = names.find(name => reservedNames.includes(name));
  if (reserved) {
    return { ok: false, error: `${reserved} is used by the preview itself. Rename that file and choose it again.` };
  }
  const duplicate = names.find((name, index) => names.indexOf(name) !== index);
  if (duplicate) {
    return { ok: false, error: `Two files would both be saved as ${duplicate}. Rename one and choose them again.` };
  }
  return { ok: true, names };
}

export function download(blob: Blob, name: string) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = name;
  document.body.append(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
