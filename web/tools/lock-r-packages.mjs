// Explicit maintenance operation. Normal builds consume the committed lock.
import { mkdir, writeFile } from 'node:fs/promises';
const repository = 'https://repo.r-wasm.org/bin/emscripten/contrib/4.6';
const response = await fetch(`${repository}/PACKAGES`);
if (!response.ok) throw new Error(`Package index: HTTP ${response.status}`);
const blocks = (await response.text()).replaceAll('\r\n', '\n').trim().split(/\n\s*\n/);
const entries = new Map();
for (const block of blocks) {
  const fields = {}; let field;
  for (const line of block.split('\n')) {
    const match = line.match(/^([^\s:]+):\s*(.*)$/);
    if (match) { field = match[1]; fields[field] = match[2]; }
    else if (field) fields[field] += ` ${line.trim()}`;
  }
  entries.set(fields.Package, { block, fields });
}
const base = new Set(['R','base','compiler','datasets','graphics','grDevices','grid','methods','parallel','splines','stats','stats4','tcltk','tools','utils']);
const wanted = new Set();
function visit(name) {
  if (base.has(name) || wanted.has(name)) return;
  const entry = entries.get(name); if (!entry) throw new Error(`Missing mandatory dependency: ${name}`);
  wanted.add(name);
  for (const key of ['Depends','Imports','LinkingTo']) {
    for (const dependency of (entry.fields[key] ?? '').split(',')) {
      const target = dependency.replace(/\([^)]*\)/g, '').trim(); if (target) visit(target);
    }
  }
}
for (const name of ['jsonlite','yaml','ggplot2','emmeans','haven']) visit(name);
const names = [...wanted].sort();
const dcf = names.map(name => `${entries.get(name).block}\nRepository: ${repository}`).join('\n\n') + '\n';
await mkdir('public/locks', { recursive: true });
await writeFile('public/locks/packages.dcf', dcf);
await writeFile('public/locks/packages.json', JSON.stringify({ webR:'0.6.0', r:'4.6', repository,
  packages:names.map(name => ({name, version:entries.get(name).fields.Version, file:entries.get(name).fields.File ?? `${name}_${entries.get(name).fields.Version}.tgz`})) }, null, 2) + '\n');
console.log(`Locked ${names.length} mandatory packages. No binary packages were redistributed.`);
