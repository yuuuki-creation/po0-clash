# Installs the native po0-clash on 64-bit Windows 10 or 11. Downloads made here carry no Mark of the Web, so
# SmartScreen does not prompt; Smart App Control still judges the unsigned binaries by signature and reputation.
# Runs under Constrained Language Mode, which App Control imposes on untrusted scripts: cmdlets only, no .NET calls.
# ASCII only: Invoke-RestMethod decodes a release asset as Latin-1 before Invoke-Expression sees it.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Install-Po0Clash {
  $repo = if ($env:PO0CLASH_REPO) { $env:PO0CLASH_REPO } else { 'yuuuki-creation/po0-clash' }
  $api = if ($env:PO0CLASH_API) { $env:PO0CLASH_API } else { 'https://api.github.com' }
  $headers = @{ 'User-Agent' = 'po0-clash-installer'; Accept = 'application/vnd.github+json' }
  if ($env:GH_TOKEN) { $headers.Authorization = "Bearer $env:GH_TOKEN" }

  if ($env:PO0CLASH_VERSION) {
    $tag = 'native-v' + ($env:PO0CLASH_VERSION -replace '^(native-)?v', '')
    $release = Invoke-RestMethod -Uri "$api/repos/$repo/releases/tags/$tag" -Headers $headers
  } else {
    $releases = Invoke-RestMethod -Uri "$api/repos/$repo/releases?per_page=50" -Headers $headers
    $release = $releases | Where-Object { -not $_.draft -and $_.tag_name -like 'native-v*' } | Select-Object -First 1
    if (-not $release) { throw "$repo has no native release yet" }
  }
  $asset = $release.assets | Where-Object { $_.name -match '^po0-clash-.*-windows-x64-setup\.exe$' } | Select-Object -First 1
  if (-not $asset) { throw "release $($release.tag_name) has no Windows installer" }

  $work = Join-Path $env:TEMP "po0-clash-$(Get-Random)"
  New-Item -ItemType Directory -Path $work | Out-Null
  try {
    $setup = Join-Path $work $asset.name
    Write-Host "Downloading po0-clash $($release.tag_name)..."
    Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $setup -Headers @{ 'User-Agent' = 'po0-clash-installer' }

    $expected = if ($env:PO0CLASH_SHA256) { $env:PO0CLASH_SHA256 } else { $asset.digest -replace '^sha256:', '' }
    if (-not $expected) { throw "the release does not publish a checksum for $($asset.name)" }
    $actual = (certutil -hashfile $setup SHA256)[1] -replace '\s', ''
    if ($actual -ine $expected) { throw "checksum mismatch: got $actual, expected $expected" }
    Write-Host 'Checksum verified.'
    if ($env:PO0CLASH_DOWNLOAD_ONLY) { return }

    $blockedAdvice = 'Smart App Control blocks apps without a trusted signature and has no per-app exception. ' +
      'To use po0-clash, turn it off in Windows Security > App & browser control > Smart App Control settings.'
    $sac = $null
    try { $sac = (Get-MpComputerStatus -ErrorAction Stop).SmartAppControlState } catch {}
    if ($sac -eq 'On') { Write-Host "Smart App Control is on and may block this. $blockedAdvice" -ForegroundColor Yellow }

    Write-Host 'Installing; Windows will ask for administrator permission...'
    try {
      $installer = Start-Process -FilePath $setup -ArgumentList '/S' -Verb RunAs -Wait -PassThru
    } catch {
      $hint = if ($sac -eq 'On') { " $blockedAdvice" } else { '' }
      throw "Windows did not start the installer: $($_.Exception.Message)$hint"
    }
    if ($installer.ExitCode -ne 0) { throw "the installer exited with code $($installer.ExitCode)" }

    $root = if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }
    $app = Join-Path $root 'po0-clash\po0-clash.exe'
    if (-not (Test-Path -LiteralPath $app)) { throw "the installer finished but $app is missing" }
    Write-Host 'Opening po0-clash...'
    try {
      Start-Process -FilePath $app -Verb RunAs
    } catch {
      $hint = if ($sac -eq 'On') { " $blockedAdvice" } else { '' }
      throw "po0-clash is installed but Windows did not start it: $($_.Exception.Message)$hint"
    }
  } finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
  }
}

try {
  Install-Po0Clash
} catch {
  Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red
  if ($PSCommandPath) { exit 1 }
}
