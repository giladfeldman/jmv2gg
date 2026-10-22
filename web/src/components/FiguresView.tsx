import { Icon } from './Icon';
import type { Analysis, PreviewFile } from '../types';

export type DataKind = 'simulate' | 'file' | 'bundled';

interface Props {
  busy: boolean;
  analyses: Analysis[];
  analysis: string;
  dataKind: DataKind;
  bundledAvailable: boolean;
  simulationN: number;
  categorical: string;
  previews: PreviewFile[];
  onAnalysis: (id: string) => void;
  onDataKind: (kind: DataKind) => void;
  onDataFile: (file?: File) => void;
  onSimulationN: (n: number) => void;
  onCategorical: (value: string) => void;
  onPreview: () => void;
  onDownload: (file: PreviewFile) => void;
}

export function FiguresView(props: Props) {
  const { busy, analysis, dataKind, previews } = props;
  const choice = (kind: DataKind, label: string) => <label>
    <input disabled={busy} type="radio" name="data" checked={dataKind === kind}
      onChange={() => props.onDataKind(kind)}/>
    {' '}{label}
  </label>;
  return <div className="preview-area">
    <div className="preview-notice">ggplot2 previews run here as PNG. BetterGG figures appear in the report preview
      and in local R.</div>
    <label>Analysis
      <select disabled={busy} value={analysis} onChange={event => props.onAnalysis(event.target.value)}>
        {props.analyses.filter(item => item.status === 'converted').map(item => <option key={item.id} value={item.id}>
          {item.id} · {item.heading ?? item.function_name}</option>)}
      </select>
    </label>
    <div className="data-choice">
      {props.bundledAvailable && choice('bundled', 'Bundled synthetic dataset')}
      {choice('simulate', 'Simulated data')}
      {choice('file', 'My local dataset')}
    </div>
    {dataKind === 'bundled' && <p className="help">replication-study.csv ships with the app. Its values are simulated,
      not research results; nothing is uploaded.</p>}
    {dataKind === 'simulate' && <label>Simulated participants
      <input disabled={busy} type="number" min="10" max="5000" value={props.simulationN}
        onChange={event => props.onSimulationN(Number(event.target.value))}/>
    </label>}
    {dataKind === 'file' && <>
      <label className="data-upload">Choose a CSV or SAV file
        <input disabled={busy} type="file" accept=".csv,.sav"
          onChange={event => props.onDataFile(event.target.files?.[0])}/>
      </label>
      <p className="help">Select prepared analysis data. It is read in this browser, not uploaded. Rmd setup and
        case-weight attributes are not reconstructed here; use native R for weighted analyses.</p>
    </>}
    {dataKind !== 'simulate' && <label>Categorical column overrides<small>Comma-separated names; optional</small>
      <input disabled={busy} value={props.categorical} onChange={event => props.onCategorical(event.target.value)}
        placeholder="condition, group"/>
    </label>}
    <button className="secondary" disabled={busy || !analysis} onClick={props.onPreview}><Icon name="chart"/>Preview
      ggplot2</button>
    {previews.map(file => <figure key={file.path}>
      {file.simulated && <div className="simulation-label">SIMULATED DATA — not research results</div>}
      <img src={file.url} alt={`${file.simulated ? 'Simulated' : 'Local data'} preview for ${analysis}`}/>
      <figcaption>{file.path}
        <button onClick={() => props.onDownload(file)}><Icon name="download"/>PNG</button>
      </figcaption>
    </figure>)}
  </div>;
}
