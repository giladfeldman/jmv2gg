# Developing jmv2gg

## Orientation

The R package is the converter. The static React client calls it through WebR;
there is no second JavaScript converter. Read [architecture](docs/ARCHITECTURE.md),
[validation/limits](docs/VALIDATION.md), [lessons](LESSONS.md), and
[deployment](docs/DEPLOYMENT.md).

## Feedback workflow

1. Capture the exact call/chunk, engine/options, expected versus actual output,
   versions, and whether the issue is conversion, inference, layout, preview,
   report embedding or export. Private inputs do not belong in public issues.
2. Reproduce with synthetic data having the same structural problem. Identify
   which source option/test/model/weight must be preserved or visibly distinguished.
3. Add a failing regression for substantive bugs; fix the owning layer. Never
   weaken a reference or lower a test floor to make a result green.
4. Run affected checks, rebuild WebR for compiled-source changes, and use a real
   browser for UI/worker/graphics/security changes. Leave private source data intact.
5. Update README/capabilities/CHANGELOG/LESSONS for behavior changes and keep release
   provenance reviewable. A successful conversion is not universal inferential proof.

## Native R and web checks

Conversion requires R>=4.4; full integration was tested with R4.6.1. Execution needs
plotting/report dependencies and Pandoc where applicable. Confirm `Rscript --version`
and `.libPaths()`; do not silently use an older executable from PATH.

From package root, PowerShell:

```powershell
./tools/check.ps1 -Rscript 'Rscript' -PackageCheck
npm --prefix web ci
npm --prefix web test
npm --prefix web run build
npm --prefix web run preview -- --port 4176
```

The R check script sets process-local C locales. With custom Windows libraries,
set both R_LIBS and R_LIBS_USER for child R processes. Put optional oxipng on PATH
to exercise lossless optimization; disclose its skip if absent. Fast unit checks
source R files, whereas installed-package checks and WebR integration exercise
packaging. All three provide different evidence; do not substitute one for another.

After DESCRIPTION/NAMESPACE/LICENSE/R/man/inst changes, follow the browser rebuild
instructions in DEPLOYMENT.md. Retain exactly the intended source archive in the
ignored build index; an older tarball can conflict with a new version. Commit the
binary, package index and manifest together. Do not replace immutable versioned
public artifacts with changed converter behavior under the same URL.

Private acceptance tools use environment variables and never bundle their inputs.
Record package/environment versions for research reproduction; a mutable default
repository is not an exact dependency lock. No database or auth is needed.
