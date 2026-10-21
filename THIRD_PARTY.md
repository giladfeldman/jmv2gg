# Third-party software

jmv2gg's own source is MIT licensed. Its web interface uses React and React DOM
(MIT), JSZip (MIT option), the WebR JavaScript API (MIT), and IBM Plex fonts
(SIL Open Font License 1.1). Copies of their notices are served under
`web/public/licenses/` and accompany the static distribution.

The R/WebAssembly runtime is downloaded directly from the official pinned
WebR distribution. WebR's notice explains the licenses of its runtime and
components, including GNU GPL v3 for the combined runtime binaries. Sources:
[WebR](https://github.com/r-wasm/webr),
[R](https://www.r-project.org/),
[React](https://github.com/facebook/react),
[JSZip](https://github.com/Stuk/jszip),
[IBM Plex](https://github.com/IBM/plex).

The package binary served by this project contains jmv2gg's own R source.
Other R packages are downloaded from the official WebR package repository,
with exact versions recorded in `web/public/locks/packages.json`. Native R
dependencies, ggstatsplot and BetterGG retain their respective licenses.
