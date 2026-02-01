# Changelog

[![SemVer 2.0.0][📌semver-img]][📌semver] [![Keep-A-Changelog 1.0.0][📗keep-changelog-img]][📗keep-changelog]

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][📗keep-changelog],
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html),
and [yes][📌major-versions-not-sacred], platform and engine support are part of the [public API][📌semver-breaking].
Please file a bug if you notice a violation of semantic versioning.

[📌semver]: https://semver.org/spec/v2.0.0.html
[📌semver-img]: https://img.shields.io/badge/semver-2.0.0-FFDD67.svg?style=flat
[📌semver-breaking]: https://github.com/semver/semver/issues/716#issuecomment-869336139
[📌major-versions-not-sacred]: https://tom.preston-werner.com/2022/05/23/major-version-numbers-are-not-sacred.html
[📗keep-changelog]: https://keepachangelog.com/en/1.0.0/
[📗keep-changelog-img]: https://img.shields.io/badge/keep--a--changelog-1.0.0-FFDD67.svg?style=flat

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [1.0.2] - 2026-02-01

- TAG: [v1.0.2][1.0.2t]
- COVERAGE: 97.73% -- 345/353 lines in 8 files
- BRANCH COVERAGE: 83.06% -- 103/124 branches in 8 files
- 96.83% documented

### Added

- Utilizes `Ast::Merge::RSpec::MergeGemRegistry` when running RSpec tests

### Changed

- Documentation cleanup
- Upgrade to [ast-merge v4.0.5](https://github.com/kettle-rb/ast-merge/releases/tag/v4.0.5)
- Upgrade to [tree_haver v5.0.3](https://github.com/kettle-rb/tree_haver/releases/tag/v5.0.3)

## [1.0.1] - 2026-01-01

- TAG: [v1.0.1][1.0.1t]
- COVERAGE: 97.72% -- 343/351 lines in 8 files
- BRANCH COVERAGE: 83.61% -- 102/122 branches in 8 files
- 96.83% documented

### Added

- `node_typing` parameter for per-node-type merge preferences
  - Enables `preference: { default: :destination, special_type: :template }` pattern
  - Works with custom merge_types assigned via node_typing lambdas
- `match_refiner` parameter for fuzzy matching support
- `regions` and `region_placeholder` parameters for nested content merging
- `EnvLine#type` method returning `"env_line"` for TreeHaver::Node protocol compatibility

### Changed

- **SmartMerger**: Added `**options` for forward compatibility
  - Accepts additional options that may be added to base class in future
  - Passes all options through to `SmartMergerBase`
- **MergeResult**: Added `**options` for forward compatibility
- **BREAKING**: `SmartMerger` now inherits from `Ast::Merge::SmartMergerBase`
  - Provides standardized options API consistent with all other `*-merge` gems
  - All keyword arguments are now explicit (no more positional-only arguments)
  - Gains automatic support for new SmartMergerBase features
- Renamed `EnvLine#type` attribute to `EnvLine#line_type` to avoid conflict with TreeHaver::Node protocol

## [1.0.0] - 2025-12-12

- TAG: [v1.0.0][1.0.0t]
- COVERAGE: 97.85% -- 319/326 lines in 8 files
- BRANCH COVERAGE: 82.69% -- 86/104 branches in 8 files
- 96.97% documented

### Added

- Initial release

[Unreleased]: https://github.com/kettle-rb/dotenv-merge/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/kettle-rb/dotenv-merge/compare/v1.0.1...v1.0.2
[1.0.2t]: https://github.com/kettle-rb/dotenv-merge/releases/tag/v1.0.2
[1.0.1]: https://github.com/kettle-rb/dotenv-merge/compare/v1.0.0...v1.0.1
[1.0.1t]: https://github.com/kettle-rb/dotenv-merge/releases/tag/v1.0.1
[1.0.0]: https://github.com/kettle-rb/dotenv-merge/compare/a34c8f20c877a45d03b9f0b83b973614e123a92b...v1.0.0
[1.0.0t]: https://github.com/kettle-rb/dotenv-merge/tags/v1.0.0
