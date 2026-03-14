# AGENTS.md - dotenv-merge Development Guide

## 🎯 Project Overview

`dotenv-merge` is a **format-specific implementation of the `*-merge` gem family** for .env files. It provides intelligent environment file merging using line-based analysis (no AST parser available for .env format).

**Core Philosophy**: Intelligent .env file merging that preserves structure, comments, and formatting while applying updates from templates.

**Repository**: https://github.com/kettle-rb/dotenv-merge
**Current Version**: 1.0.3
**Required Ruby**: >= 3.2.0 (currently developed against Ruby 4.0.1)

## ⚠️ AI Agent Terminal Limitations

### Terminal Output Is Available, but Each Command Is Isolated

**CRITICAL**: AI agents can reliably read terminal output when commands run in the background and the output is polled afterward. However, each terminal command should be treated as a fresh shell with no shared state.

**Use this pattern**:
1. Run commands with background execution enabled.
2. Fetch the output afterward.
3. Make every command self-contained — do **not** rely on a previous `cd`, `export`, alias, or shell function.

### Use `mise` for Project Environment

**CRITICAL**: The canonical project environment now lives in `mise.toml`, with local overrides in `.env.local` loaded via `dotenvy`.

⚠️ **Watch for trust prompts**: After editing `mise.toml` or `.env.local`, `mise` may require trust to be refreshed before commands can load the project environment. That interactive trust screen can masquerade as missing terminal output, so commands may appear hung or silent until you handle it.

**Recovery rule**: If a `mise exec` command in this repo goes silent, appears hung, or terminal polling stops returning useful output, assume `mise trust` is needed first and recover with:

```bash
mise trust -C /home/pboling/src/kettle-rb/dotenv-merge
mise exec -C /home/pboling/src/kettle-rb/dotenv-merge -- bundle exec rspec
```

Do this before spending time on unrelated debugging; in this workspace, silent `mise` commands are usually a trust problem.

```bash
mise trust -C /home/pboling/src/kettle-rb/dotenv-merge
```

✅ **CORRECT**:
```bash
mise exec -C /home/pboling/src/kettle-rb/dotenv-merge -- bundle exec rspec
```

✅ **CORRECT**:
```bash
eval "$(mise env -C /home/pboling/src/kettle-rb/dotenv-merge -s bash)" && bundle exec rspec
```

❌ **WRONG**:
```bash
cd /home/pboling/src/kettle-rb/dotenv-merge
bundle exec rspec
```

❌ **WRONG**:
```bash
cd /home/pboling/src/kettle-rb/dotenv-merge && bundle exec rspec
```

### Prefer Internal Tools Over Terminal

Use `read_file`, `list_dir`, `grep_search`, `file_search` instead of terminal commands for gathering information. Only use terminal for running tests, installing dependencies, and git operations.

### Workspace layout

This repo is a sibling project inside the `/home/pboling/src/kettle-rb` workspace, not a vendored dependency under another repo.

### NEVER Pipe Test Commands Through head/tail

Run the plain command and inspect the full output afterward. Do not truncate test output.

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

## 🔧 Development Workflows

### Running Tests

```bash
# Full suite
mise exec -C /home/pboling/src/kettle-rb/dotenv-merge -- bundle exec rspec

# Single file (disable coverage threshold check)
mise exec -C /home/pboling/src/kettle-rb/dotenv-merge -- env K_SOUP_COV_MIN_HARD=false bundle exec rspec spec/dotenv/merge/smart_merger_spec.rb
```

**Note**: Always make commands self-contained. Use `mise exec -C /home/pboling/src/kettle-rb/dotenv-merge -- ...` so the command gets the project environment in the same invocation.

### Coverage Reports

```bash
mise exec -C /home/pboling/src/kettle-rb/dotenv-merge -- bin/rake coverage
mise exec -C /home/pboling/src/kettle-rb/dotenv-merge -- bin/kettle-soup-cover -d
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

**Freeze Blocks**:
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

This project uses `kettle-dev` for gem maintenance automation:

- **Rakefile**: Sourced from kettle-dev template
- **CI Workflows**: GitHub Actions and GitLab CI managed via kettle-dev
- **Releases**: Use `kettle-release` for automated release process

### Version Requirements
- Ruby >= 3.2.0 (gemspec), developed against Ruby 4.0.1 (`.tool-versions`)
- `ast-merge` >= 4.0.0 required

## 🧪 Testing Patterns

### No Parser Dependency Tags

Since dotenv-merge uses line-based parsing (no external parser), there are no special dependency tags needed:

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

- **`ast-merge`**: Inherits base classes (`SmartMergerBase`, `FileAnalyzable`, etc.)
- **Line-based parsing**: Similar to `Ast::Merge::Text::SmartMerger` pattern
- **RSpec**: Full integration via `ast/merge/rspec`
- **SimpleCov**: Coverage tracked for `lib/**/*.rb`; spec directory excluded

## 💡 Key Insights

1. **Line-based parsing**: No AST parser exists for .env format; uses regex to parse KEY=value
2. **Key matching**: Environment variables matched by key name (case-sensitive)
3. **Comment preservation**: Comments on their own lines are preserved
4. **Export handling**: Lines starting with `export` are supported
5. **Quote handling**: Single quotes, double quotes, and no quotes all supported
6. **Freeze blocks use `# dotenv-merge:freeze`**: Standard comment syntax
7. **Cross-platform**: Pure Ruby, no native dependencies

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
