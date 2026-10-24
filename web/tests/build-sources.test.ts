import { createHash } from 'node:crypto';
import { readdirSync, readFileSync } from 'node:fs';
import { relative, resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

// The build manifest hashes the sources as they sit on disk, and the hosted build hashes a fresh
// LF checkout (.gitattributes eol=lf). A Windows CRLF copy hashed locally stopped the 0.2.0 deploy.
const root = resolve(__dirname, '..', '..');
const manifest = JSON.parse(readFileSync(resolve(__dirname, '..', 'public', 'r-packages', 'build-manifest.json'), 'utf8'));

describe('sources hashed into the browser package', () => {
  it('use LF line endings, as the hosted checkout does', () => {
    const crlf = Object.keys(manifest.sources).filter(path => readFileSync(resolve(root, path)).includes('\r\n'));
    expect(crlf).toEqual([]);
  });
});

// tools/webr/build.R reuses a published dependency binary while this fingerprint matches its source
// (file list in C order, each file hashed without carriage returns, as in source_fingerprint()).
function fingerprint(dir: string) {
  const walk = (d: string): string[] => readdirSync(d, { withFileTypes: true })
    .flatMap(entry => entry.isDirectory() ? walk(resolve(d, entry.name)) : [resolve(d, entry.name)]);
  const files = walk(dir).map(file => relative(dir, file).replace(/\\/g, '/'))
    .filter(file => /^(DESCRIPTION|NAMESPACE|LICENSE|R\/|inst\/|man\/|src\/|data\/)/.test(file))
    .sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  const sha = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');
  const lines = files.map(file => `${file} ${sha(Buffer.from(readFileSync(resolve(dir, file)).filter(byte => byte !== 13)))}`);
  return sha(Buffer.from(lines.map(line => `${line}\n`).join('')));
}

describe('published dependency binaries', () => {
  it('record the source they were built from, so an unchanged source reuses them', () => {
    expect(manifest.dependencies.BetterGG.source).toMatch(/^[0-9a-f]{64}$/);
    expect(manifest.placeholders.websocket.source)
      .toBe(fingerprint(resolve(root, 'tools', 'webr', 'placeholders', 'websocket')));
  });
});
