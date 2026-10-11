# claude-plugins

Erik Båvenstrand's Claude Code setup: the `bavenstrand` plugin marketplace, plus rules and global instructions symlinked into `~/.claude`.

## Plugins

### baven-core

- Skill `writing-for-agents`: rules for writing text an agent reads
- Hook: format shell scripts with shfmt and lint them with shellcheck after each write
- Hook: format Python files with ruff after each write

### Install

```sh
claude plugin marketplace add ErikBavenstrand/claude-plugins
claude plugin install baven-core@bavenstrand
```

## Rules and global instructions

Plugins cannot ship rules, so these are symlinked:

```sh
ln -s ~/Code/claude-plugins/rules ~/.claude/rules
ln -s ~/Code/claude-plugins/global-CLAUDE.md ~/.claude/CLAUDE.md
```
