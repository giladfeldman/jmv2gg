import { describe, expect, it, vi } from 'vitest';
import type { ConversionRequest } from './types';
const initMock = vi.hoisted(() => vi.fn(async () => {}));
vi.mock('webr', () => ({ WebR: class {
  init = initMock; installPackages = async () => {};
  FS = { mkdir: async () => {}, writeFile: async () => {} }; evalRVoid = async () => {};
  evalR = async () => ({ exec: async () => ({ toString: async () => JSON.stringify({ status: 'complete', analyses: [], diagnostics: [], manifest: { converted: 1 } }) }) });
  destroy() { throw new Error("Can't find object in shelter."); }
  close() {}
} }));
import { RWorkbench } from './runtime';
describe('workbench transport', () => {
  it('retains successful results from unmanaged function calls', async () => {
    vi.stubGlobal('location', { origin: 'http://localhost' });
    vi.stubGlobal('fetch', async () => ({ ok: true, arrayBuffer: async () => new ArrayBuffer(0) }));
    const runtime = new RWorkbench(() => {});
    const result = await runtime.convert({ source: '', mode: 'code', action: 'convert', engine: 'ggplot2' } as ConversionRequest);
    expect(result.status).toBe('complete');
    expect(result.manifest.converted).toBe(1);
  });
  it('reports a startup timeout instead of waiting indefinitely', async () => {
    vi.useFakeTimers();
    initMock.mockImplementationOnce(() => new Promise<void>(() => {}));
    const runtime = new RWorkbench(() => {});
    const pending = expect(runtime.initialize()).rejects.toThrow('within three minutes');
    await vi.advanceTimersByTimeAsync(180_000);
    await pending;
    vi.useRealTimers();
  });
});
