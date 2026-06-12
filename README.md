# MindNoron

MindNoron is a calm, local-first personal operating system for busy people who
want to capture ideas, choose priorities, lock in, and keep moving.

It is Windows desktop first, built with Flutter, Riverpod, and Drift/SQLite.
No account required. No cloud required. Your data starts on your machine.

If MindNoron helps you focus, please star the repo. Stars help more people find
the project and give the roadmap a little more gravity.

## Why MindNoron?

Most productivity tools become another place to manage productivity. MindNoron
is meant to feel simpler: quick capture first, tasks you can act on, a focus
timer that survives restarts, notes for thinking, habits for consistency, and a
dashboard that keeps the day visible.

The app now opens with a lock-in screen: read a motivational line, press any key
except Space for another one, and press Space only when you are ready to enter
the app and commit to the day.

## Highlights

- MindNoron Inc.: a living pixel-art office lobby where employees work, chat,
  and take coffee breaks on their own — click to inspect, drag-and-drop them
  god-style, rename, hire, fire, and pin real tasks to each one. All artwork
  is hand-drawn in code (no image assets).
- English-first desktop UI.
- Daily randomized motivation deck with 200+ original lines.
- No repeated motivation lines during the same day until the full daily pool is
  exhausted.
- Quick capture through the app, tray, or global hotkey.
- Inbox to task conversion.
- Task list with priorities, completion state, due metadata, and soft delete.
- Timestamp-based Pomodoro/focus timer that stays accurate across restarts.
- Dashboard with today's focus minutes, completed tasks, top priorities, and
  energy check-in.
- Notes with Markdown preview and [[wikilink]] backlinks.
- Habits with a tappable 7-day history, streaks, and totals.
- Expenses tracker with daily, monthly, and yearly comparison.
- Daily reflection journal with prompts, mood, and autosave.
- Focus-by-week and energy-trend charts.
- Command palette with navigation and search (tasks, notes, inbox).
- Local backup, export, import, and clear-data controls.
- Local-first SQLite data model designed to be sync-ready later.

## Tech Stack

- Flutter + Material 3
- Riverpod
- go_router
- Drift + SQLite
- Windows desktop integrations: tray, hotkey, notification, window manager

## Roadmap

| Phase | Scope | State |
| --- | --- | --- |
| 0 | Foundation: theme, Drift DB, migrations, window/tray/hotkey/notifications, router shell, l10n | Done |
| 1A | Core loop: capture, Inbox, tasks, focus timer, dashboard stats, backup-on-exit | Done |
| 1B | Command palette, settings, theme, export/import, energy check-in | Done |
| 2 | Notes (Markdown + [[backlinks]]), tags, contexts, palette search | Done |
| 3 | Habits, journal, focus/energy charts, calendar | Started |
| 3b | Projects and goals | Planned |
| 4 | Optional Supabase sync and mobile companion | Planned |

See [PLAN.md](PLAN.md) for the full product spec and roadmap.

## Download A Windows Build

For non-developer use, download the latest Windows zip from GitHub Releases
when one is published. Extract the zip, then run:

```text
mind_noron.exe
```

Do not copy only the `.exe` out of the folder. Flutter desktop apps need the
neighboring DLL files and the `data/` directory.

## Prerequisites

- Flutter stable
- Visual Studio 2022 with the "Desktop development with C++" workload for
  Windows builds

## Run Locally

The quickest way on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File tool\open_app.ps1
```

That script builds the debug Windows app if needed, then opens it.

Manual run:

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter run -d windows
```

The built debug binary is created at:

```text
build\windows\x64\runner\Debug\mind_noron.exe
```

## Build A Release Zip

On Windows, package a release build with:

```powershell
powershell -ExecutionPolicy Bypass -File tool\package_release.ps1
```

The script builds `flutter build windows --release` and writes a zip to `dist/`.
That zip contains the full runnable Release folder.

## No Developer Mode?

Flutter normally needs Windows Developer Mode to create plugin symlinks. This
project includes a helper that creates directory junctions instead.

If you see "Building with plugins requires symlink support" after a clean build,
run:

```powershell
powershell -ExecutionPolicy Bypass -File tool\setup_plugin_junctions.ps1
```

You can also enable Developer Mode once in Windows settings.

## Test And Analyze

```powershell
flutter analyze
flutter test
```

## Project Layout

```text
lib/
+-- core/          # theme, constants, enums, platform services, providers
+-- data/          # Drift database, tables, repositories, backup service
+-- features/      # capture, dashboard, tasks, focus, notes, habits, expenses
+-- l10n/          # English localization
+-- presentation/  # router, sidebar shell, shared widgets
+-- app.dart       # MaterialApp.router, theme mode, close-to-tray
+-- main.dart      # desktop init, ProviderContainer, backup-on-exit
```

Architecture: feature-first Flutter + Riverpod + Drift. Core records use UUIDs,
timestamps, soft delete, and dirty flags so future sync can be added without
reshaping the whole app.

## Privacy, Security, And License

- Privacy: [PRIVACY.md](PRIVACY.md)
- Security reports: [SECURITY.md](SECURITY.md)
- License: [MIT](LICENSE)
