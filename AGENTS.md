# AGENTS.md - Development Guide

## 🎯 Project Overview

```bash
mise exec -C /path/to/project -- bundle exec rspec
```

✅ **CORRECT** — If you need shell syntax first, load the environment in the same command:

```ruby
# kettle-jem:freeze
# ... custom code preserved across template runs ...
# kettle-jem:unfreeze
```

### Modular Gemfile Architecture

Gemfiles are split into modular components under `gemfiles/modular/`. Each component handles a specific concern (coverage, style, debug, etc.). The main `Gemfile` loads these modular components via `eval_gemfile`.

### Forward Compatibility with `**options`

**CRITICAL**: All constructors and public API methods that accept keyword arguments MUST include `**options` as the final parameter for forward compatibility.

**Repository**: https://github.com/kettle-rb/dotenv-merge
**Current Version**: 1.0.3
**Required Ruby**: >= 3.2.0 (currently developed against Ruby 4.0.1)

## ⚠️ AI Agent Terminal Limitations

### Terminal Output Is Available, but Each Command Is Isolated

**Minimum Supported Ruby**: See the gemspec `required_ruby_version` constraint.
**Local Development Ruby**: See `.tool-versions` for the version used in local development (typically the latest stable Ruby).

**Use this pattern**:

### Test Infrastructure

- Uses `kettle-test` for RSpec helpers (stubbed_env, block_is_expected, silent_stream, timecop)
- Uses `Dir.mktmpdir` for isolated filesystem tests
- Spec helper is loaded by `.rspec` — never add `require "spec_helper"` to spec files

### Use `mise` for Project Environment

**CRITICAL**: The canonical project environment lives in `mise.toml`, with local overrides in `.env.local` loaded via `dotenvy`.

⚠️ **Watch for trust prompts**: After editing `mise.toml` or `.env.local`, `mise` may require trust to be refreshed before commands can load the project environment. Until that trust step is handled, commands can appear hung or produce no output, which can look like terminal access is broken.

**Recovery rule**: If a `mise exec` command goes silent or appears hung, assume `mise trust` is the first thing to check. Recover by running:

```bash
mise trust -C /home/pboling/src/kettle-rb/dotenv-merge
mise exec -C /home/pboling/src/kettle-rb/dotenv-merge -- bundle exec rspec
```

```bash
mise trust -C /path/to/project
mise exec -C /path/to/project -- bundle exec rspec
```

Do this before spending time on unrelated debugging; in this workspace pattern, silent `mise` commands are usually a trust problem first.

```bash
mise trust -C /home/pboling/src/kettle-rb/dotenv-merge
```

✅ **CORRECT** — Run self-contained commands with `mise exec`:

```bash
mise exec -C /home/pboling/src/kettle-rb/dotenv-merge -- bundle exec rspec
```

✅ **CORRECT**:
```bash
eval "$(mise env -C /home/pboling/src/kettle-rb/dotenv-merge -s bash)" && bundle exec rspec
```

```bash
eval "$(mise env -C /path/to/project -s bash)" && bundle exec rspec
```

❌ **WRONG** — Do not rely on a previous command changing directories:

```bash
cd /home/pboling/src/kettle-rb/dotenv-merge
bundle exec rspec
```

❌ **WRONG**:
```bash
cd /home/pboling/src/kettle-rb/dotenv-merge && bundle exec rspec
```

```bash
cd /path/to/project
bundle exec rspec
```

❌ **WRONG** — A chained `cd` does not give directory-change hooks time to update the environment:

```bash
cd /path/to/project && bundle exec rspec
```

### Prefer Internal Tools Over Terminal

Full suite spec runs:

```bash
mise exec -C /path/to/project -- bundle exec rspec
```

For single file, targeted, or partial spec runs the coverage threshold **must** be disabled.
Use the `K_SOUP_COV_MIN_HARD=false` environment variable to disable hard failure:

### Workspace layout

## 🏗️ Architecture

### Toolchain Dependencies

This gem is part of the **kettle-rb** ecosystem. Key development tools:

### NEVER Pipe Test Commands Through head/tail

When you do run tests, keep the full output visible so you can inspect failures completely.

## 🏗️ Architecture: Line-Based Implementation

### What dotenv-merge Provides

- **`Dotenv::Merge::SmartMerger`** – .env-specific SmartMerger implementation
- **`Dotenv::Merge::FileAnalysis`** – .env file analysis with key-value extraction
- **`Dotenv::Merge::LineNode`** – Line-based node representation
- **`Dotenv::Merge::EntryNode`** – Key-value pair node
- **`Dotenv::Merge::MergeResult`** – .env-specific merge result
- **`Dotenv::Merge::ConflictResolver`** – .env conflict resolution
- **`Dotenv::Merge::FreezeNode`** – .env freeze block support
- **`Dotenv::Merge::DebugLogger`** – .env-specific debug logging

### Key Dependencies

| Gem | Role |
|-----|------|
| `ast-merge` (~> 4.0) | Base classes and shared infrastructure (uses Text::SmartMerger pattern) |
| `version_gem` (~> 1.1) | Version management |

### No Parser Backend

dotenv-merge uses line-based parsing (similar to `Ast::Merge::Text::SmartMerger`):

| Approach | Parser | Platform | Notes |
|----------|--------|----------|-------|
| Line-based | None (regex) | All platforms | Parses KEY=value lines with regex |

| Tool | Purpose |
|------|---------|
| `kettle-dev` | Development dependency: Rake tasks, release tooling, CI helpers |
| `kettle-test` | Test infrastructure: RSpec helpers, stubbed_env, timecop |
| `kettle-jem` | Template management and gem scaffolding |

### Executables (from kettle-dev)

| Executable | Purpose |
|-----------|---------|
| `kettle-release` | Full gem release workflow |
| `kettle-pre-release` | Pre-release validation |
| `kettle-changelog` | Changelog generation |
| `kettle-dvcs` | DVCS (git) workflow automation |
| `kettle-commit-msg` | Commit message validation |
| `kettle-check-eof` | EOF newline validation |

## 📁 Project Structure

```
lib/dotenv/merge/
├── smart_merger.rb          # Main SmartMerger implementation
├── file_analysis.rb         # .env file analysis
├── line_node.rb             # Line representation
├── entry_node.rb            # Key-value pair node
├── merge_result.rb          # Merge result object
├── conflict_resolver.rb     # Conflict resolution
├── freeze_node.rb           # Freeze block support
├── debug_logger.rb          # Debug logging
└── version.rb

spec/dotenv/merge/
├── smart_merger_spec.rb
├── file_analysis_spec.rb
├── entry_node_spec.rb
└── integration/
```

```
lib/
├── <gem_namespace>/           # Main library code
│   └── version.rb             # Version constant (managed by kettle-release)
spec/
├── fixtures/                  # Test fixture files (NOT auto-loaded)
├── support/
│   ├── classes/               # Helper classes for specs
│   └── shared_contexts/       # Shared RSpec contexts
├── spec_helper.rb             # RSpec configuration (loaded by .rspec)
gemfiles/
├── modular/                   # Modular Gemfile components
│   ├── coverage.gemfile       # SimpleCov dependencies
│   ├── debug.gemfile          # Debugging tools
│   ├── documentation.gemfile  # YARD/documentation
│   ├── optional.gemfile       # Optional dependencies
│   ├── rspec.gemfile          # RSpec testing
│   ├── style.gemfile          # RuboCop/linting
│   └── x_std_libs.gemfile     # Extracted stdlib gems
├── ruby_*.gemfile             # Per-Ruby-version Appraisal Gemfiles
└── Appraisal.root.gemfile     # Root Gemfile for Appraisal builds
.git-hooks/
├── commit-msg                 # Commit message validation hook
├── prepare-commit-msg         # Commit message preparation
├── commit-subjects-goalie.txt # Commit subject prefix filters
└── footer-template.erb.txt    # Commit footer ERB template
```

## 🔧 Development Workflows

### Running Tests

```bash
# Full suite
mise exec -C /home/pboling/src/kettle-rb/dotenv-merge -- bundle exec rspec

# Single file (disable coverage threshold check)
mise exec -C /home/pboling/src/kettle-rb/dotenv-merge -- env K_SOUP_COV_MIN_HARD=false bundle exec rspec spec/dotenv/merge/smart_merger_spec.rb
```

### Running Commands

Always make commands self-contained. Use `mise exec -C /home/pboling/src/kettle-rb/prism-merge -- ...` so the command gets the project environment in the same invocation.
If the command is complicated write a script in local tmp/ and then run the script.

```bash
mise exec -C /path/to/project -- env K_SOUP_COV_MIN_HARD=false bundle exec rspec spec/path/to/spec.rb
```

### Coverage Reports

```bash
mise exec -C /home/pboling/src/kettle-rb/dotenv-merge -- bin/rake coverage
mise exec -C /home/pboling/src/kettle-rb/dotenv-merge -- bin/kettle-soup-cover -d
```

```bash
mise exec -C /path/to/project -- bin/rake coverage
mise exec -C /path/to/project -- bin/kettle-soup-cover -d
```

**Key ENV variables** (set in `mise.toml`, with local overrides in `.env.local`):

- Running tests (`bundle exec rspec`)
- Installing dependencies (`bundle install`)
- Simple commands that do not require much shell escaping
- Running scripts (prefer writing a script over a complicated command with shell escaping)

### Code Quality

```bash
mise exec -C /path/to/project -- bundle exec rake reek
mise exec -C /path/to/project -- bundle exec rubocop-gradual
```

### Releasing

```bash
bin/kettle-pre-release    # Validate everything before release
bin/kettle-release        # Full release workflow
```

## 📝 Project Conventions

### API Conventions

#### SmartMerger API

- `merge` – Returns a **String** (the merged .env content)
- `merge_result` – Returns a **MergeResult** object
- `to_s` on MergeResult returns the merged content as a string

#### .env-Specific Features

**Key-Value Matching**:
```bash
# Template
DATABASE_URL=postgres://localhost/template_db
API_KEY=template_key

# Destination
DATABASE_URL=postgres://localhost/production_db
CUSTOM_VAR=keep_this
```

### Freeze Block Preservation

Template updates preserve custom code wrapped in freeze blocks:

```bash
# dotenv-merge:freeze
SECRET_KEY=custom_secret_dont_override
CUSTOM_TOKEN=abc123
# dotenv-merge:unfreeze

DATABASE_URL=postgres://localhost/db
```

**Comment Preservation**:
```bash
# Database configuration
DATABASE_URL=postgres://localhost/db

# API keys (do not commit to git)
API_KEY=your_key_here
```

### kettle-dev Tooling

This project is a **RubyGem** managed with the [kettle-rb](https://github.com/kettle-rb) toolchain.

- **Rakefile**: Sourced from kettle-dev template
- **CI Workflows**: GitHub Actions and GitLab CI managed via kettle-dev
- **Releases**: Use `kettle-release` for automated release process

### Version Requirements

- Ruby >= 3.2.0 (gemspec), developed against Ruby 4.0.1 (`.tool-versions`)
- `ast-merge` >= 4.0.0 required

## 🧪 Testing Patterns

### No Parser Dependency Tags

### Environment Variable Helpers

```ruby
before do
  stub_env("MY_ENV_VAR" => "value")
end

before do
  hide_env("HOME", "USER")
end
```

### Dependency Tags

Use dependency tags to conditionally skip tests when optional dependencies are not available:

✅ **CORRECT**:
```ruby
RSpec.describe Dotenv::Merge::SmartMerger do
  # No special tags needed - always runs
end
```

❌ **WRONG**:
```ruby
before do
  skip "Requires parser" unless parser_available?  # NOT NEEDED
end
```

### Shared Examples

dotenv-merge uses shared examples from `ast-merge`:

```ruby
it_behaves_like "Ast::Merge::FileAnalyzable"
it_behaves_like "Ast::Merge::ConflictResolverBase"
it_behaves_like "a reproducible merge", "scenario_name", { preference: :template }
```

## 🔍 Critical Files

| File | Purpose |
|------|---------|
| `lib/dotenv/merge/smart_merger.rb` | Main .env SmartMerger implementation |
| `lib/dotenv/merge/file_analysis.rb` | .env file analysis and key extraction |
| `lib/dotenv/merge/entry_node.rb` | Key-value pair abstraction |
| `lib/dotenv/merge/debug_logger.rb` | .env-specific debug logging |
| `spec/spec_helper.rb` | Test suite entry point |
| `mise.toml` | Shared development environment defaults |

## 🚀 Common Tasks

```bash
# Run all specs with coverage
bundle exec rake spec

# Generate coverage report
bundle exec rake coverage

# Check code quality
bundle exec rake reek
bundle exec rake rubocop_gradual

# Prepare and release
kettle-changelog && kettle-release
```

## 🌊 Integration Points

✅ **PREFERRED** — Use internal tools:

- `grep_search` instead of `grep` command
- `file_search` instead of `find` command
- `read_file` instead of `cat` command
- `list_dir` instead of `ls` command
- `replace_string_in_file` or `create_file` instead of `sed` / manual editing

❌ **AVOID** when possible:

- `run_in_terminal` for information gathering

Only use terminal for:

- `K_SOUP_COV_DO=true` – Enable coverage
- `K_SOUP_COV_MIN_LINE` – Line coverage threshold
- `K_SOUP_COV_MIN_BRANCH` – Branch coverage threshold
- `K_SOUP_COV_MIN_HARD=true` – Fail if thresholds not met

## 💡 Key Insights

1. **Line-based parsing**: No AST parser exists for .env format; uses regex to parse KEY=value
2. **Key matching**: Environment variables matched by key name (case-sensitive)
3. **Comment preservation**: Comments on their own lines are preserved
4. **Export handling**: Lines starting with `export` are supported
5. **Quote handling**: Single quotes, double quotes, and no quotes all supported
6. **Freeze blocks use `# dotenv-merge:freeze`**: Standard comment syntax
7. **Cross-platform**: Pure Ruby, no native dependencies

```ruby
RSpec.describe SomeClass, :prism_merge do
  # Skipped if prism-merge is not available
end
```

## 🚫 Common Pitfalls

1. **Keys are case-sensitive**: `DATABASE_URL` and `database_url` are different
2. **No whitespace normalization**: `KEY=value` and `KEY = value` are treated differently
3. **Quote differences matter**: `KEY="value"` and `KEY=value` are preserved as-is
4. **Do NOT load vendor gems** – They are not part of this project; they do not exist in CI
5. **Use `tmp/` for temporary files** – Never use `/tmp` or other system directories
6. **Do NOT expect `cd` to persist** – Every terminal command is isolated; use a self-contained `mise exec -C ... -- ...` invocation.
7. **Do NOT rely on prior shell state** – Previous `cd`, `export`, aliases, and functions are not available to the next command.

## 🔧 .env-Specific Notes

### Line Types

```bash
# Comment line
KEY=value                # Key-value pair
export KEY=value         # Exported variable
KEY="quoted value"       # Quoted value
KEY='single quoted'      # Single-quoted value
                        # Empty line
```

### Parsing Rules

```bash
# Valid formats
KEY=value
KEY="value with spaces"
KEY='value with "quotes"'
export DATABASE_URL=postgres://localhost/db
MULTILINE="line 1
line 2"  # Not recommended but supported by some parsers
```

### Merge Behavior

- **Keys**: Matched by exact key name (case-sensitive)
- **Comments**: Preserved on their own lines
- **Exports**: `export` keyword preserved if present
- **Quotes**: Quote style preserved from source
- **Freeze blocks**: Protect customizations from template updates
- **Order**: Key order preserved from destination unless new keys added

### EntryNode Structure

```ruby
entry = Dotenv::Merge::EntryNode.new(
  key: "DATABASE_URL",
  value: "postgres://localhost/db",
  line: "DATABASE_URL=postgres://localhost/db",
  has_export: false,
  quote_char: nil  # or '"' or "'"
)

entry.key          # "DATABASE_URL"
entry.value        # "postgres://localhost/db"
entry.to_s         # "DATABASE_URL=postgres://localhost/db"
```

1. **NEVER pipe test output through `head`/`tail`** — Run tests without truncation so you can inspect the full output.
