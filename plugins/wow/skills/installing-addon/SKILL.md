---
name: installing-addon
description: Use when the user wants to install or update the Agentcraft World of Warcraft addon bundled with this plugin, or when wow game data shows no Agentcraft snapshot.
---

# Installing the addon

The plugin bundles the Agentcraft addon in `${CLAUDE_PLUGIN_ROOT}/addon/Agentcraft`. Installing copies it into the game's `Interface/AddOns` folder.

The game can stay open: it loads addon files only on login and `/reload`.

1. Run:

   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/wowdata.ps1" install
   ```

   Check: the output names the AddOns folder it installed to. If it reports that WoW wasn't found, ask the user for the folder that holds `_retail_` or `_forever_` and add `-WowPath "<folder>"`.
2. Tell the user to type `/reload` in game (or log in), then `/reload` once more. The second reload writes the first snapshot to disk.
3. Run `overview`. Check: `snapshots` lists the character.

Running `install` again updates the addon to the plugin's version. It replaces the whole `Agentcraft` folder, so local edits there are lost.

For developing Agentcraft from a clone of the plugin repo, use `install -Link` instead. It links the AddOns folder to the clone, so edits load on `/reload`. It needs the existing `Agentcraft` folder removed first.
