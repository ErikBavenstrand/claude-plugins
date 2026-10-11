---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
---

# Python

- Match syntax to the project's `requires-python` (`X | None` needs 3.10+).
- Standalone scripts outside a project get PEP 723 inline metadata and a `#!/usr/bin/env -S uv run --script` shebang, so they run with their dependencies anywhere.
