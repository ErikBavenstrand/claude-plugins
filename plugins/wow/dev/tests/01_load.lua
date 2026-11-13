-- The addon loads like it does on /reload: every TOC file in order, then
-- ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD and the timers after it.
local H = require("harness")

test("addon loads without error", function()
  local env = H.boot()
  noErrors(env)
  eq(env.G.Agentcraft, env.ns, "global Agentcraft is the namespace")
  for _, name in ipairs({ "controller", "actionbars", "keybinds", "snapshot", "fishing" }) do
    ok(env.ns.modules[name], "module " .. name .. " registered")
    ok(env.ns.modules[name].active, "module " .. name .. " enabled after ADDON_LOADED")
  end
  ok(env.G.SlashCmdList.AGENTCRAFT, "/ac registered")
  eq(env.G.AgentcraftDB.loadCount, 1, "AgentcraftDB.loadCount")
  ok(env.ns.Layout and env.ns.MacroLibrary, "Layout and MacroLibrary loaded")
  H.collect(env)
end)

test("addon keeps old SavedVariables and counts loads", function()
  local env = H.boot({ db = { loadCount = 4, enabled = { Fishing = false } } })
  noErrors(env)
  eq(env.G.AgentcraftDB.loadCount, 5)
  ok(not env.ns.modules.fishing.active, "a module switched off stays off")
end)

test("only the expected globals are set", function()
  local env = H.boot()
  local allowed = {
    Agentcraft = true, AgentcraftDB = true, AgentcraftCharDB = true,
    SLASH_AGENTCRAFT1 = true, SLASH_AGENTCRAFT2 = true,
    -- Nothing else: ns.Capture no longer swaps print, and SnapshotCached no
    -- longer replaces ChatFrame_DisplayTimePlayed.
  }
  local extra = {}
  for _, name in ipairs(env:globalsWritten()) do
    if not allowed[name] then extra[#extra + 1] = name end
  end
  -- Run a command so code paths behind /ac get a chance to leak too.
  env:slash("spells")
  env:slash("keys")
  env:slash("")   -- opens the window
  local out = env.ns.Run(function() env.ns.Print("captured") end)
  ok(out:find("captured", 1, true), "ns.Run returns what the action printed")
  for _, name in ipairs(env:globalsWritten()) do
    if not allowed[name] then extra[#extra + 1] = name end
  end
  if #extra > 0 then fail("unexpected globals (taint risk, or a missing 'local'): " .. table.concat(extra, ", ")) end
end)

test("/ac help lists commands without error", function()
  local env = H.boot()
  env:resetCalls()
  env:slash("help")
  ok(env:chatText():find("/ac controller", 1, true), "help mentions /ac controller:\n" .. env:chatText())
  noErrors(env)
end)
