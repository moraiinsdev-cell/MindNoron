# Privacy

MindNoron is local-first. The app does not require an account, does not include
analytics, and does not send your tasks, notes, journal entries, expenses, timer
history, habits, or settings to a server.

## What The App Stores

MindNoron stores your app data in a local SQLite database managed by Drift. The
database is created in the platform application documents area used by Flutter's
`path_provider`.

Stored data can include:

- inbox captures;
- tasks and subtasks;
- focus and break sessions;
- early-stop reasons written when you stop a timer before completion;
- notes, backlinks, and thinking-flow entries;
- calendar events;
- habits and completions;
- expenses;
- journal notes, mood, and energy check-ins;
- settings such as theme, hotkey, sound, and custom focus-track paths.

## Backups And Exports

The app can create local JSON backups and user-chosen JSON exports. These files
contain the same personal data as the app database. Keep them somewhere you
trust.

Backups and exports are not encrypted by MindNoron today.

If you import a custom focus soundscape, MindNoron stores a reference to the
file path. The backup/export currently stores that path reference, not a copy of
the audio file itself.

## Network And Cloud

MindNoron does not currently use Supabase or any other cloud service at runtime.
Supabase sync is a planned optional feature for a later phase. If cloud sync is
added, it should be opt-in and documented before release.

## Deleting Data

Use Settings -> Data -> Delete all data to wipe local app records. You should
also delete any JSON backups or exports you created separately if you no longer
want those copies.
