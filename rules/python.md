---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
---

# Python

- Match syntax to the project's `requires-python` (`X | None` needs 3.10+).
- Give standalone scripts outside a project PEP 723 inline metadata and a `#!/usr/bin/env -S uv run --script` shebang. They then run with their dependencies anywhere.
- To format or lint, use `ruff format` and `ruff check`.
- Run ruff through `uv run` when the project pins it, and through `uvx` otherwise.
