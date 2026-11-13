-- Applying the hunter controller layout (Controller.lua) and keyboard bars
-- (ActionBars.lua). Owner rule: applying bars never installs macros; a home
-- that wants a macro uses it only if installed, else the plain spell.
local H = require("harness")

test("applying the hunter controller layout never calls CreateMacro (no pet)", function()
  local env = H.boot()
  env:resetCalls()
  env:slash("controller apply")
  noErrors(env)
  ok(#env:calls("PlaceAction") > 0, "the layout placed something:\n" .. env:chatText())
  if #env:calls("CreateMacro") > 0 or #env:calls("EditMacro") > 0 then
    fail("Apply created or edited macros:\n" .. describeCalls(env, "CreateMacro") .. "\n" .. describeCalls(env, "EditMacro"))
  end
end)

-- With a pet out, page 3's { petauto = true } buttons use the library's
-- "Auto <ability>" macros, but only once installed; Apply never creates them.
test("applying the hunter controller layout never calls CreateMacro (pet out)", function()
  local env = H.boot({ pet = true })
  env:resetCalls()
  env:slash("controller apply")
  noErrors(env)
  if #env:calls("CreateMacro") > 0 or #env:calls("EditMacro") > 0 then
    fail("Apply created or edited macros (petauto toggles):\n" .. describeCalls(env, "CreateMacro") .. "\n" .. describeCalls(env, "EditMacro"))
  end
end)

test("a petauto button uses its Auto macro only once installed", function()
  local env = H.boot({ pet = true, macros = { "Auto Growl" } })
  env:slash("controller apply")
  noErrors(env)
  local placed = {}
  for slot = 181, 276 do local t = env:slotText(slot); if t then placed[t] = true end end
  ok(placed["macro:Auto Growl"], "the installed Auto Growl macro was placed")
  ok(not placed["macro:Auto Bite"], "Auto Bite isn't installed, so it isn't placed")
end)

test("a macro home uses the plain spell until the macro is installed", function()
  local env = H.boot()
  env:slash("controller apply")
  local slot = env:padSlot(1, "RT A")   -- { macro = "Arcane", "Arcane Shot" }
  eq(env:slotText(slot), "spell:Arcane Shot", "RT A without the Arcane macro")

  local env2 = H.boot({ macros = { "Arcane" } })
  env2:slash("controller apply")
  eq(env2:slotText(slot), "macro:Arcane", "RT A with the Arcane macro installed")
end)

test("homes for spells you haven't learned stay empty", function()
  local env = H.boot()
  env:slash("controller apply")
  -- LT Right = { "Bestial Wrath", "Deterrence", "Trueshot Aura" }; the fixture knows none.
  eq(env:slotText(env:padSlot(1, "LT Right")), nil, "LT Right")
end)

test("a stale back-button macro binding is cleared (F13 MACRO PetAttack)", function()
  local env = H.boot({ bindings = { F13 = "MACRO PetAttack" } })
  env:slash("controller apply")
  noErrors(env)
  ok(env.W.bindings.F13 ~= "MACRO PetAttack", "F13 still points at the missing PetAttack macro")
  for key, action in pairs(env.W.bindings) do
    local name = action:match("^MACRO (.+)$")
    if name then ok(env.G.GetMacroIndexByName(name) > 0, key .. " is bound to MACRO " .. name .. ", which doesn't exist") end
  end
end)

test("applying the keyboard bars never calls CreateMacro", function()
  local env = H.boot()
  env:resetCalls()
  env:slash("spells apply")
  noErrors(env)
  ok(#env:calls("PlaceAction") > 0, "bars were filled:\n" .. env:chatText())
  eq(#env:calls("CreateMacro"), 0, "CreateMacro calls")
  eq(#env:calls("EditMacro"), 0, "EditMacro calls")
end)

test("keyboard bar 1 Q holds Arcane Shot without the macro", function()
  local env = H.boot()
  env:slash("spells apply")
  eq(env:slotText(1), "spell:Arcane Shot", "slot 1 (Q)")
end)

-- Layout.lua paddles = {}: the owner left the back buttons unbound for now,
-- so Apply unbinds F13-F16 and SHIFT-F13..F16.
test("Apply unbinds back buttons that have no home", function()
  local env = H.boot({ bindings = { F16 = "SPELL Concussive Shot", ["SHIFT-F15"] = "SPELL Freezing Trap" } })
  env:slash("controller apply")
  noErrors(env)
  for _, k in ipairs({ "F13", "F14", "F15", "F16", "SHIFT-F13", "SHIFT-F14", "SHIFT-F15", "SHIFT-F16" }) do
    eq(env.W.bindings[k], nil, k)
  end
end)