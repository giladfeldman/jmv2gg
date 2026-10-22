import { useEffect, useState } from 'react';
import { formatDuration, formatRemaining, type ProgressSnapshot } from '../lib/progress';

interface Props {
  progress: ProgressSnapshot;
  cancelLabel?: string;
  onCancel?: () => void;
  /** Fixed clock for tests; the live panel ticks every second. */
  now?: number;
}

/** Remaining-time text: an approximate estimate when one exists, otherwise "estimating…". */
export function remainingText(progress: ProgressSnapshot, now: number) {
  const end = progress.jobEndsAt ?? progress.stepEndsAt;
  if (end === undefined) return 'estimating…';
  const left = end - now;
  if (left <= 0) return 'taking longer than usual, still working…';
  return `${formatRemaining(left)}${progress.jobEndsAt !== undefined ? ' in total' : ' in this step'} (approximate)`;
}

const marks = { done: '✓', skipped: '–', current: '›', pending: '' };

export function ProgressPanel({ progress, cancelLabel = 'Cancel', onCancel, now: fixed }: Props) {
  const [tick, setTick] = useState(() => Date.now());
  useEffect(() => {
    if (fixed !== undefined) return;
    const timer = setInterval(() => setTick(Date.now()), 1000);
    return () => clearInterval(timer);
  }, [fixed]);
  const now = fixed ?? tick;
  const counted = progress.total !== undefined && progress.total > 0;
  const current = progress.phases[progress.phaseIndex];
  return <section className="progress-panel respects-reduced-motion" aria-labelledby="progress-title">
    <div className="progress-head">
      <h3 id="progress-title">{progress.title}</h3>
      {onCancel && <button onClick={onCancel}>{cancelLabel}</button>}
    </div>
    <p className="progress-step" aria-live="polite">
      {progress.phases.length > 0 && <strong>Step {progress.phaseIndex + 1} of {progress.phases.length}
        {current ? `: ${current.label}` : ''}. </strong>}
      {progress.message}
    </p>
    {counted
      ? <progress key="counted" className="progress-bar" value={progress.done ?? 0} max={progress.total}
        aria-label={`${progress.done ?? 0} of ${progress.total} done`}/>
      : <progress key="working" className="progress-bar indeterminate" aria-label="Working"/>}
    <p className="progress-time">
      <span>Elapsed {formatDuration(now - progress.startedAt)}</span>
      <span>{remainingText(progress, now)}</span>
    </p>
    {progress.usual && <p className="progress-usual">This step is {progress.usual} (approximate).</p>}
    {progress.phases.length > 1 && <ol className="progress-phases">
      {progress.phases.map(phase => <li key={phase.id} className={phase.status}
        aria-current={phase.status === 'current' ? 'step' : undefined}>
        <span className="phase-mark" aria-hidden="true">
          {marks[phase.status]}
        </span>
        {phase.label}
        {phase.status === 'skipped' && <small> (already done)</small>}
        {phase.status === 'done' && <span className="sr-only"> (finished)</span>}
      </li>)}
    </ol>}
  </section>;
}
