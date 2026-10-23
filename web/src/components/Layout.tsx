import { Icon } from './Icon';

export function SiteHeader({ onReset }: { onReset: () => void }) {
  return <header className="site-header">
    <a className="brand" href="#main"><span className="brand-mark"><Icon name="chart"/></span>jmv<span>2</span>gg</a>
    <nav aria-label="Project links">
      <a href="https://github.com/giladfeldman/jmv2gg" target="_blank" rel="noreferrer">R package ↗</a>
      <a href="#how-it-works">How it works</a>
      <button className="text-button" onClick={onReset}>Clear workspace</button>
    </nav>
  </header>;
}

export function Intro() {
  return <section className="intro">
    <div>
      <p className="intro-label">Editable figures. Reproducible research.</p>
      <h1>Make the figure yours.</h1>
      <p className="lead">Turn jamovi analysis code into ggplot2 and BetterGG figures you can edit, share, and
        reproduce.</p>
    </div>
    <div className="privacy">
      <Icon name="shield"/>
      <p>
        <strong>Your work stays on your device.</strong>
        <span>Code and data are processed locally in your browser. No account needed.</span>
      </p>
    </div>
  </section>;
}

export function Explainer() {
  return <section className="explainer" id="how-it-works">
    <h2>Built for the next person who opens your analysis.</h2>
    <div>
      <article>
        <h3>Explicit, editable code</h3>
        <p>Keep the data preparation, model, and figure in R. Adjust the generated code as your research develops.</p>
      </article>
      <article>
        <h3>Statistical differences made visible</h3>
        <p>When a BetterGG plot introduces a different test, the notes explain it. Your existing analyses remain
          available.</p>
      </article>
      <article>
        <h3>A report that travels</h3>
        <p>Download an Rmd with floating navigation, folded code, and publication exports. Knit it with your data in
          local R, or preview it here in your browser first.</p>
      </article>
    </div>
  </section>;
}

export function Footer() {
  return <footer>
    <span>jmv2gg · version 0.2.1</span>
    <span>WebR 0.6.0 · R runs locally · no research data uploads</span>
  </footer>;
}
