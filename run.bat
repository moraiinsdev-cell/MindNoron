@echo off
REM Double-click to rebuild MindNoron from the latest code and launch it.
REM For a code-only change this is all you need. After changing Drift models
REM or .arb files, run instead:  run.bat codegen
cd /d "%~dp0"
if /i "%1"=="codegen" (
  powershell -ExecutionPolicy Bypass -File "%~dp0tool\open_app.ps1" -Rebuild -Codegen
) else (
  powershell -ExecutionPolicy Bypass -File "%~dp0tool\open_app.ps1" -Rebuild
)
