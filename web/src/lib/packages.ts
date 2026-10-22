/** Packages shipped with R itself; never installed from a repository. */
export const basePackages = new Set(['R', 'base', 'compiler', 'datasets', 'graphics', 'grDevices', 'grid', 'methods',
  'parallel', 'splines', 'stats', 'stats4', 'tcltk', 'tools', 'utils']);

export interface PackageEntry { depends: string[]; imports: string[]; linkingTo: string[] }
export type PackageDb = Map<string, PackageEntry>;

/** Parses a Debian-control (PACKAGES / packages.dcf) file: records split by blank lines, indented continuations. */
export function parseDcf(text: string): Record<string, string>[] {
  const records: Record<string, string>[] = [];
  let current: Record<string, string> = {};
  let last = '';
  for (const line of text.replace(/\r\n/g, '\n').split('\n')) {
    if (!line.trim()) {
      if (Object.keys(current).length) records.push(current);
      current = {};
      last = '';
    } else if (/^\s/.test(line) && last) {
      current[last] += ` ${line.trim()}`;
    } else {
      const colon = line.indexOf(':');
      if (colon < 1) continue;
      last = line.slice(0, colon).trim();
      current[last] = line.slice(colon + 1).trim();
    }
  }
  if (Object.keys(current).length) records.push(current);
  return records;
}

/** "ggplot2 (>= 3.5), rlang" -> ["ggplot2", "rlang"] */
export function dependencyNames(field?: string) {
  if (!field) return [];
  return field.split(',').map(item => item.replace(/\(.*?\)/g, '').trim()).filter(Boolean);
}

export function packageDb(text: string): PackageDb {
  const db: PackageDb = new Map();
  for (const record of parseDcf(text)) {
    if (!record.Package) continue;
    db.set(record.Package, {
      depends: dependencyNames(record.Depends), imports: dependencyNames(record.Imports),
      linkingTo: dependencyNames(record.LinkingTo),
    });
  }
  return db;
}

export function runtimeDependencies(entry: PackageEntry | undefined, withDepends = true) {
  if (!entry) return [];
  return [...(withDepends ? entry.depends : []), ...entry.imports, ...entry.linkingTo];
}

/**
 * The packages to install, one at a time, dependencies first. Base packages, packages that
 * are already installed (their dependencies are then installed too) and names the lock does
 * not list (optional system extras such as Rmpfr) are left out; the last are reported in `missing`.
 */
export function installOrder(roots: string[], db: PackageDb, installed: Iterable<string> = []) {
  const have = new Set(installed);
  const order: string[] = [];
  const missing: string[] = [];
  const seen = new Set<string>();
  const visit = (name: string) => {
    if (seen.has(name) || basePackages.has(name) || have.has(name)) return;
    seen.add(name);
    const entry = db.get(name);
    if (!entry) { missing.push(name); return; }
    for (const dependency of runtimeDependencies(entry)) visit(dependency);
    order.push(name);
  };
  roots.forEach(visit);
  return { order, missing };
}
