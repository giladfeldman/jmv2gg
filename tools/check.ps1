param([string]$Rscript = 'Rscript', [switch]$PackageCheck)
$ErrorActionPreference = 'Stop'
# Process-local locale settings prevent inherited Linux locales breaking Windows R.
foreach ($localeName in @('LC_ALL','LC_COLLATE','LC_CTYPE','LC_MONETARY','LC_TIME')) {
    [Environment]::SetEnvironmentVariable($localeName, 'C', 'Process')
}
& $Rscript tools/check.R
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $Rscript -e 'roxygen2::roxygenise()'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($PackageCheck) {
    $resolvedRscript = (Get-Command $Rscript).Source
    $rExecutable = Join-Path (Split-Path $resolvedRscript) 'R.exe'
    & $rExecutable CMD build --no-build-vignettes .
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $rExecutable CMD check --no-manual jmv2gg_0.1.0.9000.tar.gz
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
