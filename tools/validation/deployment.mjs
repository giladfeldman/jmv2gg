// Anonymous-only static probes. Real-browser checks are required separately.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
const origin = new URL(process.env.JMV2GG_APP_URL || 'https://jmv2gg.vercel.app');
const revision = process.env.JMV2GG_EXPECTED_REVISION || execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
const manifest = JSON.parse(await readFile('web/public/r-packages/build-manifest.json', 'utf8'));
const get = (path, init) => fetch(new URL(path, origin), { ...init, signal: AbortSignal.timeout(30_000) });
const root = await get('/');
assert.equal(root.status, 200, 'Public page must work without authentication.');
assert.equal(root.headers.get('cross-origin-opener-policy'), 'same-origin');
assert.equal(root.headers.get('cross-origin-embedder-policy'), 'require-corp');
assert.equal(root.headers.get('x-content-type-options'), 'nosniff');
assert.match(root.headers.get('content-security-policy') || '', /form-action 'none'/);
assert.match(await root.text(), /jmv2gg/);
const buildResponse = await get('/build-info.json');
assert.equal(buildResponse.status, 200);
const build = await buildResponse.json();
assert.equal(build.revision, revision, 'Live revision must match the release commit.');
assert.equal(build.sourceTreeDirty, false, 'Released source must be clean; provider metadata changes are disclosed separately.');
assert.equal(build.converterVersion, '0.1.0');
assert.equal(build.webRVersion, '0.6.0');
assert.equal(build.converterArtifactSha256, manifest.sha256);
assert.ok(Number.isFinite(Date.parse(build.builtAt)));
const binary = await get(`/r-packages/${manifest.artifact}`);
assert.equal(binary.status, 200);
assert.equal(createHash('sha256').update(new Uint8Array(await binary.arrayBuffer())).digest('hex'), manifest.sha256);
const lock = await get('/locks/packages.dcf');
assert.equal(lock.status, 200);
assert.equal(await lock.text(), await readFile('web/public/locks/packages.dcf', 'utf8'));
for (const path of ['/.env', '/.git/config', '/wp-login.php']) {
  assert.equal((await get(path)).status, 403, `Scanner path ${path} must be denied.`);
}
assert.equal((await get('/', { headers: { 'User-Agent': 'GPTBot/1.0' } })).status, 403);
console.log(JSON.stringify({ status: 'PASS', origin: origin.origin, build, browserChecks: 'Required separately' }, null, 2));
