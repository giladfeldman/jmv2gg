# Release and deployment

Vercel project: `jmv2gg`; repository: `giladfeldman/jmv2gg`; production branch:
`main`; root: `web/`; framework: Vite; Node 24; install: `npm ci`; build:
`npm run build`; output: `dist/`. Include source files outside the root directory
for converter hash verification. This is an anonymous-only profile: no secrets,
database, server, test-login endpoint, or authenticated probes.

Run the native and web checks from README before release. After changing
DESCRIPTION, NAMESPACE, LICENSE, R/, man/, or inst/, rebuild the actual R package:

```powershell
docker run --rm --mount "type=bind,source=$PWD,target=/src" -w /src ghcr.io/r-wasm/webr:v0.6.0 Rscript tools/webr/build.R
npm --prefix web test
npm --prefix web run build
```

Keep exactly the current source archive in the ignored `web/public/r-packages/src/contrib/`
build directory. Commit the compiled binary, package index, and manifest together.
The build rejects stale source/artifact checksums. Inspect archive member lists;
never publish `.env*`, credentials, research data, or private reports.

Before first deployment publish three edge firewall rules: deny scanner paths
(`.env`, `.git`, `.aws`, WordPress/PHP probes); deny known training crawlers;
rate limit page requests by IP (120/minute), excluding runtime assets. Inspect:
`vercel firewall overview --project jmv2gg`.

Once Ready, run from the repository root:

```powershell
$env:JMV2GG_APP_URL = 'https://jmv2gg.vercel.app'
node tools/validation/deployment.mjs
```

This checks live revision/clean source, versions, artifact hash, exact dependency
index, headers, and scanner/crawler denies. HTTP probes do not enforce CSP/CORS.
`workingTreeDirty` reports raw Git status. `sourceTreeDirty` separately excludes
the two observed hosted-build changes: `.vercel/project.json` and untracked root
`vercel.json`; both appear in `providerManagedChanges`. Unexpected changes still
fail, and local builds receive no provider exception. Hashed frontend assets and
versioned converter binaries are immutable; manifests and indexes can revalidate.
Also test in a real browser:

1. Convert the default R example; inspect actual generated code for all engines.
2. Preview/download a simulated ggplot2 PNG with its simulation label.
3. Preview/download on selected prepared CSV and SAV data. Confirm network traffic
   contains only fixed public asset requests, with no source/data transmission.
4. Convert `examples/report.Rmd` with original output hidden. Download Rmd/ZIP.
   Verify native parity, provenance and data exclusion with
   `tools/validation/browser-downloads.R`.
5. Cancel/reset during a job and convert again. Check keyboard focus, desktop,
   360px/375px layouts, and reduced motion. Keep evidence privately.

Full HTML rendering and BetterGG previews use native R. Never hide this boundary.
Upgrade WebR by rebuilding and repeating native/browser parity tests, not merely
changing its JavaScript version.

Rollback to the previous verified Vercel deployment and compare its build-info
with the prior Git revision/artifact. The first release has no previous production
target; withdraw its alias if necessary. Restore native package versions from
exact tags/commits into a separate library to preserve existing analyses.

## Developer references

For change ownership and test scope read [architecture](ARCHITECTURE.md),
[capabilities/validation](VALIDATION.md), and [contributor workflow](../CONTRIBUTING.md).
Recorded release checks are not automatic proof that a later documentation or
code change has been deployed. Keep the live Git revision explicit.
