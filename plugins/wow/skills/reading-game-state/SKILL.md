---
name: reading-game-state
description: Use when the user asks about their World of Warcraft character or game setup, such as gear, stats, talents, spells, pet, bags, gold, professions, quests, reputation, keybinds, action bars, addons, Lua errors or combat logs. Reads the data the TinkerKit addon and the game write to disk, so answers rest on the user's real state.
---

# Reading game state

The TinkerKit addon writes a full snapshot of the character on every `/reload` and logout. The game also writes keybinds, addon data and logs. `wowdata.ps1` reads all of it and prints JSON.

## Commands

Run with Windows PowerShell:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/wowdata.ps1" <command> [options]
```

| Command | Reads |
| --- | --- |
| `overview` | Install folder, characters with snapshot times, addon data files, logs, installed addons |
| `character [-Character Name] [-Path a/b]` | TinkerKit snapshot: `basics`, `stats`, `equipment`, `bags`, `skills`, `spellbook`, `talents`, `pet`, `buffs`, `reputation`, `quests`, `bars` |
| `sv -File Name [-Character Name] [-Path a/b]` | Any addon's SavedVariables file, such as `TradeSkillMaster` |
| `binds [-Grep regex]` | Keybinds, key to command |
| `errors [-Count n]` | Recent Lua errors from the console history |
| `log [-File name] [-Tail n] [-Grep regex]` | The newest combat log, or another file in `Logs` |
| `file -Path rel/path [-Grep regex]` | Any text file under the game folder, such as `WTF/Config.wtf` |

`-Path` walks into the data with `/` between keys, such as `-Path pet/spellbook`. Output over 40,000 characters is replaced by a key list; narrow it with `-Path`. Without `-Character`, the most recent snapshot is used.

## Process

1. Run `overview` first in a session. Check: a snapshot exists for the character the user means.
2. Fetch only the sections the question needs, using `-Path`.
3. Compare the snapshot `time` with the question. If the user changed something since, ask them to type `/reload` and read again.
4. Answer from the data. Name the values you used, such as item names, ranks and talent points.

If `overview` shows no snapshot, run the `installing-addon` skill.

## Gotchas

- Advice depends on the game version. The flavor folder tells you which: `_forever_` is WoW Forever, `_classic_era_` is Classic Era, `_retail_` is retail. Check class guides for that version before recommending a rotation or build.
- Talents in WoW Forever use the modern trait tree, so they appear under `talents` → `Trait tree`.
- Health, mana and some combat values show as `null`. The client marks them secret and addons can't read them.
- Names come in the client's language, and realm names in folder paths can differ from the in-game realm name.
- The combat log exists only while the user has `/combatlog` on. It stops on logout.
- On macOS or Linux the script needs PowerShell 7 (`pwsh`). Without it, read the files directly: snapshots are in `WTF/Account/<account>/SavedVariables/TinkerKit.lua` under `TinkerKitDB.modules.Snapshot`.
