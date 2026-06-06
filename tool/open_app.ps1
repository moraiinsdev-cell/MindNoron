# Build if needed, then open the MindNoron Windows desktop app.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tool\open_app.ps1
#   powershell -ExecutionPolicy Bypass -File tool\open_app.ps1 -Rebuild

param(
  [switch]$Rebuild
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

if ($Rebuild -or -not (Test-Path $exe)) {
  Write-Host "Preparing MindNoron..."
  & $flutter pub get

  $junctionScript = Join-Path $root 'tool\setup_plugin_junctions.ps1'
  if (Test-Path $junctionScript) {
    & powershell -ExecutionPolicy Bypass -File $junctionScript
  }

  & $flutter build windows --debug
}

Write-Host "Opening MindNoron..."
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe)
