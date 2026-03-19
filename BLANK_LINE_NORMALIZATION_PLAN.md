# Blank Line Normalization Plan for `dotenv-merge`

_Date: 2026-03-19_

## Role in the family refactor

`dotenv-merge` is the line-oriented environment-file adopter for the shared blank-line normalization effort.

This repo should help validate that the shared layout model works for simple config files where blank lines separate variable groups and comment blocks.

## Current evidence files

Primary implementation and spec locations should be tracked from the repo root as this effort proceeds:

- `lib/dotenv/merge/`
- `spec/`
- `README.md`

## Current pressure points

Likely blank-line-sensitive cases include:

- comment-delimited variable groups
- preserved user blank lines separating environment sections
- stable spacing after key removal or reordering
- idempotence under repeated templating/merge runs

## Migration targets

- adopt the shared `ast-merge` layout model for blank-line grouping and separator preservation
- avoid repo-local newline fixes when shared gap logic is sufficient
- keep the format readable for human-maintained `.env` files

## Workstreams

- inventory existing `.env` spacing behavior and specs
- add focused blank-line regressions where missing
- migrate group-separator handling first
- confirm repeated merges remain stable

## Exit criteria

- variable-group blank-line behavior is explicitly covered
- shared layout semantics replace bespoke newline handling where possible
- repeated merges preserve intended section spacing without drift
