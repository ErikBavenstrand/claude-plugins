-- Bars, binds and macros can't change in combat: every apply must refuse
-- before touching anything.
local H = require("harness")

local CHANGES = { "PlaceAction", "PickupAction", "SetBinding", "SetBindingSpell", "SetBindingMacro",
  "SaveBindings", "CreateMacro", "EditMacro", "DeleteMacro" }

local function AssertUntouched(env, what)
  for _, name in ipairs(CHANGES) do
    if #env:calls(name) > 0 then fail(what .. " in combat called " .. name .. ":\n" .. describeCalls(env, name)) end
  end
  ok(env:chatText():lower():find("combat"), what .. " says it can't run in combat; chat was:\n" .. env:chatText())
end

for _, cmd in ipairs({ "controller apply", "controller undo", "spells apply", "spells undo", "keys apply", "keys undo" }) do
  test("/ac " .. cmd .. " is refused in combat", function()
    local env = H.boot()
    -- Undo needs something to undo.
    if cmd:find("undo") then
      env:slash((cmd:gsub("undo", "apply")))
    end
    env.W.inCombat = true
    env:resetCalls()
    env:slash(cmd)
    noErrors(env)
    AssertUntouched(env, "/ac " .. cmd)
  end)
end
