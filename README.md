# claude-plugins

Erik Båvenstrand's Claude Code plugin marketplace (`bavenstrand`).

## Install

```
/plugin marketplace add ErikBavenstrand/claude-plugins
```

Then install a plugin with `/plugin install <plugin>@bavenstrand`.

## Develop locally

Add this checkout as a marketplace so plugins load in place from disk:

```
/plugin marketplace add ~/Code/claude-plugins
```

After editing a plugin, run `/reload-plugins` or start a new session. Validate with:

```
claude plugin validate .
```

## Layout

```
.claude-plugin/marketplace.json   marketplace catalog
plugins/<name>/                   one directory per plugin
```

Plugins don't set `version`, so each commit is picked up on update.
