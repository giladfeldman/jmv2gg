import type { Mode } from '../types';

export const starterCode = `# Paste the R code copied from jamovi here.
# Preview on your local dataset or explicitly simulated data.
jmv::ANOVA(
  data = my_data,
  dep = "score",
  factors = c("condition"),
  modelTerms = list("condition"),
  emMeans = list("condition"),
  emmWeights = TRUE
)`;

export interface Example {
  id: string; label: string; mode: Mode; path?: string; filename: string; bundledData: boolean;
}

/** The bundled dataset is synthetic: simulated values, not research results. */
export const bundledDataset = { path: '/examples/replication-study.csv', name: 'replication-study.csv' };

export const examples: Example[] = [
  { id: 'starter', label: 'Short R example', mode: 'code', filename: 'analysis.R', bundledData: false },
  { id: 'complex-r', label: 'Complex R example', mode: 'code', path: '/examples/replication-study.R',
    filename: 'replication-study.R', bundledData: true },
  { id: 'complex-rmd', label: 'Complex R Markdown report', mode: 'rmd', path: '/examples/replication-report.Rmd',
    filename: 'replication-report.Rmd', bundledData: true },
];

export async function loadExample(example: Example) {
  if (!example.path) return starterCode;
  const response = await fetch(example.path);
  if (!response.ok) throw new Error(`The example ${example.filename} could not be loaded.`);
  return response.text();
}

export async function loadBundledDataset() {
  const response = await fetch(bundledDataset.path);
  if (!response.ok) throw new Error('The bundled synthetic dataset could not be loaded.');
  return new File([await response.blob()], bundledDataset.name, { type: 'text/csv' });
}
