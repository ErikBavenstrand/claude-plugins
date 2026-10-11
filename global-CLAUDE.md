# Global

## Machine

- macOS on Apple Silicon (arm64). Docker runs through colima; run `colima start` if the daemon isn't reachable.
- Commands and scripts should also work on Linux. GNU userland (coreutils, `sed`, `awk`, `grep`, `find`, `xargs`, `tar`, `make`) and bash 5 come first on PATH, so use GNU syntax (`sed -i`, `date -d`, `stat -c`), not BSD.
- Extra CLIs: `ast-grep` (structural search and rewrite), `sd` (literal find-and-replace), `fd` (find files), `yq` (YAML/TOML/XML), `just` (task runner), `psql` (Postgres client), `sshpass`, `tree`, `wget`, `agent-browser` (headless UI checks; in the desktop app use the built-in browser). Node comes from `nvm`.

## Tooling

- uv manages every Python environment: `uv run <cmd>`, `uvx <tool>` outside a project. This keeps packages out of the system Python.
- Run linters, tests and type checkers through the project's runner (`uv run`, `npm run`, `just`) so its pinned versions and config apply.
