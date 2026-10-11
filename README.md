# claude-plugins

A Claude Code setup: a plugin marketplace, plus rules and global instructions symlinked into `~/.claude`.

## Plugins

### baven-core

- Skill `writing-for-agents`: rules for writing text an agent reads
- Hook: format shell scripts with shfmt and lint them with shellcheck after each write
- Hook: format Python files with ruff after each write

### Install

Replace `<owner>/<repo>` with this repo's GitHub path and `<marketplace>` with the `name` in `.claude-plugin/marketplace.json`:

```sh
claude plugin marketplace add <owner>/<repo>
claude plugin install baven-core@<marketplace>
```

## Rules and global instructions

Plugins cannot ship rules, so these are symlinked. Replace `<repo-path>` with the absolute path of your clone of this repo:

```sh
link() { [ -e "$2" ] && [ ! -L "$2" ] && mv "$2" "$2.bak"; ln -sfn "$1" "$2"; }
link <repo-path>/rules ~/.claude/rules
link <repo-path>/global-CLAUDE.md ~/.claude/CLAUDE.md
```

Safe to rerun. An existing real file or directory is moved to `<name>.bak`; an existing symlink is replaced.
