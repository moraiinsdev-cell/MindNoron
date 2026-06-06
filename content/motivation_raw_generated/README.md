# MindNoron Motivation Library

This folder stores offline motivation content only. It is intentionally separate
from app code so new quote packs can be collected, reviewed, and appended without
touching the Flutter implementation.

Current library target: `3650` original quotes, enough for 10 years at one quote
per day. Current stored range: `mn-0001` through `mn-3650`.

## Format

Quote packs use JSON Lines (`.jsonl`): one valid JSON object per line.

Required fields:

- `id`: stable unique id, e.g. `mn-0001`
- `text`: the motivation line
- `author`: display author
- `source`: content origin
- `license`: usage label
- `category`: primary category
- `tone`: emotional tone
- `intensity`: 1-5 lock-in energy
- `timeOfDay`: `any`, `morning`, `night`, or `late_night`
- `tags`: short searchable labels

## Content Rules

- Prefer original MindNoron lines over copied famous quotes.
- Avoid exact wording from existing quote apps, books, or websites.
- Keep most lines under 160 characters for splash-screen readability.
- Add new packs as `mindnoron_quotes_batch_002.jsonl`, etc.
- Run a JSONL validation pass before using a pack in the app.
