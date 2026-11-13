-- Every macro in the library parses and follows the owner's rules.
local H = require("harness")

test("every library macro resolves and passes the rules", function()
  local env = H.boot()
  local L = env.ns.MacroLibrary
  ok(#L.macros > 0, "library has macros")
  local errors = {}
  for _, m in ipairs(L.macros) do
    local body, why = L.Resolve(m)
    if not body then errors[#errors + 1] = m.name .. ": can't resolve (" .. tostring(why) .. ")"
    else
      for _, p in ipairs(H.rules.CheckMacro(m, body)) do
        if p.severity == "error" then errors[#errors + 1] = "[" .. p.rule .. "] " .. p.msg
        elseif p.severity == "warn" then note("[" .. p.rule .. "] " .. p.msg) end
      end
    end
  end
  if #errors > 0 then fail(table.concat(errors, "\n")) end
end)

test("macro names are unique and fit 16 characters", function()
  local env = H.boot()
  local seen = {}
  for _, m in ipairs(env.ns.MacroLibrary.macros) do
    ok(not seen[m.name], "duplicate macro name " .. m.name)
    ok(#m.name <= 16, m.name .. " is longer than 16 characters")
    seen[m.name] = true
  end
end)

test("every macro a layout names exists in the library", function()
  local env = H.boot()
  local lib = {}
  for _, m in ipairs(env.ns.MacroLibrary.macros) do lib[m.name] = m end
  local missing = {}
  local function Walk(t, where)
    if type(t) ~= "table" then return end
    if type(t.macro) == "string" and not lib[t.macro] then missing[#missing + 1] = t.macro .. " (" .. where .. ")" end
    for k, v in pairs(t) do if type(v) == "table" then Walk(v, where .. "." .. tostring(k)) end end
  end
  Walk(env.ns.Layout.keyboard, "keyboard")
  Walk(env.ns.Layout.controller, "controller")
  if #missing > 0 then fail("layout names macros that aren't in the library: " .. table.concat(missing, ", ")) end
end)

test("every spell has one home per device (back-button mirrors are notes)", function()
  local env = H.boot()
  local errors = {}
  local classes = {}
  for class in pairs(env.ns.Layout.keyboard or {}) do classes[class] = true end
  for class in pairs(env.ns.Layout.controller or {}) do classes[class] = true end
  for class in pairs(classes) do
    for _, p in ipairs(H.rules.CheckLayout(env.ns.Layout, class)) do
      if p.severity == "error" then errors[#errors + 1] = p.msg else note(p.msg) end
    end
  end
  if #errors > 0 then fail(table.concat(errors, "\n")) end
end)

test("installing macros is refused in combat", function()
  local env = H.boot()
  env.W.inCombat = true
  env:resetCalls()
  env.ns.MacroLibrary.Install(env.ns.MacroLibrary.macros)
  eq(#env:calls("CreateMacro"), 0, "CreateMacro calls in combat")
  ok(env:chatText():find("combat"), "says why: " .. env:chatText())
end)
