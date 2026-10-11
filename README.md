# claude-plugins

A Claude Code setup: a plugin marketplace, plus rules and global instructions symlinked into `~/.claude`.

Setup order:

1. Install the dependencies of each plugin you want ([Plugins](#plugins)).
2. Install the plugins ([Install plugins](#install-plugins)).
3. Install the CLI tools and set up `PATH` ([CLI tools](#cli-tools)).
4. Symlink the rules and global instructions ([Rules and global instructions](#rules-and-global-instructions)).

Package names below are Homebrew formulae. On Linux, use the distro's package manager; names may differ.

## Plugins

### baven-core

- Skill `writing-for-agents`: rules for writing text an agent reads.
- Hook: after each Write or Edit, format shell scripts with shfmt and lint them with shellcheck.
- Hook: after each Write or Edit, format Python files with ruff.

Dependencies:

| Tool | Used by | Package | If missing |
| --- | --- | --- | --- |
| `jq` | both hooks, to read the hook input | `jq` (built into macOS 15+ at `/usr/bin/jq`) | both hooks do nothing |
| `shfmt` | shell hook | `shfmt` | formatting is skipped |
| `shellcheck` | shell hook | `shellcheck` | linting is skipped |
| `ruff` or `uv` | Python hook | `ruff` or `uv` | formatting is skipped |

The Python hook prefers the project's `.venv/bin/ruff`, then `ruff` on `PATH`, then `uvx ruff`. Installing `uv` alone is enough.

Hooks fail silently when a tool is missing. Check with:

```sh
command -v jq shfmt shellcheck uv
```

## Install plugins

Replace `<owner>/<repo>` with this repo's GitHub path and `<marketplace>` with the `name` in `.claude-plugin/marketplace.json`:

```sh
claude plugin marketplace add <owner>/<repo>
claude plugin install baven-core@<marketplace>
```

## CLI tools

`global-CLAUDE.md` tells Claude these tools exist. Install them so its commands work.

### GNU replacements for macOS tools

Claude is told to use GNU syntax (`sed -i`, `date -d`, `stat -c`) so commands also work on Linux. On Linux these are already the defaults; skip this section.

| Tool | Package |
| --- | --- |
| coreutils (`date`, `stat`, `ls`, ...) | `coreutils` |
| `sed` | `gnu-sed` |
| `awk` | `gawk` |
| `find`, `xargs` | `findutils` |
| `tar` | `gnu-tar` |
| `make` | `make` |
| `grep` | `grep` |
| `bash` 5 | `bash` |

Homebrew installs most of these with a `g` prefix (`gsed`, `gdate`). Put their unprefixed `gnubin` directories before the system directories on `PATH`. Claude Code runs commands in a shell built from your shell profile, so set this in `~/.zshrc`:

```zsh
typeset -U path
path=(
  "$HOMEBREW_PREFIX"/opt/{gnu-sed,coreutils,gawk,findutils,gnu-tar,make,grep}/libexec/gnubin
  "$HOMEBREW_PREFIX/opt/libpq/bin"
  $path
)
```

`bash` needs no `PATH` entry; Homebrew links it into `$HOMEBREW_PREFIX/bin`. Check in a new shell:

```sh
sed --version | head -n 1
```

The output names GNU sed.

### Additional CLIs

| Tool | Purpose | Package |
| --- | --- | --- |
| `uv` | Python environments and tools | `uv` |
| `ast-grep` | structural search and rewrite | `ast-grep` |
| `sd` | literal find-and-replace | `sd` |
| `fd` | find files | `fd` |
| `yq` | YAML, TOML and XML | `yq` |
| `just` | task runner | `just` |
| `psql` | Postgres client | `libpq` (keg-only; on `PATH` via the snippet above) |
| `sshpass` | non-interactive SSH passwords | `hudochenkov/sshpass/sshpass` |
| `tree` | directory listing | `tree` |
| `wget` | downloads | `wget` |
| `agent-browser` | headless UI checks | `agent-browser` |
| `nvm` | Node versions | `nvm` (follow its caveats to load it in `~/.zshrc`) |
| `docker`, `colima` | containers; colima runs the Docker daemon on macOS | `docker`, `colima` |

## Rules and global instructions

Plugins cannot ship rules, so these are symlinked. Replace `<repo-path>` with the absolute path of your clone of this repo:

```sh
link() { [ -e "$2" ] && [ ! -L "$2" ] && mv "$2" "$2.bak"; ln -sfn "$1" "$2"; }
link <repo-path>/rules ~/.claude/rules
link <repo-path>/global-CLAUDE.md ~/.claude/CLAUDE.md
```

Safe to rerun. An existing real file or directory is moved to `<name>.bak`; an existing symlink is replaced.
