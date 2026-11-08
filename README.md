# claude-plugins

A Claude Code setup: a plugin marketplace, plus rules and global instructions symlinked into `~/.claude`.

Setup order:

1. Install the plugins ([Install plugins](#install-plugins)).
2. Install the CLI tools and set up `PATH` ([CLI tools](#cli-tools)).
3. Symlink the rules and global instructions ([Rules and global instructions](#rules-and-global-instructions)).

Package names below are Homebrew formulae. On Linux, use the distro's package manager; names may differ.

## Plugins

### baven-core

- Skill `writing-for-agents`: rules for writing text an agent reads.
- Skill `fleshing-out`: interview the user in rounds until every decision in a plan is settled.
- Skill `researching`: research a question across the web, MCP tools and local files, scaling effort to the question; writes cited, confidence-rated findings to the scratchpad.
- Agent `researcher`: follows one lead for `researching`; the skill picks its model per lead.

### wow

Lets Claude read your World of Warcraft character and help you play it. Bundles the Agentcraft addon, which writes your full character state to disk on every `/reload` and logout, and adds an in-game window (`/ac`) for laying out action bars and keybinds.

- Skill `reading-game-state`: reads gear, stats, talents, spells, pet, bags, quests, reputation, keybinds, any addon's saved data, Lua errors and combat logs.
- Skill `installing-addon`: installs or updates Agentcraft in your WoW folder.
- Skill `extending-addon`: Agentcraft's structure and client API gotchas, for adding features.
- Script `scripts/wowdata.ps1`: the reader the skills run. Needs only Windows PowerShell; on macOS use PowerShell 7 (`pwsh`).

After installing the plugin, ask Claude to install the addon, then type `/reload` twice in game.

## Install plugins

Replace `<owner>/<repo>` with this repo's GitHub path and `<marketplace>` with the `name` in `.claude-plugin/marketplace.json`:

```sh
claude plugin marketplace add <owner>/<repo>
claude plugin install baven-core@<marketplace>
claude plugin install wow@<marketplace>
```

## CLI tools

`global-CLAUDE.md` and the rules tell Claude to use these tools. Install them so its commands work.

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
| `uv` | Python environments and tools; runs ruff for `rules/python.md` | `uv` |
| `shfmt` | format shell scripts (`rules/shell.md`) | `shfmt` |
| `shellcheck` | lint shell scripts (`rules/shell.md`) | `shellcheck` |
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
