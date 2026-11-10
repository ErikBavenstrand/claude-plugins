---
name: extending-addon
description: Use when adding or changing a feature in the Agentcraft World of Warcraft addon, such as a new module, window page, action-bar profile, keybind layout or snapshot field. Holds the addon's structure and the client API gotchas.
---

# Extending Agentcraft

The addon source is in `${CLAUDE_PLUGIN_ROOT}/addon/Agentcraft`. Edit the copy the game loads: the plugin repo clone when it is linked with `install -Link`, otherwise the game's `Interface/AddOns/Agentcraft` folder.

## Structure

| File | Role |
| --- | --- |
| `Agentcraft.toc` | Load order. Add new files above `UI\Window.lua`. |
| `Core.lua` | `ns.RegisterModule`, `ns.RegisterPage`, `ns.RegisterCommand`, `ns.RegisterAction`, `ns.Run`, saved settings |
| `UI/Widgets.lua` | Shared look: `UI.Slot`, `UI.Header`, `UI.Button`, `UI.Text`, `UI.Swatch`, `UI.DescribeCommand` |
| `UI/Window.lua` | The `/ac` window: sidebar from registered pages, header, footer buttons, auto-refresh |
| `UI/Settings.lua` | Module switches, tool buttons, log |
| `Modules/ActionBars.lua` | Fills bars from per-class profiles (`M.profiles.<CLASS>`) and the shared `M.utility` item bar |
| `Modules/Keybinds.lua` | One key layout for bars 1-3 and the pet bar |
| `Modules/Snapshot.lua` | Writes the character state to SavedVariables. Skips saves while the client reports an empty character. Exposes `M.AddSection`, `M.SetCached`, `M.On` and `M.util` |
| `Modules/SnapshotMore.lua` | Sections readable at any time. Add one with `M.AddSection(name, fn)` |
| `Modules/SnapshotCached.lua` | Data only readable with a window open or after a server reply. Store it with `M.SetCached(name, table)`, triggered from `M.On(event, fn)` |
| `Modules/Controller.lua` | Fills the native Gamepad UI bars (3 pages; Top/Left LT/Right RT/Bottom LT+RT; D-pad and face diamonds) and binds Steam Deck back buttons (F13-F16, plus LT layer) from `M.layouts.<CLASS>`. Keys look like `"RT A"` or `"none Up"`. Its header explains the Gamepad UI rules (fixed Top face buttons, flyouts as radials, Blizzard's pet radials) |
| `Macros/Library.lua` | Macro library core: categories, `L.Add`, placeholders (`{PETFOOD}`, `{FOOD}`, `{DRINK}`, `{FISHINGPOLE}`, `{MAINHAND}`, `{OFFHAND?}`), install state, install, remove and pick up. Its header lists every macro field and the macro conventions |
| `Macros/Data/*.lua` | Macro definitions: one file per class, plus `General.lua` and `Racial.lua`. Add a macro with `L.Add({...})`; add a new file to the TOC above `Macros\Page.lua` |
| `Macros/Page.lua` | Library page: "For you"/"Everything" switch, search, tag chips, macro cards with tag pills, detail panel |

Tags are worked out from a macro's `class`, `race`, `profession`, `category`, `tags` and `untested` fields. Set `class`, `race` and `profession` whenever a macro needs them: the page hides macros that don't fit the character unless the user picks "Everything". Keep `tags` to short lowercase topics that already exist (such as `opener`, `defensive`, `group`, `travel`) before inventing new ones, and keep macro names unique across all data files.
| `Modules/_Template.lua` | Copy this to start a module. It shows every registration call. |

When adding a macro, follow the conventions in the `Macros/Library.lua` header. Cite where the macro comes from in the data file's header, and set `untested = true` until the user confirms it works in game.

A page's `actions` become footer buttons. `Build` runs once; `Refresh` runs on open, after each action and when bars, binds, bags or spells change.

## Process

1. Copy `_Template.lua` for a new module, or edit the module that owns the feature.
2. Build UI only from `ns.UI` widgets, so pages share one look.
3. Wrap client API calls that may be missing in an existence check, such as `C_Item and C_Item.GetItemInfo`. Friends run different game versions.
4. Ask the user to `/reload` and try it. Check: run `wowdata.ps1 errors` from the `reading-game-state` skill; no new Agentcraft errors.
5. Bump `## Version` in `Agentcraft.toc` when the change is done.

## Client API gotchas

- The global `GetItemInfo` is missing in modern-based clients. Use `C_Item.GetItemInfo`.
- Spellbook: `C_SpellBook.GetSpellBookItemInfo(i, Enum.SpellBookSpellBank.Player)`, with the classic `GetSpellBookItemName` as fallback.
- WoW Forever talents use `C_ClassTalents` and `C_Traits`. `GetTalentInfo` and `UnitCharacterPoints` don't exist there.
- Health, mana and some combat values are secret: storing them gives `nil` in SavedVariables.
- Changing bars or binds fails in combat. Check `InCombatLockdown()` first.
- SavedVariables reach disk only on `/reload` and logout.
- Bar slots: bar 1 = 1-12, bottom left = 61-72, bottom right = 49-60, right = 25-36, right 2 = 37-48. Pet bar binds are `BONUSACTIONBUTTON1-10`.
