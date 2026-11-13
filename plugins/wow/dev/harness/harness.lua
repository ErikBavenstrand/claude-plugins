-- Test-facing API: boot a fresh mocked game with the addon loaded.
--
--   local H = require("harness")
--   local env = H.boot({ fixture = "hunter", pet = true })
--   env:slash("controller apply")
--   assert(#env:calls("CreateMacro") == 0)
--
-- boot options:
--   fixture   name of a file in harness/fixtures (default "hunter")
--   pet       true to give the fixture its pet (fixture.petData)
--   db, charDB  SavedVariables tables to start from (default nil, a fresh install)
--   macros    { "Arcane", ... } library macros already installed (by name)
--   bindings  { F13 = "MACRO PetAttack", ... } keybinds before login
--   setup(W)  called after the world is made, before the addon loads
--   loaded(env) called after the addon files ran, before ADDON_LOADED (to
--             patch a module, e.g. make its OnEnable raise)
--   secret    true to start with combat values secret (W.secret; see wow.lua)
local wow = require("wow")
local rules = require("rules")

local H = { rules = rules, wow = wow }
H.addonDir = nil   -- set by run.lua
H.addonName = "Agentcraft"

local function LoadFixture(name)
  local f = assert(loadfile(H.harnessDir .. "/fixtures/" .. name .. ".lua"))
  return f()
end

local Env = {}
Env.__index = Env

function Env:fire(event, ...) wow.FireEvent(self.W, event, ...) end
function Env:runTimers(seconds) wow.RunTimers(self.W, seconds) end
function Env:calls(name) return self.W.calls[name] or {} end
function Env:resetCalls() self.W.calls = {}; self.W.chat = {} end
function Env:chatText() return table.concat(self.W.chat, "\n") end

-- Runs "/ac <msg>" the way the chat box would. Core.lua runs commands in a
-- pcall and prints "error: ..." instead of raising, so those lines are moved
-- into W.errors, where noErrors(env) sees them.
function Env:slash(msg)
  local fn = self.G.SlashCmdList.AGENTCRAFT
  assert(fn, "SlashCmdList.AGENTCRAFT is not registered")
  local before = #self.W.chat
  fn(msg)
  for i = before + 1, #self.W.chat do
    local line = self.W.chat[i]
    if line:find("error:", 1, true) then self.W.errors[#self.W.errors + 1] = "/ac " .. tostring(msg) .. ": " .. line end
  end
end

-- Puts a library macro into /macro without going through the addon (as if
-- the owner installed it earlier). Does not record a CreateMacro call.
function Env:installMacro(name)
  for _, m in ipairs(self.ns.MacroLibrary.macros) do
    if m.name == name then
      local body = assert(self.ns.MacroLibrary.Resolve(m))
      self.W.macros[#self.W.macros + 1] = { name = name, icon = "INV_Misc_QuestionMark", body = body, perChar = m.perCharacter and true or false }
      return #self.W.macros
    end
  end
  error("no library macro named " .. name)
end

-- Gamepad storage slot for page (1-3) and a layout key like "RT A".
local BAR = { none = 0, LT = 1, RT = 2, ["LT+RT"] = 3 }
local BUTTON = { Left = 1, Up = 2, Right = 3, Down = 4, X = 5, Y = 6, B = 7, A = 8 }
function Env:padSlot(page, key)
  local layer, button = key:match("^(%S+) (%S+)$")
  return 180 + (page - 1) * 32 + BAR[layer] * 8 + BUTTON[button]
end

-- What a slot holds: "spell:Arcane Shot", "macro:Arcane", "item:6948", "flyout:253" or nil.
function Env:slotText(slot)
  local a = self.W.actions[slot]
  if not a then return nil end
  if a.type == "macro" then return "macro:" .. tostring(self.W.macros[a.id] and self.W.macros[a.id].name) end
  if a.type == "spell" then
    for _, s in ipairs(self.W.fixture.spells or {}) do if s.id == a.id then return "spell:" .. s.name end end
  end
  return a.type .. ":" .. tostring(a.id)
end

-- Globals the addon wrote (minus frames it named; auto stubs live outside G).
function Env:globalsWritten()
  local out = {}
  for k, v in pairs(self.G) do
    if k ~= "_G" and not (type(v) == "table" and rawget(v, "_world")) then
      out[#out + 1] = k
    end
  end
  table.sort(out)
  return out
end

function H.boot(opts)
  opts = opts or {}
  local fixture = LoadFixture(opts.fixture or "hunter")
  if opts.pet then fixture.pet = fixture.petData end
  local W = wow.NewWorld(fixture)
  local toc = wow.ReadToc(H.addonDir, H.addonName)
  local G = wow.NewEnv(W, toc)
  G.AgentcraftDB = opts.db
  G.AgentcraftCharDB = opts.charDB
  for k, v in pairs(opts.bindings or {}) do W.bindings[k] = v end
  W.secret = opts.secret and true or false
  if opts.setup then opts.setup(W) end

  local ns = wow.LoadAddon(W, G, toc)
  local env = setmetatable({ W = W, G = G, ns = ns, toc = toc }, Env)
  for _, name in ipairs(opts.macros or {}) do env:installMacro(name) end
  if opts.loaded then opts.loaded(env) end

  wow.FireEvent(W, "ADDON_LOADED", H.addonName)
  wow.FireEvent(W, "PLAYER_LOGIN")
  wow.FireEvent(W, "PLAYER_ENTERING_WORLD", true, false)
  wow.FireEvent(W, "SPELLS_CHANGED")
  wow.RunTimers(W, 15)

  H.worlds[#H.worlds + 1] = W
  return env
end

-- Every auto-stubbed API touched by any boot, during load or later in a
-- test: { [name] = total calls }. run.lua prints it at the end.
H.worlds = {}
function H.Unknown()
  local out = {}
  for _, W in ipairs(H.worlds) do
    for k, n in pairs(W.unknown) do out[k] = (out[k] or 0) + n end
  end
  return out
end
function H.collect() end  -- kept for old tests; H.Unknown() sees every boot

return H
