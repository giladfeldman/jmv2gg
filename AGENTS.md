# jmv2gg development

The repository root is the R package; `web/` is the static React/Vite client.
Keep conversion behavior in R. Never evaluate input expressions while parsing.
Preserve original analyses, metadata, factor/reference coding, and explicit model
terms. Mark alternative statistical tests visibly in reports and diagnostics.

Use synthetic public tests. Private acceptance inputs and participant data must
never enter git or public artifacts. Do not weaken a test to clear a failure.

Run `Rscript tools/check.R`, the standard R package checks, and
`npm --prefix web run build`. Test the actual installed R package in WebR;
sourcing loose R files in JavaScript is not a package-integration test.

Read README.md for interfaces and current execution boundaries. Record checks
that did not run as blocked or not run, never passed.
