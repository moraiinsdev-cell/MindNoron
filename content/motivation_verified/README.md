# MindNoron verified motivation library

This folder is for source-backed English motivation quotes only.

The previous 3650 generated quotes were not deleted. They were moved to:

`content/motivation_raw_generated/`

Use this verified folder as the production-quality path. The raw generated folder can still be mined later, but every quote promoted into this folder must pass source review first.

## Quality rule

A quote belongs here only when:

- the wording is found in a named source text, speech, essay, or book;
- the author, source title, source URL, and source type are recorded;
- the source is public-domain or otherwise safe enough to review for app use;
- the quote is not copied from modern quote aggregator sites without primary-source confirmation;
- the quote is not included only because it is famous online.

## Normalization

Quotes may be normalized for app display:

- line wraps removed;
- ASCII punctuation used;
- Project Gutenberg or editor footnote markers omitted;
- obvious HTML artifacts removed.

Normalization must not rewrite the meaning or invent wording. If a quote needs adaptation, do not mark it as `verified-source-text`; keep it out of this folder until reviewed.

## Files

- `sources.json`: source metadata and license/terms notes.
- `verified_quotes_batch_001.jsonl`: first verified quote batch.

## JSONL quote schema

Each JSONL row should include:

- `id`: stable quote id, `vq-0001` style.
- `text`: display quote text in English.
- `author`: credited author or speaker.
- `sourceId`: id from `sources.json`.
- `sourceLocator`: rough location in the work or speech.
- `verificationStatus`: currently `verified-source-text`.
- `normalized`: whether display text was normalized for app readability.
- `themes`: short tags for future filtering.
- `intensity`: 1-5 motivation intensity.

## Scaling plan

Grow in batches. A good batch is 50-100 quotes from 5-15 reliable sources, then validation:

- JSON parse succeeds.
- No duplicate ids.
- No duplicate display text.
- Every `sourceId` exists in `sources.json`.
- Every quote can be searched back in the source text after normalization allowances.
