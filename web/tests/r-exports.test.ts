import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

// The browser calls jmv2gg::<name>; a function missing from NAMESPACE only fails at run time in WebR
// (the 0.2.0 report preview failed this way while every native test passed).
function sources(dir: string): string[] {
  return readdirSync(dir).flatMap(name => {
    const path = join(dir, name);
    return statSync(path).isDirectory() ? sources(path) : /\.tsx?$/.test(name) ? [path] : [];
  });
}

describe('R functions called by the web app', () => {
  it('are all exported by the jmv2gg NAMESPACE', () => {
    const namespace = readFileSync(join(__dirname, '../../NAMESPACE'), 'utf8');
    const exported = new Set([...namespace.matchAll(/^export\(([^)]+)\)/gm)].map(match => match[1]));
    const called = new Set(sources(join(__dirname, '../src'))
      .flatMap(path => [...readFileSync(path, 'utf8').matchAll(/jmv2gg::([A-Za-z_.][A-Za-z0-9_.]*)/g)])
      .map(match => match[1]));
    expect(called.size).toBeGreaterThan(0);
    expect([...called].filter(name => !exported.has(name))).toEqual([]);
  });
});
