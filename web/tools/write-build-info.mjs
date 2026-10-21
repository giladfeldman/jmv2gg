import { execFileSync } from 'node:child_process';
import { readFile, writeFile } from 'node:fs/promises';

const pkg = JSON.parse(await readFile(new URL('../package.json', import.meta.url), 'utf8'));
const description = await readFile(new URL('../../DESCRIPTION', import.meta.url), 'utf8');
const converter = JSON.parse(await readFile(new URL('../public/r-packages/build-manifest.json', import.meta.url), 'utf8'));
const root = new URL('../../', import.meta.url);
const git = args => execFileSync('git', args, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
let localRevision = null;
let workingTreeDirty = null;
try {
  localRevision = git(['rev-parse', 'HEAD']);
  workingTreeDirty = git(['status', '--porcelain']).length > 0;
} catch { /* Provider builds may not contain Git metadata; do not claim a clean tree. */ }
const providerRevision = process.env.VERCEL_GIT_COMMIT_SHA || null;
if (providerRevision && !/^[a-f0-9]{40}$/i.test(providerRevision)) throw new Error('Invalid provider Git revision.');
if (providerRevision && localRevision && providerRevision !== localRevision) throw new Error('Provider and checkout revisions differ.');
const revision = providerRevision || localRevision;
if (!revision) throw new Error('Build identity requires a Git checkout or VERCEL_GIT_COMMIT_SHA.');
const converterVersion = description.match(/^Version:\s*(\S+)/m)?.[1];
if (!converterVersion) throw new Error('R package version is missing.');
const info = {
  revision, workingTreeDirty, builtAt: new Date().toISOString(),
  frontendVersion: pkg.version, converterVersion,
  webRVersion: pkg.dependencies.webr, converterArtifactSha256: converter.sha256,
};
await writeFile(new URL('../dist/build-info.json', import.meta.url), JSON.stringify(info, null, 2) + '\n');
console.log(`Wrote build identity for ${revision}${workingTreeDirty ? ' (uncommitted changes)' : ''}.`);
