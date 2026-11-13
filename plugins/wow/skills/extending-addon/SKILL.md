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
| `Core.lua` | `ns.RegisterModule`, `ns.RegisterPage`, `ns.RegisterCommand`, `ns.RegisterAction`, `ns.Run`, saved settings. Runs each module's `OnEnable` and event handlers in `xpcall`, so one failing module never stops the others. Print with `ns.Print` or `ns.Out` |
| `UI/Widgets.lua` | Shared look: `UI.Slot`, `UI.Header`, `UI.Button`, `UI.Text`, `UI.Swatch`, `UI.DescribeCommand` |
| `UI/Window.lua` | The `/ac` window: sidebar from registered pages, header, footer buttons, auto-refresh. A page whose `Build` raises shows the error in the footer and is retried on the next visit |
| `UI/Settings.lua` | Module switches, tool buttons, log |
| `Modules/Layout.lua` | Per-class layouts, one per device: `L.keyboard.<CLASS>` (bars 1-2, plain keybinds, no flyouts) and `L.controller.<CLASS>` (3 pages of `"RT A"`-style keys with radials, plus back buttons). Controller page 3 holds Steam Deck helpers, `{ overflow = true }` buttons that take every known spell without another controller home, and `{ petauto = true }` pet autocast toggles. Its header lists the entry forms and the rules: one permanent home per spell, alternatives only for either-or talents or same-role upgrades, no spell in two homes |
| `Modules/ActionBars.lua` | Fills keyboard bars 1-2 from `Layout.lua` (or `M.profiles.<CLASS>` for classes without one), the shared `M.utility` Alt bar, and the side bars. Backs up the bars on the first Apply only; Undo restores macros by name |
| `Modules/Keybinds.lua` | One key layout for bars 1-3 and the pet bar. Backs up the active binding set (account or character) |
| `Modules/Snapshot.lua` | Writes the character state to SavedVariables (see the gotchas). Exposes `M.AddSection`, `M.SetCached`, `M.On` and `M.util` |
| `Modules/SnapshotMore.lua` | Sections readable at any time. Add one with `M.AddSection(name, fn)` |
| `Modules/SnapshotCached.lua` | Data only readable with a window open or after a server reply. Store it with `M.SetCached(name, table)`, triggered from `M.On(event, fn)` |
| `Modules/Controller.lua` | Fills the native Gamepad UI bars (3 pages; Top/Left LT/Right RT/Bottom LT+RT; D-pad and face diamonds) and binds Steam Deck back buttons (F13-F16, plus LT layer) from `Layout.lua`. Holds the entry resolver (spells, flyouts, macros, items, racials) that ActionBars reuses. Apply deletes retired Agentcraft macros and unbinds their keys first. Without the Gamepad UI it binds only the back buttons. Its header explains the Gamepad UI rules |
| `Modules/Fishing.lua` | Puts your weapons back 15 s after your last fishing cast ends, or when you mount. Warns when the lure runs out. Remembers weapons in `AgentcraftCharDB.weapons` |
| `Macros/Library.lua` | Macro library core: categories, `L.Add`, install state, install, remove and pick up. Install and Remove never touch a player's own macro of the same name (state `taken`), and Remove unbinds the macro's keys. Its header lists every macro field and the macro conventions |
| `Macros/Data/*.lua` | Macro definitions: one file per class, plus `General.lua` and `Racial.lua`. Add a macro with `L.Add({...})`; add a new file to the TOC above `Macros\Page.lua` |
| `Macros/Page.lua` | Library page: "For you"/"Everything" switch, search, tag chips, macro cards with tag pills, detail panel |
| `Modules/_Template.lua` | Copy this to start a module. It shows every registration call |

Tags are worked out from a macro's `class`, `race`, `profession`, `category`, `tags` and `untested` fields. Set `class`, `race` and `profession` whenever a macro needs them: the page hides macros that don't fit the character unless the user picks "Everything". Keep `tags` to short lowercase topics that already exist (such as `opener`, `defensive`, `group`, `travel`) before inventing new ones, and keep macro names unique across all data files.

When adding a macro, follow the conventions in the `Macros/Library.lua` header. Cite where the macro comes from in the data file's header, and set `untested = true` until the user confirms it works in game.

Applying bars or a layout never creates macros; a macro home uses the plain spell until the user installs the macro on the Macros page. Controller `petauto` buttons use the library's "Auto <ability>" macros (Macros/Data/Hunter.lua, matched by `petAbility`) only once installed. Back buttons may mirror a page-1 spell; the hunter layout leaves them empty for now, and Apply unbinds any back button without a home.

A page's `actions` become footer buttons. `Build` runs once; `Refresh` runs on open, after each action and when bars, binds, bags or spells change.

## Process

1. Copy `_Template.lua` for a new module, or edit the module that owns the feature. Build UI only from `ns.UI` widgets, so pages share one look.
2. Wrap client API calls that may be missing in an existence check, such as `C_Item and C_Item.GetItemInfo`. Friends run different game versions.
3. Run the dev kit:

   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/dev/dev.ps1" check
   ```

   Check: no new failures in `toc`, `rules`, `lint` or `test`. `dev/README.md` lists what each step checks and how to add a test in `dev/tests`.
4. Ask the user to `/reload`, try the feature, wait 10 seconds, then `/reload` again. The second reload writes the snapshot to disk.
5. Run `wowdata.ps1 errors` from the `reading-game-state` skill. Check: no new console Lua errors and `0 errors` in the snapshot line.
6. Bump `## Version` in `Agentcraft.toc` when the change is done.

## Client API gotchas

- The global `GetItemInfo` is missing in modern-based clients. Use `C_Item.GetItemInfo`.
- Spellbook: `C_SpellBook.GetSpellBookItemInfo(i, Enum.SpellBookSpellBank.Player)`, with the classic `GetSpellBookItemName` as fallback.
- WoW Forever talents use `C_ClassTalents` and `C_Traits`. `GetTalentInfo` and `UnitCharacterPoints` don't exist there.
- Health, power and many combat values (attack power, auras) are secret while tainted. Arithmetic, comparison or concatenation on them throws. Check `issecretvalue(v)` first, as `Safe` and `Keep` in `Modules/Snapshot.lua` do.
- `GetProfessions()` returns nils for empty slots, so `ipairs({ GetProfessions() })` stops early. Take the returns by name.
- Changing bars or binds fails in combat. Check `InCombatLockdown()` first.
- SavedVariables reach disk only on `/reload` and logout. Snapshot saves 10 s after a change (after combat ends), because on logout the character data is often already gone and that save is skipped. A section that fails or turns secret keeps its last good values, marked with `staleSince`/`lastError` or `secretKept`.
- Never reassign `print` or other Blizzard globals; it taints. Route output through `ns.Out`.
- Bar slots: bar 1 = 1-12, bottom left = 61-72, bottom right = 49-60, right = 25-36, right 2 = 37-48, bars 6-8 = 145-180 (`MULTIACTIONBAR5-7BUTTON`). Pet bar binds are `BONUSACTIONBUTTON1-10`.
