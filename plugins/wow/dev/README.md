# Agentcraft dev kit

Check addon changes on Windows before you `/reload` the game. Everything runs from `dev.ps1`:

```
powershell -NoProfile -ExecutionPolicy Bypass -File plugins/wow/dev/dev.ps1 <command>
```

| Command | What it does | Needs |
| --- | --- | --- |
| `check` | Runs `toc`, `rules`, `lint`, `types` and `test`. A step whose tool is missing is skipped and does not fail the run. | PowerShell 5.1 |
| `toc` | Checks `Agentcraft.toc`: every listed file exists (and matches its case on disk), every `.lua` file is listed, `Version` is `X.Y.Z`, the `Interface` and SavedVariables lines are present, and the load order is right (Core first, Library before the macro data files, Snapshot before its extensions, new files above `UI\Window.lua`). | PowerShell 5.1 |
| `rules` | Checks the owner's rules without running Lua. It reads `Macros/Data/*.lua` and `Modules/Layout.lua` (details below). When the game is installed, it also reads the newest account's `bindings-cache.wtf` and `macros-cache.txt` (read-only). | PowerShell 5.1 |
| `lint` | Runs luacheck with `plugins/wow/.luacheckrc`, which flags accidental globals, unused variables and typos. | luacheck |
| `types` | Runs `lua-language-server --check` with `plugins/wow/.luarc.json`, which flags wrong API arguments and misspelled `C_` functions. | LuaLS and the Ketho annotations |
| `test` | Runs the Lua 5.1 harness. It loads the addon against a WoW API mock and runs `dev/tests/*.lua`. | Lua 5.1 or LuaJIT |
| `globals` | Lists the globals the addon reads and writes. Use it when updating `.luacheckrc`. | PowerShell 5.1 |

Exit codes are 0 for pass, 1 for findings or failures, and 2 when a needed tool is missing.

Options:
- `-Strict` makes warnings fail `rules` too.
- `-NoGame` skips the live game section.
- `-WowPath <dir>` points at the game install. The script finds it through the registry by default.
- `-Addon <dir>` checks a copy of the addon, for example a scratch copy with a change you're trying out.

### What `rules` enforces

**Macros**
- Errors:
  - A macro names an item through `/use`, `/equip`, `/equipslot`, `#showtooltip`, or `/cast` of a known item. `/use 13` (a slot number) is allowed.
  - A `[mod]`, `[mod:shift]` or `[mod:ctrl]` condition.
  - `@mouseover` or `@cursor`.
  - `/petpassive` or `/petattack` (the owner sends the pet by hand).
  - A body over 255 characters, or a name over 16 characters.
  - The same macro name in two files.
  - A command the game menus already cover, such as `/camp`, `/readycheck`, `/screenshot`, or a `/run` or `/console` that toggles the map, repairs, sells junk or sets camera zoom.
- Warnings:
  - A live macro that shares a name with an `L.retired` entry.
- Info: a macro without `#showtooltip`, one marked `untested`, `/equip` of poles in `Fish` (an exception the owner approved), and back buttons that mirror a page-1 spell (allowed).

**Layouts**
- Errors:
  - A spell with more than one home on the same device. Your racial, an `item` and a `utility` slot count as homes too.
  - A flyout, `petauto` or `overflow` entry in a keyboard layout.
  - A bad controller key, or a use of the fixed Top face buttons.
  - A `macro = "X"` that is missing from the library, is retired, or belongs to another class.
- Info:
  - A back button that repeats a page home (a mirror, allowed).
  - A macro-only home, which stays empty until the macro is installed.
  - A macro that also casts spells that have their own home.

**Code**
- Warning: `CreateMacro` or `EditMacro` outside `Macros/Library.lua`, which breaks the rule that applying bars never installs macros.

**Live game**
- Error: a key bound to `MACRO X` where no macro `X` exists, as with F13 bound to `MACRO PetAttack`.
- Info:
  - An installed library macro whose text differs from the library.
  - An installed retired macro.

## Install the tools

You only need these for `lint`, `types` and `test`; `toc` and `rules` run with nothing installed.

```
scoop install luacheck                      # or put luacheck.exe (v1.2.0 release) in dev/tools/
scoop bucket add versions; scoop install lua51   # real Lua 5.1, matches the game
winget install --id DEVCOM.LuaJIT -e        # alternative to lua51 if you only use winget
winget install --id LuaLS.lua-language-server -e
git clone https://github.com/Ketho/vscode-wow-api plugins/wow/dev/tools/vscode-wow-api   # WoW API annotations for LuaLS
```

- Don't use `DEVCOM.Lua`: it is Lua 5.4, not the game's 5.1.
- `dev.ps1` looks for each tool in `dev/tools/`, then on PATH, then in `%LOCALAPPDATA%\Programs\*\` (and `*\bin\`) and `%LOCALAPPDATA%\Microsoft\WinGet\Links` or `Packages`, so a fresh winget or unzip install works without reopening the shell.
- Lua and luacheck can't open paths with characters outside the ANSI code page. `dev.ps1` runs them in `plugins/wow` with relative paths, and switches to the 8.3 short name when that folder's path isn't plain ASCII.
- In VS Code, install `sumneko.lua` and `ketho.wow-api`.
- In the game, BugGrabber and BugSack give full stack traces. `/console scriptErrors 1` shows errors as popups.

## The loop

1. Edit the addon in `plugins/wow/addon/Agentcraft`. The game loads it through the junction.
2. Run `dev.ps1 check`. Fix every error, and read the warnings.
3. In the game, `/reload`. The `Reload` macro on controller page 3 does the same.
4. Do the thing you changed, such as Apply, open the page, or fish.
5. `/reload` again so SavedVariables, `macros-cache.txt` and `bindings-cache.wtf` are written to disk.
6. Run `plugins/wow/scripts/wowdata.ps1 errors` to see new Lua errors, and `wowdata.ps1 character` or `binds` to see the result. Then run `dev.ps1 rules` again; its live section reads the files from step 5.

## The test harness

The harness lives in `dev/harness/`:

| File | Role |
| --- | --- |
| `run.lua` | Runner. It loads `dev/tests/*.lua` in sorted order and gives them `test`, `eq`, `ok`, `fail`, `note`, `noErrors` and `describeCalls`. |
| `harness.lua` | `H.boot{...}` makes a fresh world. It loads every TOC file with `("Agentcraft", ns)`, fires `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD` and `SPELLS_CHANGED`, then runs the timers. It returns an `env` with `:slash("controller apply")`, `:calls("CreateMacro")`, `:installMacro("Arcane")`, `:padSlot(1, "RT A")`, `:slotText(slot)`, `:fire(event, ...)`, `:runTimers(sec)` and `.W` (the world state: `macros`, `actions`, `bindings`, `inCombat`, `secret`, `chat`, `errors`). Options: `pet`, `db`, `charDB`, `macros`, `bindings`, `setup(W)` (before the addon loads), `loaded(env)` (after its files ran, before `ADDON_LOADED`: patch a module here) and `secret`. |
| `wow.lua` | The API mock: frames with scripts and events, C_Timer, the spellbook and flyouts, pets, bags and items, macros, action slots and the cursor, bindings, the Gamepad storage slots, and unit stats. With `W.secret` set, health, power, attack power, crit and dodge return secret values (`issecretvalue` is true; arithmetic, comparison and concatenation raise) and aura reads raise. `xpcall` passes extra arguments, as the game's does. Names the modern client lacks (`GetItemInfo`, `GetTalentInfo`) are nil. |
| `rules.lua` | The macro and layout rules in Lua. Keep them in step with `dev.ps1`. |
| `fixtures/hunter.lua` | A level 60 Orc hunter: spells, flyouts, items, bags, and a pet for `boot{ pet = true }`. |

Every API the addon calls that the mock doesn't define becomes an auto stub: it returns nil and is listed at the end of the run. To add a stub:

1. Open `wow.lua` and find `M.api(W, toc)`.
2. Add `A.Name = function(...) ... end`, or a field inside the matching `C_` table.
3. Read state from `W.fixture` or `W`. Call `Record(W, "Name", ...)` when a test needs to see the call.

A partly mocked `C_` namespace still auto-stubs the functions it doesn't define.

To add a test, create `dev/tests/NN_topic.lua`:

```lua
local H = require("harness")
test("what it checks", function()
  local env = H.boot({ pet = true, macros = { "Arcane" }, bindings = { F13 = "MACRO PetAttack" } })
  env:slash("controller apply")
  eq(env:slotText(env:padSlot(1, "RT A")), "macro:Arcane")
end)
```

`noErrors(env)` fails on Lua errors from event handlers and timers, and on the `error:` lines Core.lua prints when a `/ac` command raises (`env:slash` collects those). The mock refuses `CreateMacro`, `EditMacro`, `DeleteMacro`, `PlaceAction` and the `SetBinding*` calls while `env.W.inCombat` is true, but still records them, so a test can assert that nothing was attempted.

To run a single file or test, run Lua directly from `plugins/wow`: `luajit dev/harness/run.lua addon/Agentcraft dev/tests controller` (the last argument filters by test or file name). Set `AC_VERBOSE=1` to echo the addon's chat output.
