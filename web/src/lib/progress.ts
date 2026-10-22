/**
 * Progress for long operations (starting WebR, installing packages, converting, rendering):
 * phases, counted items, elapsed time and approximate time estimates. Durations measured on
 * this device are kept in localStorage so the next run can estimate from the start.
 */

export const timingPrefix = 'jmv2gg.timing.';
const keep = 5;

export interface PhaseSpec { id: string; label: string }
export type PhaseStatus = 'done' | 'skipped' | 'current' | 'pending';

export interface ProgressSnapshot {
  title: string;
  phases: (PhaseSpec & { status: PhaseStatus })[];
  phaseIndex: number;
  message: string;
  done?: number;
  total?: number;
  item?: string;
  startedAt: number;
  phaseStartedAt: number;
  /** Time at which the current step should end; undefined while estimating. */
  stepEndsAt?: number;
  /** Time at which the whole job should end, when every remaining phase has a history. */
  jobEndsAt?: number;
  /** "usually about 20 s here", from this device's history of the current phase. */
  usual?: string;
}

export function median(values: number[]) {
  if (!values.length) return undefined;
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

type Store = Pick<Storage, 'getItem' | 'setItem'> | null | undefined;

/** localStorage when the browser allows it; never throws (private modes, blocked storage, tests). */
export function defaultStore(): Store {
  try { return typeof localStorage === 'undefined' ? null : localStorage; } catch { return null; }
}

export function readTimings(store: Store, key: string): number[] {
  try {
    const value = JSON.parse(store?.getItem(timingPrefix + key) ?? '[]');
    if (!Array.isArray(value)) return [];
    return value.filter(item => typeof item === 'number' && Number.isFinite(item) && item >= 0);
  } catch { return []; }
}

export function recordTiming(store: Store, key: string, ms: number) {
  if (!Number.isFinite(ms) || ms < 0) return;
  try { store?.setItem(timingPrefix + key, JSON.stringify([...readTimings(store, key), Math.round(ms)].slice(-keep))); }
  catch { /* storage full or blocked: estimates simply start from scratch next time */ }
}

export function usualMs(store: Store, key: string) {
  return median(readTimings(store, key));
}

/**
 * Remaining milliseconds of a counted step. Uses the average of the finished items once two are
 * done; before that, this device's history for each remaining item (if every one has one).
 */
export function countedRemainingMs(finished: number[], remaining: (number | undefined)[], inCurrentMs = 0) {
  if (!remaining.length) return 0;
  const average = finished.length >= 2 ? finished.reduce((sum, value) => sum + value, 0) / finished.length : undefined;
  let total = 0;
  for (const known of remaining) {
    const value = known ?? average;
    if (value === undefined) return undefined;
    total += value;
  }
  return Math.max(0, total - inCurrentMs);
}

/** "jmv2gg-progress 3 21 confirmatory" -> { done: 3, total: 21, label: "confirmatory" } */
export function parseProgressLine(line: string) {
  const match = /^jmv2gg-progress (\d+) (\d+)(?: (.*))?$/.exec(line.trim());
  if (!match) return undefined;
  const done = Number(match[1]);
  const total = Number(match[2]);
  if (!Number.isSafeInteger(done) || !Number.isSafeInteger(total) || total < 0) return undefined;
  return { done, total, label: (match[3] ?? '').trim() };
}

export function formatDuration(ms: number) {
  const seconds = Math.max(0, Math.round(ms / 1000));
  if (seconds < 60) return `${seconds} s`;
  const minutes = Math.floor(seconds / 60);
  return `${minutes}:${String(seconds % 60).padStart(2, '0')}`;
}

/** Plain-language remaining time, always rounded up and labelled "about". */
export function formatRemaining(ms: number) {
  if (ms < 60_000) return `about ${Math.max(5, Math.ceil(ms / 10_000) * 10)} s left`;
  const minutes = Math.ceil(ms / 60_000);
  return `about ${minutes} min left`;
}

export interface TrackerOptions { now?: () => number; store?: Store }

/**
 * Collects progress for one job and reports snapshots. After cancel() nothing is reported or
 * recorded, so a stopped job cannot overwrite the next one or teach wrong timings.
 */
export class ProgressTracker {
  private readonly now: () => number;
  private readonly store: Store;
  private readonly specs: PhaseSpec[];
  private statuses: PhaseStatus[];
  private index = -1;
  private state: ProgressSnapshot;
  private items: string[] = [];
  private itemKind = '';
  private finishedItems: number[] = [];
  private itemStartedAt = 0;
  private active = true;
  constructor(title: string, phases: PhaseSpec[], private onChange: (snapshot: ProgressSnapshot) => void,
    options: TrackerOptions = {}) {
    this.now = options.now ?? (() => Date.now());
    this.store = options.store === undefined ? defaultStore() : options.store;
    this.specs = phases;
    this.statuses = phases.map(() => 'pending');
    const start = this.now();
    this.state = {
      title, phases: this.phaseList(), phaseIndex: 0, message: 'Starting…', startedAt: start, phaseStartedAt: start,
    };
  }
  private phaseList() { return this.specs.map((spec, i) => ({ ...spec, status: this.statuses[i] })); }
  private emit(patch: Partial<ProgressSnapshot>) {
    if (!this.active) return;
    this.state = { ...this.state, ...patch, phases: this.phaseList() };
    this.state.jobEndsAt = this.jobEnd();
    this.onChange(this.state);
  }
  private jobEnd() {
    if (this.state.stepEndsAt === undefined) return undefined;
    let end = this.state.stepEndsAt;
    for (let i = this.index + 1; i < this.specs.length; i++) {
      const usual = usualMs(this.store, `phase.${this.specs[i].id}`);
      if (usual === undefined) return undefined;
      end += usual;
    }
    return end;
  }
  private closePhase(status: PhaseStatus) {
    if (this.index < 0) return;
    if (status === 'done') {
      recordTiming(this.store, `phase.${this.specs[this.index].id}`, this.now() - this.state.phaseStartedAt);
    }
    this.statuses[this.index] = status;
  }
  /** Moves to a phase. Phases passed over were not needed this time (for example R was already running). */
  phase(id: string, message?: string) {
    if (!this.active) return;
    const next = this.specs.findIndex(spec => spec.id === id);
    if (next < 0 || next === this.index) { if (message) this.step(message); return; }
    this.closePhase('done');
    for (let i = this.index + 1; i < next; i++) this.statuses[i] = 'skipped';
    this.index = next;
    this.statuses[next] = 'current';
    this.items = []; this.finishedItems = [];
    const now = this.now();
    const usual = usualMs(this.store, `phase.${id}`);
    this.emit({ phaseIndex: next, message: message ?? this.specs[next].label, phaseStartedAt: now,
      done: undefined, total: undefined, item: undefined,
      stepEndsAt: usual === undefined ? undefined : now + usual,
      usual: usual === undefined ? undefined : `usually about ${formatDuration(usual)} on this device` });
  }
  step(message: string) { this.emit({ message }); }
  /** Starts a counted list (packages); each item's duration is remembered under `${kind}.${name}`. */
  begin(names: string[], kind = 'pkg') {
    this.items = names; this.itemKind = kind; this.finishedItems = [];
    this.itemStartedAt = this.now();
    this.emit({ done: 0, total: names.length, item: names[0], stepEndsAt: this.countedEnd(0) });
  }
  /** Marks `done` items of the list finished; the next one is in progress. */
  advance(done: number) {
    const now = this.now();
    if (done > 0 && this.items[done - 1] !== undefined) {
      const ms = now - this.itemStartedAt;
      this.finishedItems.push(ms);
      if (this.active) recordTiming(this.store, `${this.itemKind}.${this.items[done - 1]}`, ms);
    }
    this.itemStartedAt = now;
    this.emit({ done, total: this.items.length, item: this.items[done], stepEndsAt: this.countedEnd(done) });
  }
  /**
   * Counts without names (report chunks), from the lines R writes as each chunk STARTS:
   * chunk `started` of `total` is running, so `started - 1` are finished.
   */
  count(started: number, total: number, label: string, message: string) {
    const now = this.now();
    const finished = Math.max(0, started - 1);
    if (this.state.done !== undefined && finished > this.state.done) this.finishedItems.push(now - this.itemStartedAt);
    this.itemStartedAt = now;
    const left = Math.max(0, total - finished);
    const remaining = countedRemainingMs(this.finishedItems, Array<undefined>(left).fill(undefined));
    this.emit({ done: finished, total, item: label, message,
      stepEndsAt: remaining === undefined ? undefined : now + remaining });
  }
  private countedEnd(done: number) {
    const left = this.items.slice(done).map(name => usualMs(this.store, `${this.itemKind}.${name}`));
    const remaining = countedRemainingMs(this.finishedItems, left);
    return remaining === undefined ? undefined : this.now() + remaining;
  }
  finish() { if (!this.active) return; this.closePhase('done'); this.active = false; }
  cancel() { this.active = false; }
  get snapshot() { return this.state; }
}
