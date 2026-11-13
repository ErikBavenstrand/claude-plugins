-- Regression tests for the fixes from the code review: module start-up
-- isolation, macro removal clearing binds, Controller Undo never binding
-- dead macros, and snapshots surviving secret values.
local H = require("harness")

-- Every key bound to "MACRO X" must have a macro X in /macro.
local function NoDeadMacroBinds(env, when)
  for key, action in pairs(env.W.bindings) do
    local name = action:match("^MACRO (.+)$")
    if name then ok(env.G.GetMacroIndexByName(name) > 0, when .. ": " .. key .. " is bound to MACRO " .. name .. ", which doesn't exist") end
  end
end

-- Core.lua -------------------------------------------------------------------

test("one module's OnEnable error doesn't stop the modules after it", function()
  local env = H.boot({
    loaded = function(e)
      -- ActionBars is the first module in the TOC.
      e.ns.modules.actionbars.OnEnable = function() error("boom from ActionBars") end
    end,
  })
  eq(env.ns.order[1].name, "ActionBars", "first module (the test breaks it)")
  ok(not env.ns.modules.actionbars.active, "ActionBars stays off after its OnEnable raised")
  for _, name in ipairs({ "keybinds", "snapshot", "controller", "fishing" }) do
    local mod = env.ns.modules[name]
    ok(mod.active, name .. " still enabled")
    ok(type(mod.db) == "table" and type(mod.charDB) == "table", name .. " got its db")
  end
  ok(env:chatText():find("ActionBars failed to start", 1, true), "the failure is announced:\n" .. env:chatText())
  local reported = false
  for _, e in ipairs(env.W.errors) do if e:find("boom from ActionBars", 1, true) then reported = true end end
  ok(reported, "the error reaches geterrorhandler")
  eq(env.G.AgentcraftDB.enabled.ActionBars, nil, "a failed start isn't saved as switched off")
end)

test("one module's event handler error doesn't stop the others", function()
  local env = H.boot({
    loaded = function(e)
      e.ns.modules.actionbars.events = e.ns.modules.actionbars.events or {}
      e.ns.modules.actionbars.events.PLAYER_REGEN_ENABLED = function() error("boom in handler") end
    end,
  })
  local hit = false
  env.ns.modules.keybinds.events = env.ns.modules.keybinds.events or {}
  env.ns.modules.keybinds.events.PLAYER_REGEN_ENABLED = function() hit = true end
  env:fire("PLAYER_REGEN_ENABLED")
  ok(hit, "Keybinds (after ActionBars) still got the event")
end)

-- Macros/Library.lua -----------------------------------------------------------

local function LibMacro(env, name)
  for _, m in ipairs(env.ns.MacroLibrary.macros) do if m.name == name then return m end end
  error("no library macro " .. name)
end

test("removing a library macro clears the keys bound to it", function()
  local env = H.boot()
  local m = LibMacro(env, "Arcane")
  env.ns.MacroLibrary.Install({ m })
  ok(env.G.GetMacroIndexByName("Arcane") > 0, "Arcane installed:\n" .. env:chatText())
  env.W.bindings.F5 = "MACRO Arcane"
  env.W.bindings["SHIFT-F5"] = "MACRO Arcane"
  env:resetCalls()
  env.ns.MacroLibrary.Remove({ m })
  noErrors(env)
  eq(env.G.GetMacroIndexByName("Arcane"), 0, "Arcane deleted")
  eq(env.W.bindings.F5, nil, "F5")
  eq(env.W.bindings["SHIFT-F5"], nil, "SHIFT-F5")
  ok(#env:calls("SaveBindings") > 0, "bindings saved")
end)

test("removing never deletes the player's own macro of the same name", function()
  local env = H.boot({ setup = function(W)
    W.macros[1] = { name = "Arcane", icon = "x", body = "/say mine", perChar = false }
  end })
  env.W.bindings.F5 = "MACRO Arcane"
  env.ns.MacroLibrary.Remove({ LibMacro(env, "Arcane") })
  ok(env.G.GetMacroIndexByName("Arcane") > 0, "the player's Arcane is kept")
  eq(env.W.bindings.F5, "MACRO Arcane", "its binding is kept")
end)

-- Modules/Controller.lua -------------------------------------------------------

test("Controller Undo never binds a key to a macro that doesn't exist", function()
  local env = H.boot({ bindings = { F16 = "MACRO Ghost", ["SHIFT-F15"] = "SPELL Arcane Shot" },
    -- Layout.lua leaves the back buttons empty for now; give R5 a home here.
    loaded = function(e) e.ns.Layout.controller.HUNTER.paddles = { R5 = { "Concussive Shot" } } end })
  env:slash("controller apply")
  noErrors(env)
  eq(env.W.bindings.F16, "SPELL Concussive Shot", "F16 after Apply")
  env:resetCalls()
  env:slash("controller undo")
  noErrors(env)
  eq(env.W.bindings["SHIFT-F15"], "SPELL Arcane Shot", "SHIFT-F15 is put back")
  ok(env.W.bindings.F16 ~= "MACRO Ghost", "F16 isn't bound back to the missing Ghost macro")
  ok(env:chatText():find("couldn't put back", 1, true), "Undo names what it couldn't restore:\n" .. env:chatText())
  NoDeadMacroBinds(env, "after Undo")
end)

test("Apply deletes a retired macro, unbinds its keys, and Undo doesn't rebind them", function()
  local env = H.boot({
    bindings = { F13 = "MACRO PetAttack", F20 = "MACRO PetAttack" },
    setup = function(W)
      W.macros[1] = { name = "PetAttack", icon = "x", body = "/petattack [@target,harm,nodead]", perChar = false }
    end,
  })
  env:slash("controller apply")
  noErrors(env)
  eq(env.G.GetMacroIndexByName("PetAttack"), 0, "retired PetAttack deleted")
  NoDeadMacroBinds(env, "after Apply")
  eq(env.W.bindings.F20, nil, "F20 (not a back button) unbound with the macro")
  env:slash("controller undo")
  noErrors(env)
  NoDeadMacroBinds(env, "after Undo")
end)

test("Apply binds the back buttons without the Gamepad UI and leaves the bars alone", function()
  local env = H.boot({ setup = function(W) W.gamepad = false end,
    loaded = function(e) e.ns.Layout.controller.HUNTER.paddles = { R5 = { "Concussive Shot" } } end })
  env:resetCalls()
  env:slash("controller apply")
  noErrors(env)
  eq(env.W.bindings.F16, "SPELL Concussive Shot", "F16 (back button R5)")
  ok(env:chatText():find("bars skipped", 1, true), "Apply says the bars were skipped: " .. env:chatText())
  eq(#env:calls("PlaceAction"), 0, "no bar changes without the Gamepad UI")
  env:slash("controller undo")
  noErrors(env)
  eq(#env:calls("PlaceAction"), 0, "Undo doesn't touch the bars either")
end)

-- Modules/Snapshot.lua ---------------------------------------------------------

local function Snap(env)
  local db = env.ns.modules.snapshot.db
  return db and db["Tester-Mockrealm"]
end

local function SaveNow(env)
  local _, stored = env.ns.modules.snapshot:Save()
  ok(stored, "snapshot stored")
  return Snap(env)
end

test("snapshot sections save with readable values", function()
  local env = H.boot()
  noErrors(env)
  local snap = SaveNow(env)
  ok(type(snap.basics) == "table", "basics is a table: " .. tostring(snap.basics))
  eq(snap.basics.health, "3000 / 3500", "basics.health")
  ok(type(snap.stats) == "table", "stats is a table: " .. tostring(snap.stats))
  eq(snap.stats["Melee attack power"], 340, "melee attack power")
  eq(snap.stats.Agility, 62, "agility")
  ok(type(snap.buffs) == "table" and snap.buffs[1] == "Aspect of the Hawk", "buffs: " .. tostring(snap.buffs))
end)

test("snapshot sections survive secret values", function()
  local env = H.boot({ secret = true })
  noErrors(env)
  local snap = SaveNow(env)
  ok(type(snap.basics) == "table", "basics is a table: " .. tostring(snap.basics))
  eq(snap.basics.health, "<secret> / <secret>", "basics.health")
  ok(type(snap.stats) == "table", "stats is a table: " .. tostring(snap.stats))
  eq(snap.stats.Agility, 62, "agility is readable while attack power is secret")
  eq(snap.stats.Armor, 2100, "armor")
  eq(snap.stats["Melee attack power"], "<secret>", "melee attack power")
  eq(snap.stats["Ranged crit %"], "<secret>", "ranged crit")
  eq(snap.stats["Ranged damage"], "<secret>", "ranged damage")
  for name, v in pairs(snap) do
    if type(v) == "table" then
      for k, x in pairs(v) do
        ok(not env.G.issecretvalue(x), name .. "." .. tostring(k) .. " stored a raw secret (nil on disk)")
      end
    end
  end
end)

test("a save while values are secret keeps the last readable ones", function()
  local env = H.boot()
  SaveNow(env)
  env.W.secret = true
  local snap = SaveNow(env)
  eq(snap.basics.health, "3000 / 3500", "health kept from the readable save")
  eq(snap.stats["Melee attack power"], 340, "attack power kept")
  ok(type(snap.stats.secretKept) == "table" and #snap.stats.secretKept > 0, "stats.secretKept lists what was kept")
  ok(type(snap.buffs) == "table" and snap.buffs[1] == "Aspect of the Hawk", "buff list kept: " .. tostring(snap.buffs))
  ok(snap.buffs.lastError and snap.buffs.staleSince, "buffs marked stale with the error")
end)

test("snapshot waits for combat to end before saving", function()
  local env = H.boot()
  local mod = env.ns.modules.snapshot
  local saves, save = 0, mod.Save
  mod.Save = function(...) saves = saves + 1; return save(...) end
  env.W.inCombat = true
  env:fire("PLAYER_MONEY")
  env:runTimers(15)
  eq(saves, 0, "saves in combat")
  env.W.inCombat = false
  env:fire("PLAYER_REGEN_ENABLED")
  env:runTimers(15)
  noErrors(env)
  eq(saves, 1, "saves after combat")
end)

test("every snapshot section saves without an error (pet out)", function()
  local env = H.boot({ pet = true })
  local snap = SaveNow(env)
  for name, v in pairs(snap) do
    if type(v) == "string" and v:find("^error") then fail(name .. ": " .. v) end
  end
  ok(type(snap.bars) == "table", "bars: " .. tostring(snap.bars))
  noErrors(env)
end)

-- UI/Window.lua ------------------------------------------------------------------

test("/ac opens the window and every page builds and refreshes", function()
  local env = H.boot({ pet = true })
  env:slash("")
  noErrors(env)
  ok(#env.ns.pages > 0, "pages registered")
  for _, page in ipairs(env.ns.pages) do
    env.ns.OpenPage(page.id)
    ok(page.frame, "page " .. tostring(page.id) .. " failed to build")
    if page.Refresh then
      local okR, err = pcall(page.Refresh, page)
      ok(okR, "page " .. tostring(page.id) .. " Refresh: " .. tostring(err))
    end
    if page.Status then
      local okS, err = pcall(page.Status, page)
      ok(okS, "page " .. tostring(page.id) .. " Status: " .. tostring(err))
    end
  end
  noErrors(env)
end)
