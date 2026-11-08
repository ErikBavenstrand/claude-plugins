-- TinkerKit core: module registry, saved settings, enable/disable, slash commands.
-- Works on retail and classic-era clients (only uses APIs common to all).
local ADDON, ns = ...
TinkerKit = ns -- global handle so macros or other addons can reach it
ns.modules, ns.order, ns.commands = {}, {}, {}

function ns.Print(...)
  print("|cff33ff99TinkerKit|r:", ...)
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
  description   one line shown in /tk modules
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

-- Register a slash subcommand: /tk <name> <args>
function ns.RegisterCommand(name, help, fn)
  ns.commands[name:lower()] = { help = help, fn = fn }
end

--[[ Register a page in the TinkerKit window (one entry in the sidebar).
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

-- Run fn and return everything it printed as one string (used by the
-- window to show output instead of spamming chat).
function ns.Capture(fn)
  local buf, orig = {}, print
  print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    table.insert(buf, table.concat(parts, " "))
  end
  local ok, err = pcall(fn)
  print = orig
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

local SetEnabled
function ns.SetModuleEnabled(mod, on) SetEnabled(mod, on) end

function SetEnabled(mod, on)
  ns.db.enabled[mod.name] = on
  mod.active = on
  for ev in pairs(mod.events or {}) do
    if on then frame:RegisterEvent(ev) end
  end
  if on and mod.OnEnable then mod:OnEnable() end
  if not on and mod.OnDisable then mod:OnDisable() end
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON or loaded then return end
    loaded = true
    TinkerKitDB = TinkerKitDB or {}
    TinkerKitCharDB = TinkerKitCharDB or {}
    ns.db, ns.charDB = TinkerKitDB, TinkerKitCharDB
    -- Counts loads. If it keeps resetting to 1, the client isn't reading
    -- SavedVariables back (a known WoW Forever beta bug).
    ns.db.loadCount = (ns.db.loadCount or 0) + 1
    ns.db.enabled = ns.db.enabled or {}
    ns.db.modules = ns.db.modules or {}
    ns.charDB.modules = ns.charDB.modules or {}
    for _, mod in ipairs(ns.order) do
      ns.db.modules[mod.name] = CopyDefaults(mod.defaults or {}, ns.db.modules[mod.name] or {})
      ns.charDB.modules[mod.name] = CopyDefaults(mod.charDefaults or {}, ns.charDB.modules[mod.name] or {})
      mod.db, mod.charDB = ns.db.modules[mod.name], ns.charDB.modules[mod.name]
      if IsEnabled(mod) then SetEnabled(mod, true) end
    end
    return
  end
  for _, mod in ipairs(ns.order) do
    local handler = mod.active and mod.events and mod.events[event]
    if handler then handler(mod, ...) end
  end
end)

-- Built-in commands
ns.RegisterCommand("modules", "list modules and whether they are on", function()
  for _, mod in ipairs(ns.order) do
    local state = mod.active and "|cff00ff00on|r" or "|cffff4444off|r"
    print(string.format("  %s [%s] %s", mod.name, state, mod.description or ""))
  end
end)

local function Toggle(arg, on)
  local mod = ns.modules[(arg or ""):lower()]
  if not mod then return ns.Print("no module named '" .. (arg or "") .. "'. Try /tk modules") end
  if mod.active == on then return ns.Print(mod.name .. " is already " .. (on and "on" or "off")) end
  SetEnabled(mod, on)
  ns.Print(mod.name .. (on and " enabled" or " disabled"))
end
ns.RegisterCommand("on", "enable a module: /tk on <module>", function(arg) Toggle(arg, true) end)
ns.RegisterCommand("off", "disable a module: /tk off <module>", function(arg) Toggle(arg, false) end)

SLASH_TINKERKIT1 = "/tk"
SLASH_TINKERKIT2 = "/tinkerkit"
SlashCmdList.TINKERKIT = function(msg)
  local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
  local entry = ns.commands[cmd:lower()]
  if entry then
    -- Catch errors so a bug in a module prints a message instead of
    -- leaving the chat box stuck.
    local ok, err = pcall(entry.fn, rest)
    if not ok then ns.Print("|cffff4444error:|r " .. tostring(err)) end
    return
  end
  if cmd == "" and ns.ToggleUI then return ns.ToggleUI() end
  ns.Print("commands (/tk alone opens the window):")
  local names = {}
  for name in pairs(ns.commands) do table.insert(names, name) end
  table.sort(names)
  for _, name in ipairs(names) do
    print("  /tk " .. name .. " - " .. ns.commands[name].help)
  end
end
