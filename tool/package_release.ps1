# Build and package the Windows release folder into a distributable zip.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tool\package_release.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Resolve-Flutter {
  $cmd = Get-Command flutter -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $localFlutter = 'D:\sdk\flutter\bin\flutter.bat'
  if (Test-Path $localFlutter) { return $localFlutter }

  Write-Error "Flutter was not found. Add Flutter to PATH or install it at D:\sdk\flutter."
}

Set-Location $root
$flutter = Resolve-Flutter

Write-Host "Resolving packages..." -ForegroundColor Cyan
& $flutter pub get

$junctionScript = Join-Path $root 'tool\setup_plugin_junctions.ps1'
if (Test-Path $junctionScript) {
  & powershell -ExecutionPolicy Bypass -File $junctionScript
}

Write-Host "Building Windows release..." -ForegroundColor Cyan
& $flutter build windows --release

$versionLine = Select-String -Path (Join-Path $root 'pubspec.yaml') -Pattern '^version:\s*(.+)$'
$version = if ($versionLine) { $versionLine.Matches[0].Groups[1].Value.Trim() } else { 'dev' }
$safeVersion = $version -replace '\+', '-'

$releaseDir = Join-Path $root 'build\windows\x64\runner\Release'
$distDir = Join-Path $root 'dist'
$zipPath = Join-Path $distDir "MindNoron-windows-x64-$safeVersion.zip"

if (-not (Test-Path $releaseDir)) {
  Write-Error "Release directory not found: $releaseDir"
}

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
if (Test-Path $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}

Write-Host "Creating $zipPath..." -ForegroundColor Cyan
Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath $zipPath -Force

Write-Host "Packaged: $zipPath" -ForegroundColor Green
