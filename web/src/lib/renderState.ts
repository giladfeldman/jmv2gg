import type { ScanResult } from '../types';

/**
 * The browser report preview, as a small state machine:
 * idle -> scanned -> confirmed -> rendering -> done | failed | cancelled.
 * A refused scan stays at "scanned"; nothing can start from there.
 */
export type RenderState =
  | { phase: 'idle' }
  | { phase: 'scanned'; scan: ScanResult }
  | { phase: 'confirmed'; scan: ScanResult }
  | { phase: 'rendering'; scan: ScanResult }
  | { phase: 'done'; scan: ScanResult; html: string }
  | { phase: 'failed'; scan: ScanResult; error: string }
  | { phase: 'cancelled'; scan: ScanResult; reason: string };

export type RenderEvent =
  | { type: 'scanned'; scan: ScanResult }
  | { type: 'confirm'; value: boolean }
  | { type: 'start' }
  | { type: 'succeed'; html: string }
  | { type: 'fail'; error: string }
  | { type: 'cancel'; reason: string }
  | { type: 'reset' };

export const idle: RenderState = { phase: 'idle' };

/** Phases in which the user has confirmed the scan, so a (re)render may start. */
const confirmedPhases = ['confirmed', 'done', 'failed', 'cancelled'] as const;

export function isConfirmed(state: RenderState) {
  return (confirmedPhases as readonly string[]).includes(state.phase) || state.phase === 'rendering';
}

export function canStart(state: RenderState) {
  return (confirmedPhases as readonly string[]).includes(state.phase);
}

export function renderReducer(state: RenderState, event: RenderEvent): RenderState {
  switch (event.type) {
    case 'reset':
      return idle;
    case 'scanned':
      // A new scan always needs a new confirmation.
      return { phase: 'scanned', scan: event.scan };
    case 'confirm':
      if (state.phase === 'idle' || state.phase === 'rendering') return state;
      if (!event.value) return { phase: 'scanned', scan: state.scan };
      return state.scan.refused || state.phase !== 'scanned' ? state : { phase: 'confirmed', scan: state.scan };
    case 'start':
      return canStart(state) && state.phase !== 'idle' ? { phase: 'rendering', scan: state.scan } : state;
    case 'succeed':
      return state.phase === 'rendering' ? { phase: 'done', scan: state.scan, html: event.html } : state;
    case 'fail':
      return state.phase === 'rendering' ? { phase: 'failed', scan: state.scan, error: event.error } : state;
    case 'cancel':
      return state.phase === 'rendering' ? { phase: 'cancelled', scan: state.scan, reason: event.reason } : state;
  }
}

/** Codes of the findings the user confirmed; R checks this list again before running anything. */
export function confirmedCodes(scan: ScanResult) {
  return [...new Set(scan.findings.map(finding => finding.code))];
}
