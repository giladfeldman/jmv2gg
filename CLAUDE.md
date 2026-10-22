# jmv2gg — Claude Code entry point

Read [AGENTS.md](AGENTS.md), [README.md](README.md), [CONTRIBUTING.md](CONTRIBUTING.md),
[architecture](docs/ARCHITECTURE.md), [capabilities/validation](docs/VALIDATION.md),
and [deployment](docs/DEPLOYMENT.md). Package/frontend version: 0.2.0.

Keep conversion in R. Never evaluate uploaded source to infer analyses. Preserve
original analyses, explicit terms, dataset snapshots, weights, factor value mappings,
references and RNG. Unsupported/different analyses require visible diagnostics.
BetterGG means real BetterGG calls. Its additional tests are not silently equivalent
to original jamovi inference. Full HTML and BetterGG previews use native R.

Use synthetic public fixtures. Research files, rendered reports, machine-specific
paths, history backups and private handoffs must stay outside public source/artifacts.
Do not add a backend, database, upload endpoint, auth, analytics or AI.

Run R through PowerShell with the intended executable/library. Run npm tests/build.
After compiled-source changes rebuild the actual WebR package with tools/webr/build.R;
never waive source/binary hash guards. Real-browser checks are required for CSP,
CORS and graphics. Unit mocks or HTTP success are not execution evidence.

Investigate feedback using the smallest reproducer and an independently checked
reference. Compare inference against source implementations, not screenshots alone.
Read LESSONS.md before parser/generator/runtime/release work. Record NOT RUN checks,
optional skips and limitations. Preserve release tags; changed released R behavior
needs a version bump and matching rebuilt browser artifact before publication.
