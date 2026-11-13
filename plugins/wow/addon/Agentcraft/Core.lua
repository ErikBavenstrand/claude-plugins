-- Agentcraft core: module registry, saved settings, enable/disable, slash commands.
-- Works on retail and classic-era clients (only uses APIs common to all).
local ADDON, ns = ...
Agentcraft = ns -- global handle so macros or other addons can reach it
ns.modules, ns.order, ns.commands = {}, {}, {}

-- Output goes to the active ns.Capture buffer when there is one, else to
-- chat. Never reassign the global print: writing a global taints it.
function ns.Out(...)
  local buf = ns._capture
  if not buf then return print(...) end
  local parts = {}
  for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
  table.insert(buf, table.concat(parts, " "))
end

function ns.Print(...)
  ns.Out("|cff33ff99Agentcraft|r:", ...)
end

-- Error handler for xpcall: report through the game's handler (BugSack and
-- the error popup see it) and hand the message back.
local function ReportError(err)
  local handler = geterrorhandler and geterrorhandler()
  if handler then pcall(handler, err) end
  return err
end

local function CopyDefaults(src, dst)
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = type(dst[k]) == "table" and dst[k] or {}
      CopyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

--[[ Register a module. Fields on mod (all optional):
  description   one line shown in /ac modules
  enabled       default on/off (true if omitted)
  defaults      table of default account-wide settings  -> self.db
  charDefaults  table of default per-character settings -> self.charDB
  events        { EVENT_NAME = function(self, ...) end }
  OnEnable(self), OnDisable(self)
]]
function ns.RegisterModule(name, mod)
  mod.name = name
  if mod.enabled == nil then mod.enabled = true end
  ns.modules[name:lower()] = mod
  table.insert(ns.order, mod)
  return mod
end

-- Register a slash subcommand: /ac <name> <args>
function ns.RegisterCommand(name, help, fn)
  ns.commands[name:lower()] = { help = help, fn = fn }
end

--[[ Register a page in the Agentcraft window (one entry in the sidebar).
  id        unique string
  title     sidebar and header text
  icon      texture path or file ID for the sidebar icon
  order     sort position (lower = higher up; Settings uses 1000)
  Build(page, frame)   called once, the first time the page is opened.
                       Use the widgets in ns.UI (UI\Widgets.lua).
  Refresh(page)        called on open, after footer actions, and when bars,
                       binds, bags or spells change while the window is open
  Status(page)         optional; returns the one-line summary in the header
  actions = { { label = "Apply", fn = function() end, tooltip = "..." }, ... }
                       footer buttons, the last one sits rightmost
]]
ns.pages = {}
function ns.RegisterPage(page)
  table.insert(ns.pages, page)
  return page
end

-- Small extra buttons shown under "Tools" on the Settings page.
ns.actions = {}
function ns.RegisterAction(section, label, fn, tooltip)
  table.insert(ns.actions, { section = section, label = label, fn = fn, tooltip = tooltip })
end

-- Run fn, keep what it printed in the log (Settings > Log), return the text.
ns.log = {}
function ns.Run(fn)
  local out = ns.Capture(fn)
  if out ~= "" then
    table.insert(ns.log, "|cff888888" .. date("%H:%M:%S") .. "|r  " .. out)
    while #ns.log > 100 do table.remove(ns.log, 1) end
  end
  return out
end

-- Run fn and return everything it printed through ns.Print / ns.Out as one
-- string (used by the window to show output instead of spamming chat).
function ns.Capture(fn)
  local buf, outer = {}, ns._capture
  ns._capture = buf
  local ok, err = pcall(fn)
  ns._capture = outer
  if not ok then table.insert(buf, "|cffff4444error:|r " .. tostring(err)) end
  return table.concat(buf, "\n")
end

local frame = CreateFrame("Frame")
local loaded = false

local function IsEnabled(mod)
  local state = ns.db.enabled[mod.name]
  if state == nil then return mod.enabled end
  return state
end

-- Turn a module on or off for this session without saving the choice.
-- OnEnable/OnDisable errors are reported, and a module whose OnEnable fails
-- stays off. Returns true when the module ended up in the asked state.
local function Activate(mod, on)
  if not on then
    mod.active = false
    if mod.OnDisable then xpcall(mod.OnDisable, ReportError, mod) end
    return true
  end
  for ev in pairs(mod.events or {}) do
    -- pcall: an event that doesn't exist on this game version would error.
    pcall(frame.RegisterEvent, frame, ev)
  end
  if mod.OnEnable and not xpcall(mod.OnEnable, ReportError, mod) then
    mod.active = false
    ns.Print("|cffff4444" .. mod.name .. " failed to start|r (see the Lua error).")
    return false
  end
  mod.active = true
  return true
end

-- The user's choice: save it, then apply it. Only explicit choices are saved,
-- so a module's shipped default can still change later.
local function SetEnabled(mod, on)
  ns.db.enabled[mod.name] = on
  return Activate(mod, on)
end
function ns.SetModuleEnabled(mod, on) return SetEnabled(mod, on) end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON or loaded then return end
    loaded = true
    AgentcraftDB = AgentcraftDB or {}
    AgentcraftCharDB = AgentcraftCharDB or {}
    ns.db, ns.charDB = AgentcraftDB, AgentcraftCharDB
    -- Counts loads. If it keeps resetting to 1, the client isn't reading
    -- SavedVariables back (a known WoW Forever beta bug).
    ns.db.loadCount = (ns.db.loadCount or 0) + 1
    ns.db.enabled = ns.db.enabled or {}
    ns.db.modules = ns.db.modules or {}
    ns.charDB.modules = ns.charDB.modules or {}
    -- Every module gets its settings first, so one module failing to start
    -- can't leave the ones after it without a db.
    for _, mod in ipairs(ns.order) do
      ns.db.modules[mod.name] = CopyDefaults(mod.defaults or {}, ns.db.modules[mod.name] or {})
      ns.charDB.modules[mod.name] = CopyDefaults(mod.charDefaults or {}, ns.charDB.modules[mod.name] or {})
      mod.db, mod.charDB = ns.db.modules[mod.name], ns.charDB.modules[mod.name]
    end
    for _, mod in ipairs(ns.order) do
      if IsEnabled(mod) then Activate(mod, true) end
    end
    return
  end
  for _, mod in ipairs(ns.order) do
    local handler = mod.active and mod.events and mod.events[event]
    -- xpcall: one module's error is reported but the rest still get the event.
    if handler then xpcall(handler, ReportError, mod, ...) end
  end
end)

-- Built-in commands
ns.RegisterCommand("modules", "list modules and whether they are on", function()
  for _, mod in ipairs(ns.order) do
    local state = mod.active and "|cff00ff00on|r" or "|cffff4444off|r"
    ns.Out(string.format("  %s [%s] %s", mod.name, state, mod.description or ""))
  end
end)

local function Toggle(arg, on)
  local mod = ns.modules[(arg or ""):lower()]
  if not mod then return ns.Print("no module named '" .. (arg or "") .. "'. Try /ac modules") end
  if mod.active == on then return ns.Print(mod.name .. " is already " .. (on and "on" or "off")) end
  if SetEnabled(mod, on) then ns.Print(mod.name .. (on and " enabled" or " disabled")) end
end
ns.RegisterCommand("on", "enable a module: /ac on <module>", function(arg) Toggle(arg, true) end)
ns.RegisterCommand("off", "disable a module: /ac off <module>", function(arg) Toggle(arg, false) end)

SLASH_AGENTCRAFT1 = "/ac"
SLASH_AGENTCRAFT2 = "/agentcraft"
SlashCmdList.AGENTCRAFT = function(msg)
  local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
  local entry = ns.commands[cmd:lower()]
  if entry then
    -- Catch errors so a bug in a module prints a message instead of
    -- leaving the chat box stuck.
    local ok, err = pcall(entry.fn, rest)
    if not ok then ns.Print("|cffff4444error:|r " .. tostring(err)) end
    return
  end
  if cmd == "" and ns.ToggleUI then
    local ok, err = pcall(ns.ToggleUI)
    if not ok then ns.Print("|cffff4444error:|r " .. tostring(err)) end
    return
  end
  ns.Print("commands (/ac alone opens the window):")
  local names = {}
  for name in pairs(ns.commands) do table.insert(names, name) end
  table.sort(names)
  for _, name in ipairs(names) do
    ns.Out("  /ac " .. name .. " - " .. ns.commands[name].help)
  end
end
