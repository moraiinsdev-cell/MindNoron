# Assets — images

Drop a real tray icon here as `tray_icon.ico` (Windows tray needs `.ico`).
`TrayService` references `assets/images/tray_icon.ico` and fails gracefully if it
is missing, so the app still runs without it during Phase 0.
