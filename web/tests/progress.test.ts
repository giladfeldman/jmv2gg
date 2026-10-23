import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { installOrder, packageDb, parseDcf } from '../src/lib/packages';
import {
  ProgressTracker, countedRemainingMs, formatRemaining, median, parseProgressLine, readTimings, recordTiming,
  timingPrefix, usualMs, type ProgressSnapshot,
} from '../src/lib/progress';
import { ProgressPanel, remainingText } from '../src/components/ProgressPanel';

const dcf = `Package: ggplot2
Version: 3.5.2
Depends: R (>= 4.1)
Imports: cli, grid, rlang (>= 1.1.0), scales (>= 1.3.0),
        vctrs
Suggests: knitr

Package: scales
Imports: cli, rlang, R6
LinkingTo: cpp11

Package: rlang
Depends: R (>= 3.5.0)
Imports: utils

Package: cli
Imports: utils

Package: R6

Package: cpp11

Package: vctrs
Imports: cli, rlang, Rmpfr
`;

function memoryStore() {
  const data = new Map<string, string>();
  return {
    getItem: (key: string) => data.get(key) ?? null,
    setItem: (key: string, value: string) => { data.set(key, value); },
    data,
  };
}

describe('lock file dependencies', () => {
  it('parses continuation lines and version constraints', () => {
    const records = parseDcf(dcf);
    expect(records).toHaveLength(7);
    expect(records[0].Imports).toContain('vctrs');
    expect(packageDb(dcf).get('ggplot2')!.imports).toEqual(['cli', 'grid', 'rlang', 'scales', 'vctrs']);
  });
  it('orders the full closure dependencies first, without base or unlisted packages', () => {
    const { order, missing } = installOrder(['ggplot2'], packageDb(dcf));
    expect(order).toEqual(['cli', 'rlang', 'R6', 'cpp11', 'scales', 'vctrs', 'ggplot2']);
    for (const name of order) {
      const deps = packageDb(dcf).get(name)!;
      for (const dep of [...deps.imports, ...deps.linkingTo]) {
        if (order.includes(dep)) expect(order.indexOf(dep)).toBeLessThan(order.indexOf(name));
      }
    }
    expect(order).not.toContain('grid');
    expect(order).not.toContain('utils');
    expect(missing).toEqual(['Rmpfr']);
  });
  it('skips packages R already has', () => {
    const { order } = installOrder(['ggplot2'], packageDb(dcf), ['rlang', 'cli', 'scales']);
    expect(order).toEqual(['vctrs', 'ggplot2']);
    expect(installOrder(['ggplot2'], packageDb(dcf), ['ggplot2']).order).toEqual([]);
  });
});

describe('time estimates', () => {
  it('takes the median of recent observations', () => {
    expect(median([])).toBeUndefined();
    expect(median([30, 10, 20])).toBe(20);
    expect(median([10, 20, 30, 40])).toBe(25);
  });
  it('estimates from the average once two items are finished', () => {
    expect(countedRemainingMs([1000], [undefined, undefined])).toBeUndefined();
    expect(countedRemainingMs([1000, 3000], [undefined, undefined, undefined])).toBe(6000);
    expect(countedRemainingMs([1000, 3000], [undefined, undefined], 500)).toBe(3500);
    // History for each remaining item gives an estimate straight away.
    expect(countedRemainingMs([], [4000, 1000])).toBe(5000);
    expect(countedRemainingMs([], [])).toBe(0);
  });
  it('keeps the last five durations per key and never throws on blocked storage', () => {
    const store = memoryStore();
    for (const ms of [1, 2, 3, 4, 5, 6, 7]) recordTiming(store, 'pkg.ggplot2', ms * 1000);
    expect(readTimings(store, 'pkg.ggplot2')).toEqual([3000, 4000, 5000, 6000, 7000]);
    expect(usualMs(store, 'pkg.ggplot2')).toBe(5000);
    expect([...store.data.keys()]).toEqual([`${timingPrefix}pkg.ggplot2`]);
    const blocked = { getItem: () => { throw new Error('blocked'); }, setItem: () => { throw new Error('blocked'); } };
    expect(() => recordTiming(blocked, 'x', 1)).not.toThrow();
    expect(readTimings(blocked, 'x')).toEqual([]);
    expect(readTimings(null, 'x')).toEqual([]);
    store.setItem(`${timingPrefix}bad`, 'not json');
    expect(readTimings(store, 'bad')).toEqual([]);
  });
  it('rounds remaining time up and labels it approximate', () => {
    expect(formatRemaining(12_000)).toBe('about 20 s left');
    expect(formatRemaining(61_000)).toBe('about 2 min left');
  });
});

describe('render progress lines', () => {
  it('parses the lines R writes for each chunk', () => {
    expect(parseProgressLine('jmv2gg-progress 3 21 confirmatory'))
      .toEqual({ done: 3, total: 21, label: 'confirmatory' });
    expect(parseProgressLine('jmv2gg-progress 1 2 unnamed-chunk-1\n'))
      .toEqual({ done: 1, total: 2, label: 'unnamed-chunk-1' });
    expect(parseProgressLine('jmv2gg-progress 4 9')).toEqual({ done: 4, total: 9, label: '' });
    expect(parseProgressLine('Warning: jmv2gg-progress 3 21 x')).toBeUndefined();
    expect(parseProgressLine('jmv2gg-progress three 21 x')).toBeUndefined();
  });
});

describe('progress tracker', () => {
  it('ticks phases, counts items, learns durations and estimates the next run', () => {
    let now = 0;
    const store = memoryStore();
    const seen: ProgressSnapshot[] = [];
    const phases = [{ id: 'start', label: 'Start R' }, { id: 'packages', label: 'Install' },
      { id: 'convert', label: 'Convert' }];
    const tracker = new ProgressTracker('Converting', phases, snapshot => seen.push(snapshot),
      { now: () => now, store });
    tracker.phase('start');
    now = 20_000;
    tracker.phase('packages');
    tracker.begin(['a', 'b', 'c', 'd']);
    expect(tracker.snapshot.stepEndsAt).toBeUndefined();
    now += 1000; tracker.advance(1);
    now += 3000; tracker.advance(2);
    expect(tracker.snapshot.stepEndsAt).toBe(now + 4000);
    now += 2000; tracker.advance(3);
    now += 2000; tracker.advance(4);
    tracker.phase('convert');
    expect(tracker.snapshot.phases.map(phase => phase.status)).toEqual(['done', 'done', 'current']);
    tracker.finish();
    expect(usualMs(store, 'phase.start')).toBe(20_000);
    expect(usualMs(store, 'pkg.b')).toBe(3000);

    const next = new ProgressTracker('Again', phases, () => {}, { now: () => now, store });
    next.phase('start');
    expect(next.snapshot.usual).toBe('usually about 20 s on this device');
    expect(next.snapshot.stepEndsAt).toBe(now + 20_000);
    next.phase('packages');
    next.begin(['a', 'b']);
    expect(next.snapshot.stepEndsAt).toBe(now + 4000);
  });
  it('marks phases that were not needed as skipped, and stops reporting after cancel', () => {
    const seen: ProgressSnapshot[] = [];
    const phases = [{ id: 'start', label: 'Start' }, { id: 'convert', label: 'Convert' }];
    const tracker = new ProgressTracker('t', phases, snapshot => seen.push(snapshot), { store: null });
    tracker.phase('convert');
    expect(tracker.snapshot.phases.map(phase => phase.status)).toEqual(['skipped', 'current']);
    const count = seen.length;
    tracker.cancel();
    tracker.step('late');
    expect(seen).toHaveLength(count);
  });
  it('counts chunks as they start', () => {
    let now = 0;
    const tracker = new ProgressTracker('t', [{ id: 'knit', label: 'Render' }], () => {},
      { now: () => now, store: null });
    tracker.phase('knit');
    tracker.count(1, 4, 'setup', 'Rendering: chunk 1 of 4 (setup)');
    expect(tracker.snapshot).toMatchObject({ done: 0, total: 4, item: 'setup' });
    now = 2000; tracker.count(2, 4, 'a', 'm');
    now = 4000; tracker.count(3, 4, 'b', 'm');
    expect(tracker.snapshot.done).toBe(2);
    expect(tracker.snapshot.stepEndsAt).toBe(4000 + 2 * 2000);
  });
});

describe('progress panel', () => {
  const base: ProgressSnapshot = {
    title: 'Rendering the report preview', phaseIndex: 1, message: 'Installing R packages: 14 of 48 — ggplot2',
    startedAt: 0, phaseStartedAt: 0,
    phases: [{ id: 'start', label: 'Start', status: 'done' }, { id: 'packages', label: 'Install', status: 'current' },
      { id: 'knit', label: 'Render', status: 'pending' }],
  };
  it('shows a determinate bar when items are counted', () => {
    const progress = { ...base, done: 13, total: 48 };
    const html = renderToStaticMarkup(createElement(ProgressPanel, { progress, now: 65_000 }));
    expect(html).toMatch(/<progress[^>]*value="13"[^>]*max="48"/);
    expect(html).toContain('Step 2 of 3');
    expect(html).toContain('Elapsed 1:05');
    expect(html).toContain('estimating…');
    expect(html).toContain('aria-live="polite"');
    expect(html).toContain('aria-current="step"');
    expect(html).toContain('✓');
  });
  it('shows an indeterminate bar otherwise, with the reduced-motion class', () => {
    const html = renderToStaticMarkup(createElement(ProgressPanel, { progress: base, now: 1000 }));
    const bar = html.match(/<progress[^>]*>/)![0];
    expect(bar).not.toContain('value=');
    expect(bar).toContain('indeterminate');
    expect(html).toContain('respects-reduced-motion');
  });
  it('labels estimates as approximate', () => {
    expect(remainingText({ ...base, stepEndsAt: 200_000 }, 20_000)).toBe('about 3 min left in this step (approximate)');
    expect(remainingText({ ...base, stepEndsAt: 10_000, jobEndsAt: 100_000 }, 0))
      .toBe('about 2 min left in total (approximate)');
    expect(remainingText({ ...base, stepEndsAt: 10 }, 20)).toContain('longer than usual');
  });
});

describe('optional phases', () => {
  it('shows an optional phase that never ran as skipped when the job finishes', () => {
    const seen: ProgressSnapshot[] = [];
    const tracker = new ProgressTracker('t', [{ id: 'convert', label: 'Convert' },
      { id: 'style', label: 'Tidy', optional: true }], snapshot => seen.push(snapshot), { store: null });
    tracker.phase('convert');
    tracker.finish();
    expect(seen.at(-1)!.phases.map(phase => phase.status)).toEqual(['done', 'skipped']);
  });
});
