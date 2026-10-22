/**
 * The rendered report, shown with an EMPTY sandbox: no scripts, no same-origin access, no
 * forms, popups or navigation of this page. R also strips scripts first (a second layer).
 */
export function ReportFrame({ html }: { html: string }) {
  return <iframe className="report-frame" sandbox="" referrerPolicy="no-referrer" title="Report preview"
    srcDoc={html}/>;
}
