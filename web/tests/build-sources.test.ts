import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
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
