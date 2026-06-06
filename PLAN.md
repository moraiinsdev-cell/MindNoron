# MindNoron — Personal Operating System
## Development Specification & Roadmap

**Project Name:** MindNoron
**Tagline:** Your single source of truth for a busy life
**Target User:** One person only (Moraiins) — local-first, privacy-focused productivity app
**Primary Platform:** **Windows desktop first** (Flutter). Same codebase architected to add Android/iOS later.
**Language:** Vietnamese UI (default) + English-ready (i18n scaffolded from day 1)

---

## 1. Vision & Core Philosophy

MindNoron is a **personal life operating system** that replaces 5–7 separate apps (notes, todo, pomodoro, habit tracker, journal, calendar, second brain) with one calm window that is always within reach of a keyboard shortcut.

**The daily ritual loop** (the heart of the product):

```
  Capture  →  Clarify  →  Focus  →  Reflect
 (hotkey)    (Inbox →    (timer    (check-in
             task)       on task)   + stats)
```

**Guiding Principles:**
- **Capture everything instantly** (< 3 seconds, from anywhere via a global hotkey)
- **Everything is connected** — a graph of `task ↔ note ↔ time ↔ habit`
- **Deep focus first** — the integrated timer is sacred
- **Privacy & ownership** — 100% local data by default; cloud only if *you* turn it on
- **Beautiful simplicity** — calm, minimalist, fast, keyboard-first UI
- **GTD + Second Brain + Time Blocking + Reflection** combined

---

## 2. Tech Stack (Mandatory)

| Layer | Technology | Reason |
|-------|------------|--------|
| Framework | Flutter (latest stable), Dart 3 | Best cross-platform + beautiful UI; Windows desktop support is mature |
| State Management | Riverpod + riverpod_generator | Scalable, testable, modern |
| **Local Database** | **Drift (SQLite)** | Actively maintained, great desktop support, built-in **migrations** + **FTS5** full-text search, easy to layer sync on top |
| Navigation | go_router | Declarative, deep-linking, works well for desktop shells |
| UI | Material 3 + custom theme | Modern, consistent, dark-mode native |
| **Window management** | window_manager | Window size/min-size/position/state, frameless option |
| **System tray** | tray_manager | Tray icon + menu, show/hide, "live in the background" |
| **Global hotkey** | hotkey_manager | Summon Quick Capture from any app, even when minimized to tray |
| **Notifications** | flutter_local_notifications | Windows toast for timer-end + (later) task reminders |
| Startup (optional) | launch_at_startup | Auto-start on login so the hotkey is always available |
| Charts & Stats | fl_chart | Lightweight and beautiful |
| Localization | intl + flutter gen-l10n (or slang) | Vietnamese default, structure ready for English |
| Files / export | path_provider, file_picker | Export/import JSON + Markdown, choose backup location |
| IDs | uuid | Stable, sync-friendly primary keys |
| **Sync (later phase)** | supabase_flutter + delta sync (custom or PowerSync) | Optional multi-device cloud sync; schema designed sync-ready now |

> **Note on Isar:** the original plan specified Isar. As of 2026 the official Isar repo is **unmaintained** (only the community fork `isar_community` v3.3.x survives; v4 never shipped). We therefore standardize on **Drift**, which is actively maintained, runs natively on Windows, and gives us migrations + full-text search out of the box.

> **Voice input is deferred.** `speech_to_text` has weak Windows desktop support, and "100% local" private transcription needs an on-device model. MVP captures by keyboard/clipboard. Revisit voice when building the mobile version (or via local Whisper).

**Architecture Style:** Feature-first + Clean Architecture (data / domain / presentation). All persisted entities are **sync-ready** (see §6).

---

## 3. Folder Structure (Recommended)

```
lib/
├── core/
│   ├── constants/
│   ├── theme/
│   │   └── app_theme.dart          # tokens, dark + light
│   ├── utils/
│   │   ├── date_utils.dart
│   │   └── extensions.dart
│   ├── l10n/                        # generated localizations (vi default)
│   ├── platform/                    # desktop integration
│   │   ├── window_service.dart      # window_manager wrapper
│   │   ├── tray_service.dart        # tray_manager wrapper
│   │   ├── hotkey_service.dart      # hotkey_manager wrapper
│   │   ├── notification_service.dart
│   │   └── single_instance.dart     # one running instance only
│   └── providers/
│       └── app_providers.dart
├── data/
│   ├── database/                    # Drift
│   │   ├── app_database.dart
│   │   ├── tables/                  # InboxItems, Tasks, PomodoroSessions, ...
│   │   ├── daos/                    # TaskDao, TimerDao, ...
│   │   └── migrations.dart
│   ├── repositories/
│   │   ├── task_repository.dart
│   │   ├── timer_repository.dart
│   │   └── ...
│   └── backup/
│       └── backup_service.dart      # export/import + auto daily backup
├── features/
│   ├── capture/                     # global quick-capture window
│   ├── tasks/
│   ├── timer/
│   ├── dashboard/
│   ├── command_palette/             # Ctrl+K
│   ├── settings/
│   ├── notes/                       # Phase 2
│   └── sync/                        # placeholder for Supabase (Phase 4)
├── presentation/
│   ├── shell/                       # sidebar + multi-pane layout
│   ├── widgets/
│   │   ├── common/
│   │   └── task/
│   └── navigation/
│       └── app_router.dart
├── main.dart
└── app.dart
```

---

## 4. Data Models (Drift entities — sync-ready)

Every persisted entity shares these **base fields** so the schema can later sync to Supabase without a painful migration:

| Field | Type | Purpose |
|-------|------|---------|
| `id` | `String` (UUID v4) | Stable primary key (sync-friendly) |
| `createdAt` | `DateTime` | Creation time |
| `updatedAt` | `DateTime` | Last modification (conflict resolution) |
| `deletedAt` | `DateTime?` | **Soft delete** (never hard-delete synced data) |
| `isDirty` | `bool` | Has local changes not yet pushed to cloud |
| `syncedAt` | `DateTime?` | Last successful sync |

> IDs are **uuid strings everywhere** (no mixing of int auto-increment + string foreign keys). Foreign keys reference `id`.

### 4.1 InboxItem (Quick Capture)
`content`, `type` (`text` | `voice` | `photo`), `source` (`hotkey` | `tray` | `clipboard` | `drag`), `voicePath?`, `photoPath?`, `isProcessed`.
*MVP captures `text` (+ clipboard / drag-drop file). `voice` deferred; `photo` optional.*

### 4.2 Task
`title`, `description?`, `status` (`todo` | `in_progress` | `done` | `archived`), `priority` 1–4 (**1 = highest**, color-coded), `dueDate?`, `dueTime?`, `estimatedMinutes?`, `actualMinutes` (accumulated from sessions), `tags` (list for MVP; normalized via Tag in Phase 2), `context?` (`@Nhà`, `@Văn phòng`, `@Máy tính`…), `projectId?` (FK → Project, Phase 2), `isRecurring`, `recurrenceRule` (stored as RRULE-style string to future-proof; MVP supports `daily`/`weekly`/`monthly`), `completedAt?`.

### 4.3 PomodoroSession
`linkedTaskId?` (FK → Task), `startTime`, `endTime`, `plannedMinutes`, `actualMinutes`, `type` (`work` | `short_break` | `long_break`), `wasCompleted`, `interruptions`.

### 4.4 TimerState (NEW — keeps the timer alive across restarts)
`startTimestamp`, `plannedEndTimestamp`, `type`, `linkedTaskId?`, `isRunning`, `pausedElapsedSeconds`.
*Single-row table. The timer's truth is **timestamps**, never a ticking counter (see §5.3).*

### 4.5 DailyLog (NEW — backs the dashboard energy check-in)
`date`, `energyLevel` 1–5, `mood?`, `note?`, plus cached `focusMinutes` and `tasksCompleted` for fast dashboard reads.

### 4.6 AppSettings (NEW)
Timer durations (work / short / long), `sessionsBeforeLongBreak`, `autoStartBreak`, `autoStartNextWork`, `defaultPriority`, `theme`, `globalHotkey`, `contexts[]`, `locale`, `backupRetention`. (Key-value table or single-row settings table.)

### 4.7 Tag (Phase 2)
`name`, `color`. Enables rename + management; Tasks/Notes reference via a join table.

### 4.8 Note (Phase 2)
`title`, `content` (Markdown), `tags`, `linkedTaskIds`, plus **note ↔ note backlinks** (second-brain graph).

### 4.9 Later phases
`Project`, `Habit`, `JournalEntry`, `Goal` — outlined in §10.

---

## 5. Core Features — MVP

### 5.1 Quick Capture (Most Important)
- **Global hotkey** (default `Ctrl+Shift+Space`) opens a small, always-on-top capture box **from any app**, even when MindNoron is minimized to the tray.
- Type → **Enter** → saved to **Inbox** → box closes. Target: **< 3 seconds**.
- **System tray** menu also has "Ghi nhanh".
- Paste from clipboard; drag-and-drop a file/image.
- All items land in the **Inbox**. From any InboxItem:
  - "Convert to Task"
  - "Convert to Note" (Phase 2)
  - "Discard"
- *(Future: smart-parse natural language like "mai 3pm" → due date.)*

### 5.2 Tasks
**Views:** Inbox (unprocessed) · Today · Upcoming (next 7 days) · All Tasks (filter by priority/status/tags/context) · Completed (last 30 days).

**Desktop interactions:**
- **Master–detail two-pane** layout (list on the left, detail on the right) instead of mobile push-navigation.
- **Keyboard navigation** (`j`/`k` / arrows), multi-select, bulk actions.
- Create / Edit / Delete (soft) / Complete; priority 1–4 with color; due date + time; estimated vs actual time (actual auto-updates from the timer); tags; context; basic recurrence.

### 5.3 Focus Timer (Pomodoro)
- Customizable work + break durations; configurable Pomodoro rules (sessions before long break, auto-start break / next work).
- Big, calm timer screen; **start from a specific Task** → the session is linked.
- **Timestamp-based engine:** store `startTimestamp` + `plannedEndTimestamp` and compute elapsed from the clock; **never trust a Dart `Timer` for the source of truth** (it stalls when the app is backgrounded). The timer therefore **survives app restart / sleep**.
- Timer logic lives independently of the UI (a `Stream`/`ValueNotifier` drives repaints).
- Schedule a **local notification** for completion, so you're notified even when the window is hidden in the tray.
- Compact presence while running: title-bar mini-timer / tray tooltip / optional always-on-top pill.
- On work-session end: offer to start a break; log `actualMinutes` to the linked task.
- History screen + daily/weekly summary; "Focus time today" on the Dashboard.

### 5.4 Dashboard (Home)
- Time-based greeting ("Chào buổi sáng / chiều / tối").
- Today's date.
- Quick stats row: tasks completed today · focus minutes today · habit streak (later).
- "Today's Top Priorities" — 3–5 highest-priority or due-soon tasks.
- Big "Ghi nhanh" (Capture) button.
- Active-timer indicator if a session is running.
- **Daily energy check-in (1–5)** — saved per day, backed by `DailyLog`.

### 5.5 Command Palette — `Ctrl+K` (NEW, desktop-native)
Linear/Notion-style palette to jump to any view, create a task, start a timer, or search — everything reachable from the keyboard.

### 5.6 Search
MVP-lite: search Tasks + Inbox via **Drift FTS5**. Full cross-entity search (incl. Notes) in Phase 2.

### 5.7 Settings (MVP)
Timer durations · default priority · theme (**Dark default** + Light) · **global hotkey config** · contexts list · locale (vi) · **Export (JSON + Markdown)** · **Import / Restore** · **Automatic daily backup** (keep last N) · Clear all data (with confirmation).

---

## 6. Cross-Cutting Concerns (engineering depth)

- **Backup & restore (critical):** automatic daily local backup (zip of DB + media) to a chosen folder, keeping the last N copies; plus manual export/import. This is non-negotiable for a "single source of truth" app.
- **Database migrations:** Drift schema versioning from day 1 — user data is never lost when the schema evolves.
- **Notifications:** local notifications for timer completion now; task due-date reminders later.
- **Window lifecycle:** close-to-tray vs quit; restore window position/size; **single-instance enforcement** so the global hotkey never spawns a second app.
- **Sync-ready design (for Supabase, Phase 4) — documented now:** uuid PKs + `updatedAt` + soft delete + `isDirty`; conflict strategy = last-write-wins per record (field-level later); Supabase tables mirror the local schema with RLS scoped to a single user; sync mechanism = PowerSync or a custom delta-sync loop. Designing this in now avoids a painful migration later.
- **Testing:** unit tests for DAOs/repositories and the **timer engine** (pure logic → highly testable) to satisfy the reliability NFR; widget tests for the core flows.
- **Onboarding / first run:** seed default settings, default contexts (`@Nhà`, `@Văn phòng`, `@Máy tính`), and one sample task.
- **States:** consistent loading / empty / error states for every async surface.
- **Performance:** virtualized lists + Drift streaming queries → 60fps with 500+ items.

---

## 7. UI/UX Guidelines

- **Shell:** persistent **left sidebar / nav rail** (not a mobile bottom nav); resizable multi-pane (list + detail).
- **Keyboard-first:** command palette (`Ctrl+K`), discoverable shortcuts, an in-app shortcuts cheat-sheet.
- **Desktop behaviors:** system tray presence + global hotkey; decide native vs custom title bar.
- **Style:** calm, minimalist, modern (Notion + Linear + Forest). **Dark mode first**, Light available.
- **Color:** deep blue / teal accent (final palette TBD — see §11).
- **Typography:** clean sans-serif, high readability.
- **Animations:** subtle, purposeful.
- **Vietnamese first** for all user-facing text.
- **Adaptive layout** (`LayoutBuilder`) so the same screens can later collapse gracefully for mobile.
- **Accessibility:** good contrast, large tap/click targets.

---

## 8. Non-Functional Requirements

- **Offline-first** — fully functional with no internet (cloud is opt-in only).
- **Privacy** — no analytics, no tracking; data leaves the device only if you enable Supabase sync.
- **Speed** — capture < 3s, lists scroll at 60fps.
- **Reliability** — the timer is accurate (timestamp-based) and covered by tests; data is safe (auto-backup + migrations).
- **Data ownership** — one-tap export (JSON + Markdown) + import + automatic backups.

---

## 9. Coding Guidelines for AI Assistant

1. Always use **Riverpod** providers (never `setState` for business logic).
2. Keep UI dumb — move logic to repositories / use cases.
3. Use **Drift DAOs + streaming queries**; keep SQL in the data layer.
4. Keep the **timer engine independent of the UI** (drive repaints via `Stream`/`ValueNotifier`).
5. Every persisted entity uses a **uuid PK** and the base fields (timestamps + soft delete + dirty flag).
6. Write clean, readable, well-commented code; meaningful names; small focused widgets.
7. Handle loading / error / empty states in every async operation.
8. Add `const` wherever possible; use Vietnamese comments for business logic when helpful.
9. **Write tests** for the timer engine and repositories.
10. Make every primary action reachable by a **keyboard shortcut**; after finishing a feature, suggest the next logical step.

---

## 10. Development Phases

### Phase 0 — Foundation
`flutter create --platforms=windows` · add dependencies · app theme (Material 3, dark) · Drift database + migrations scaffold · `window_manager` + `tray_manager` + `hotkey_manager` wiring · go_router + sidebar shell · localization scaffold (vi).

### Phase 1A — Core Loop (the "aha", a usable daily driver)
- Quick Capture (global hotkey + tray) → Inbox → Convert to Task
- Tasks CRUD + Today / Inbox views
- Focus timer (timestamp-based) linked to a task + completion notification
- Minimal Dashboard
- Data persists; backup-on-exit
→ **You can capture, turn into tasks, focus, and see progress — every day.**

### Phase 1B — Make It Pleasant
All task views + filters · Command Palette (`Ctrl+K`) · task search (FTS5) · full Settings (timer / hotkey / theme / export / import + auto backup) · dashboard stats · energy check-in.

### Phase 2 — Knowledge & Polish
Notes (Markdown) + backlinks · global cross-entity search · tag management · projects · richer charts.

### Phase 3 — Life Management
Habits + streaks · Daily Journal with prompts · Goals & vision board · Calendar / time-blocking view.

### Phase 4 — Sync & Expand
Optional encrypted **Supabase sync** + multi-device · Android/iOS builds (reuse codebase; add mobile capture / voice / foreground-service timer) · on-device AI summarization where supported.

**Estimated effort (ranges, depends on Flutter familiarity):** Phase 0 + 1A ≈ **2–3 weeks** part-time to first daily driver; full Phase 1 (A+B) ≈ **4–6 weeks** solo.

---

## 11. Open Questions

*(Resolved: Vietnamese-first with i18n scaffolded day 1 · Windows desktop first · voice deferred · Drift over Isar · local-first + Supabase later.)*

Still to decide:
- Exact color palette + reference apps you like?
- Exact **global hotkey** (default proposed: `Ctrl+Shift+Space`)?
- Pomodoro rules — auto-start break/next? sessions before a long break?
- Default contexts beyond `@Nhà / @Văn phòng / @Máy tính`?
- Backup retention — how many copies to keep?
- When to introduce Supabase sync (which milestone triggers it)?
- Native window title bar or a custom frameless one?

---

## 12. Success Criteria for MVP

After Phase 1 you should be able to:
1. From **any** app, hit the hotkey and capture an idea/task in **< 3 seconds**.
2. Turn captured items into proper tasks and see them in **Today**.
3. Start a focus session linked to a task — it **survives a restart** and **notifies you** on completion.
4. See real progress (tasks completed + focus time) on the Dashboard every day.
5. Do almost anything via **`Ctrl+K`**, and trust that a **daily auto-backup** keeps your data safe.
6. Feel that **everything important lives in one calm, fast place**.

---

**This PLAN.md is the single source of truth for building MindNoron.**

When you're ready, start with **Phase 0 → Phase 1A** and follow the feature list. Ask for clarification only on the **Open Questions** when needed.

Let's build your personal operating system. 🚀
