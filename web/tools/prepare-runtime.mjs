import { readFile, access } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
const root = resolve('..');
const manifestPath = resolve('public/r-packages/build-manifest.json');
await access(manifestPath);
const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
for (const [path, expected] of Object.entries(manifest.sources)) {
  const actual = createHash('sha256').update(await readFile(resolve(root,path))).digest('hex');
  if (actual !== expected) throw new Error(`Browser package is stale: ${path}. Rebuild with tools/webr/build.R.`);
}
const binary = await readFile(resolve('public/r-packages', manifest.artifact));
if (createHash('sha256').update(binary).digest('hex') !== manifest.sha256) throw new Error('Browser package checksum differs from its build manifest.');
await access(resolve('public/locks/packages.dcf'));
console.log('Verified browser package source hashes, binary checksum, and dependency lock.');
