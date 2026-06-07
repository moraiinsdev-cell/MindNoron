# Build (if needed) and open the MindNoron Windows desktop app — one command.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tool\open_app.ps1            # build only if exe missing, then open
#   powershell -ExecutionPolicy Bypass -File tool\open_app.ps1 -Rebuild   # always rebuild from latest code, then open
#   powershell -ExecutionPolicy Bypass -File tool\open_app.ps1 -Codegen   # rebuild AND re-run Drift/l10n codegen (use after model/.arb changes)
#
# Tip: just double-click  run.bat  in the project root.

param(
  [switch]$Rebuild,
  [switch]$Codegen
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root 'build\windows\x64\runner\Debug\mind_noron.exe'

function Resolve-Flutter {
  $cmd = Get-Command flutter -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $localFlutter = 'D:\sdk\flutter\bin\flutter.bat'
  if (Test-Path $localFlutter) { return $localFlutter }

  Write-Error "Flutter was not found. Add Flutter to PATH or install it at D:\sdk\flutter."
}

Set-Location $root
$flutter = Resolve-Flutter

# A running instance locks the exe — stop it before rebuilding.
Get-Process mind_noron -ErrorAction SilentlyContinue | Stop-Process -Force

if ($Rebuild -or $Codegen -or -not (Test-Path $exe)) {
  Write-Host "Preparing MindNoron..." -ForegroundColor Cyan
  & $flutter pub get

  $junctionScript = Join-Path $root 'tool\setup_plugin_junctions.ps1'
  if (Test-Path $junctionScript) {
    & powershell -ExecutionPolicy Bypass -File $junctionScript
  }

  if ($Codegen) {
    Write-Host "Running Drift codegen..." -ForegroundColor Cyan
    & $flutter pub run build_runner build --delete-conflicting-outputs
    Write-Host "Generating localizations..." -ForegroundColor Cyan
    & $flutter gen-l10n
  }

  Write-Host "Building Windows (debug)..." -ForegroundColor Cyan
  & $flutter build windows --debug
}

Write-Host "Opening MindNoron..." -ForegroundColor Green
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe)
