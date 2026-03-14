# PLAN.md

## Goal
Add shared Comment AST & Merge support to `dotenv-merge` so `.env` files preserve comment headings, group separators, and inline guidance while still merging assignments deterministically.

`psych-merge` is the reference implementation for the shared comment capability, but `dotenv-merge` should adopt it in a line-oriented way that fits `.env` files.

## Current Status
- `dotenv-merge` is a strong fit for comment support because real `.env` files are often organized by comments and blank-line-separated groups.
- The gem already has the standard merge-gem layout and should stay lightweight rather than adopting a heavy AST model.
- This gem is best treated as a line/group merger with shared comment regions layered on top of assignment parsing.
- The main requirement is preserving human-maintained grouping without breaking assignment parsing.

## Integration Strategy
- Expose the shared comment capability from file analysis even though the file model is line-based.
- Treat comment lines and blank-line-separated comment blocks as first-class shared regions.
- Attach heading comments to the next assignment or logical group.
- Preserve document prelude/postlude comments and comment-only files.
- Preserve removed-key comments and promote inline comments when the owning assignment is removed.

## First Slices
1. Add shared comment capability plumbing to file analysis and parsed line wrappers.
2. Preserve top-of-file comments, bottom-of-file comments, and comment-only files.
3. Preserve heading comments for matched assignments when template content wins.
4. Preserve comments for removed destination-only assignments when removal is enabled.
5. Expand group-aware merge scenarios with blank lines between comment sections.

## First Files To Inspect
- `lib/dotenv/merge/file_analysis.rb`
- `lib/dotenv/merge/env_line.rb`
- `lib/dotenv/merge/smart_merger.rb`
- `lib/dotenv/merge/merge_result.rb`
- any parsing helpers under `lib/dotenv/merge/`

## Tests To Add First
- line parsing specs for comments vs values containing `#`
- smart merger specs for heading comment preservation
- specs for removed-key comment promotion
- specs for grouped variable sections separated by blank lines
- reproducible fixtures for realistic `.env` templates and destinations

## Risks
- `#` inside quoted values must not be mistaken for inline comments.
- Duplicate keys and exports can complicate comment ownership.
- Users care about exact spacing and grouping in `.env` files.
- The implementation must stay simple and line-oriented.

## Success Criteria
- Shared comment capability exists without overcomplicating the parser model.
- Heading comments and comment groups survive matched and removed assignment merges.
- Comment-only files and document-level comments are preserved.
- Inline comments are preserved or promoted safely.
- Reproducible fixtures cover realistic `.env` grouping patterns.

## Rollout Phase
- Phase 1 target.
- Recommended immediately after `jsonc-merge` because the line-oriented model gives fast feedback on shared comment APIs without parser complexity.

## Latest `ast-merge` Comment Logic Checklist (2026-03-13)
- [x] Shared capability plumbing: `comment_capability`, `comment_augmenter`, normalized region/attachment access
- [x] Document boundary ownership: prelude/postlude and comment-only file handling
- [x] Matched-node fallback: destination heading/inline comment preservation under template preference
- [x] Removed-node preservation: destination-only assignment comment preservation and inline promotion
- [x] Recursive/fixture parity: grouped `.env` scenarios and reproducible comment-heavy fixtures

Current parity status: complete for the latest shared `ast-merge` comment rollout shape, and the local workspace-path gem wiring has now been revalidated under `KETTLE_RB_DEV`.

## Progress
- 2026-03-13: Local workspace-path validation rechecked after modular gemfile wiring normalization.
- Replaced direct local `path:` overrides in modular tree-sitter gemfiles with the shared `nomono` local-override pattern and reran the full `dotenv-merge` suite in workspace mode; the suite is green.
- 2026-03-11: Plan sync completed.
- Confirmed `dotenv-merge` remains aligned to the latest shared `ast-merge` comment checklist with all rollout slices complete.
- This plan now serves as a completed Phase 1 reference alongside `jsonc-merge`.
- 2026-03-09: Phase 1 / Slice 1 completed.
- Added `Dotenv::Merge::CommentTracker` with shared comment capability plumbing for hash-style full-line comments and safe inline comments on unquoted assignments.
- Exposed `comment_capability`, `comment_nodes`, `comment_node_at`, `comment_region_for_range`, `comment_augmenter`, and `comment_attachment_for` from `FileAnalysis`.
- Added focused parser regressions to distinguish true inline comments from `#` characters inside quoted and unquoted values.
- Added focused specs for shared comment nodes, regions, attachments, augmenter prelude/postlude behavior, document-boundary comments, and comment-only destination preservation.
- Revalidated focused dotenv specs and the full `dotenv-merge` suite.
- 2026-03-09: Phase 1 / Slice 2 completed.
- Preserved destination inline comments when matched assignments emit template-preferred content.
- Added destination-only assignment removal support for `remove_template_missing_nodes: true` in the line-oriented merger path.
- Preserved grouped destination heading comments and blank-line-separated sections while promoting removed inline comments into standalone `# ...` lines.
- Added focused smart-merger regressions for template-preferred matched assignments, grouped comment sections, and removed destination-only assignment comment promotion.
- Revalidated focused dotenv specs and the full `dotenv-merge` suite after the Slice 2 changes.
- 2026-03-09: Phase 1 / Slice 3 completed.
- Promoted realistic grouped `.env` scenarios into reproducible fixtures for exported assignments, duplicate keys with stable sequential comment association, and quoted values containing `#`.
- Extended `spec/integration/reproducible_merge_spec.rb` and `spec/fixtures/reproducible/` with comment-heavy grouped scenarios that validate both expected output and idempotency.
- Revalidated the new reproducible fixture spec, focused dotenv parser/smart-merger coverage, and the full `dotenv-merge` suite.

## Execution Backlog

### Slice 1 — Comment regions for line-oriented files
- Add `comment_capability`, `comment_augmenter`, and normalized comment regions to file analysis.
- Preserve document prelude/postlude comments and comment-only files.
- Add focused specs for pure comment files, grouped files, and blank-line preservation.

Status: complete on 2026-03-09.

### Slice 2 — Matched and removed assignment comment ownership
- Attach heading comments to the next assignment or assignment group.
- Preserve destination comments when matched assignments are emitted from template-preferred content.
- Preserve comments for removed destination-only assignments and promote inline comments if the assignment disappears.
- Add focused smart-merger regressions for grouped variable sections.

Status: complete on 2026-03-09.

Next recommended resume point: move to the next rollout target; keep this gem in regression-only mode unless a new edge case appears.

### Slice 3 — Realistic `.env` grouping + fixtures
- Expand to `export` assignments, duplicate keys, and quoted values containing `#`.
- Pin blank-line-separated groups with reproducible fixtures.
- Keep the implementation line-oriented and avoid unnecessary parser complexity.

Status: complete on 2026-03-09.

Next recommended resume point: move to the next rollout target after `dotenv-merge` or, if staying here, add more fixture depth only for any newly discovered edge cases.

## Dependencies / Resume Notes
- Start in `lib/dotenv/merge/file_analysis.rb` and `lib/dotenv/merge/env_line.rb`.
- Reuse `psych-merge` only for shared comment concepts, not AST-level structure.
- Be conservative around quoted values and inline comment detection.

## Exit Gate For This Plan
- Comment headings, grouped sections, and removed-assignment comments survive common `.env` merges.
- The implementation remains simple, deterministic, and faithful to `.env` syntax.

Status: satisfied on 2026-03-09.
