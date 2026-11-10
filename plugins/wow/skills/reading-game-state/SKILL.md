---
name: reading-game-state
description: Use when the user asks about their World of Warcraft character or game setup, such as gear, stats, talents, spells, pet, bags, gold, professions, quests, reputation, keybinds, action bars, addons, Lua errors or combat logs. Reads the data the Agentcraft addon and the game write to disk, so answers rest on the user's real state.
---

# Reading game state

The Agentcraft addon writes a full snapshot of the character on every `/reload` and logout. The game also writes keybinds, addon data and logs. `wowdata.ps1` reads all of it and prints JSON.

## Commands

Run with Windows PowerShell:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/wowdata.ps1" <command> [options]
```

| Command | Reads |
| --- | --- |
| `overview` | Install folder, characters with snapshot times, addon data files, logs, installed addons |
| `character [-Character Name] [-Path a/b]` | Agentcraft snapshot; sections listed below |
| `sv -File Name [-Character Name] [-Path a/b]` | Any addon's SavedVariables file, such as `TradeSkillMaster` |
| `binds [-Grep regex]` | Keybinds, key to command |
| `errors [-Count n]` | Recent Lua errors from the console history |
| `log [-File name] [-Tail n] [-Grep regex]` | The newest combat log, or another file in `Logs` |
| `file -Path rel/path [-Grep regex]` | Any text file under the game folder, such as `WTF/Config.wtf` |

## Snapshot sections

| Section | Holds |
| --- | --- |
| `basics`, `stats`, `combatStats` | Level, XP, gold, zone; primary stats; crit, hit, haste, defense, resistances, spell power |
| `equipment`, `gear` | Equipped items; `gear` adds enchant, suffix and gem IDs plus full tooltip text |
| `bags`, `bagItems` | Bag contents; `bagItems` adds item IDs, quality and tooltips |
| `skills`, `spellbook`, `talents` | All skills including weapon skills; spells with ranks; talents with descriptions |
| `pet` | Hunter or warlock pet: stats, happiness, training points, abilities, action bar |
| `questLog`, `completedQuests`, `quests` | Quests with objectives and progress; IDs of every turned-in quest |
| `reputation`, `currencyPvp`, `buffs` | Standings; currencies, honor and PvP stats; active buffs |
| `macros`, `bars`, `collections` | Macro text; action bar slots with keys; mounts, companions, equipment sets |
| `controller` | Controller mode on/off, the connected pad, controller settings, and every pad button binding (`PADDUP`, `PAD1`, `PADLTRIGGER` and so on) with what it does |
| `social`, `addons`, `apiProbe` | Friends, guild roster, group; installed addons; which APIs the client has |
| `bank`, `mail`, `recipes`, `flightPaths`, `stable`, `auctions` | Saved when the user last opened that window; each has a `seen` time |
| `playedTime`, `lockouts` | Asked from the server shortly after login |

A missing window-based section means the user hasn't opened that window since installing Agentcraft. Ask them to open it once, wait a second, then `/reload`. Tell the user how old a `seen` time is when it matters.

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
- Default controller bindings never reach `bindings-cache.wtf`; the `binds` command shows only keys the user changed. Read the snapshot's `controller` section for the full pad layout.
- The combat log exists only while the user has `/combatlog` on. It stops on logout.
- On macOS or Linux the script needs PowerShell 7 (`pwsh`). Without it, read the files directly: snapshots are in `WTF/Account/<account>/SavedVariables/Agentcraft.lua` under `AgentcraftDB.modules.Snapshot`.
