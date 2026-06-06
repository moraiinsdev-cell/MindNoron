# Recreate Windows plugin junctions so MindNoron builds WITHOUT Developer Mode.
#
# Flutter normally creates *symlinks* for plugins, which require Windows
# Developer Mode (an admin/UAC toggle). This script instead creates directory
# *junctions* (mklink /J), which need no admin and satisfy the build.
#
# Run this after `flutter clean` or `flutter pub get` if you ever see:
#   "Building with plugins requires symlink support. Please enable Developer Mode"
#
# Usage:  powershell -ExecutionPolicy Bypass -File tool\setup_plugin_junctions.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$depsFile = Join-Path $root '.flutter-plugins-dependencies'
if (-not (Test-Path $depsFile)) {
  Write-Error "Run 'flutter pub get' first ($depsFile not found)."
  exit 1
}
$deps = Get-Content $depsFile -Raw | ConvertFrom-Json
$symdir = Join-Path $root 'windows\flutter\ephemeral\.plugin_symlinks'
New-Item -ItemType Directory -Force -Path $symdir | Out-Null
foreach ($pl in $deps.plugins.windows) {
  $target = ($pl.path -replace '\\\\', '\').TrimEnd('\')
  $link = Join-Path $symdir $pl.name
  if (Test-Path $link) { cmd /c "rmdir `"$link`"" | Out-Null }
  cmd /c "mklink /J `"$link`" `"$target`"" | Out-Null
  Write-Host "  junction: $($pl.name)"
}
Write-Host "Done. Now run:  flutter run -d windows"
