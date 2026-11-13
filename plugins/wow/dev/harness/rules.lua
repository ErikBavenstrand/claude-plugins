-- The owner's macro and layout rules, in Lua, for tests that run against the
-- loaded addon tables (ns.MacroLibrary, ns.Layout). dev.ps1 "rules" holds the
-- same rules for PowerShell; keep the two in step.
local R = {}

local MENU = { ["/camp"] = true, ["/logout"] = true, ["/quit"] = true, ["/exit"] = true, ["/readycheck"] = true,
  ["/screenshot"] = true, ["/map"] = true, ["/repair"] = true }
local MENU_RUN = { "ToggleWorldMap", "RepairAllItems", "Screenshot%s*%(", "Logout%s*%(", "Quit%s*%(", "DoReadyCheck",
  "UseContainerItem", "SellAllJunk", "ChatFrame_OpenChat", "cameraDistanceMax" }
local ITEM_COMMANDS = { ["/use"] = true, ["/equip"] = true, ["/equipslot"] = true, ["/userandom"] = true }

local function Trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- "[cond] a; [cond] b" -> { "a", "b" }
local function Targets(args)
  local out = {}
  for part in (args .. ";"):gmatch("([^;]*);") do
    local t = Trim(part:gsub("%b[]", ""))
    t = Trim(t:gsub("^!", ""))
    if t ~= "" then out[#out + 1] = t end
  end
  return out
end
R.Targets = Targets

-- Returns { { severity = "error"|"warn"|"info", rule = "...", msg = "..." }, ... }
function R.CheckMacro(m, body)
  body = body or m.body
  local out = {}
  local function Add(sev, rule, msg) out[#out + 1] = { severity = sev, rule = rule, msg = m.name .. ": " .. msg } end
  if #m.name > 16 then Add("error", "macro-name", "name longer than 16 characters") end
  if #body > 255 then Add("error", "macro-length", #body .. " characters; the limit is 255") end
  local fishItems = {}
  for line in (body .. "\n"):gmatch("(.-)\n") do
    local t = Trim(line)
    local cmd, rest = t:match("^(/%S+)%s*(.*)$")
    if cmd then
      cmd = cmd:lower()
      for cond in rest:gmatch("%[([^%]]*)%]") do
        for c in (cond .. ","):gmatch("([^,]*),") do
          c = Trim(c):lower()
          if c:match("^no?mod") or c:match("^mod") then
            if c:find("alt") and not (c:find("shift") or c:find("ctrl")) then Add("warn", "macro-modifier", "[" .. c .. "] (Alt)")
            else Add("error", "macro-modifier", "[" .. c .. "]: no Shift/Ctrl modifier variants") end
          elseif c:match("^@mouseover") or c:match("^@cursor") or c:match("^target%s*=%s*mouseover") or c:match("^target%s*=%s*cursor") then
            Add("error", "macro-mouse", "[" .. c .. "]: no @mouseover/@cursor")
          elseif c:match("^n?o?btn") or c:match("^n?o?button") then
            Add("warn", "macro-mouse", "[" .. c .. "]: mouse buttons don't exist on a controller")
          end
        end
      end
      if cmd == "/petpassive" then Add("error", "macro-petpassive", "/petpassive")
      elseif cmd == "/petattack" then Add("error", "macro-petattack", "/petattack (the owner wants none)")
      elseif ITEM_COMMANDS[cmd] then
        for _, target in ipairs(Targets(rest)) do
          local tg = cmd == "/equipslot" and target:gsub("^%d+%s*", "") or target
          -- A bare number ("13") or "bag slot" ("0 1") is a slot, not an item name.
          local isSlot = tg:match("^%d+$") or tg:match("^%d+%s+%d+$")
          if not isSlot then
            if m.name == "Fish" and cmd == "/equip" then fishItems[#fishItems + 1] = tg
            else Add("error", "macro-item", cmd .. " " .. tg .. " names an item") end
          end
        end
      elseif cmd == "/equipset" then Add("warn", "macro-equipset", "/equipset")
      elseif MENU[cmd] then Add("error", "macro-menu", cmd .. " is covered by a game menu")
      elseif cmd == "/run" or cmd == "/script" or cmd == "/dump" or cmd == "/console" then
        for _, p in ipairs(MENU_RUN) do
          if rest:find(p) then Add("error", "macro-menu", "/run " .. p .. " is covered by a game menu") end
        end
      end
    end
  end
  if #fishItems > 0 then Add("info", "macro-item", "/equip names " .. #fishItems .. " items (Fish exception approved by the owner)") end
  return out
end

-- Spell homes per device. Returns a list of problems:
--   { severity, rule, msg }
-- Back buttons that repeat a page home are "info" (mirrors, allowed), anything else "error".
function R.CheckLayout(Layout, class)
  local out = {}
  local function Add(sev, rule, msg) out[#out + 1] = { severity = sev, rule = rule, msg = msg } end
  local function Spells(entry)
    local list = {}
    for _, v in ipairs(entry) do if type(v) == "string" then list[#list + 1] = v end end
    -- Non-spell homes count too: your racial or one item placed twice.
    if entry.racial then list[#list + 1] = "<racial>" end
    if entry.item then list[#list + 1] = "<item " .. tostring(entry.item) .. ">" end
    if entry.utility then list[#list + 1] = "<utility " .. tostring(entry.utility) .. ">" end
    return list
  end
  local KEYS = { "Q", "E", "R", "T", "F", "G", "C", "V", "1", "2", "3", "4" }

  local kb = Layout.keyboard and Layout.keyboard[class]
  if kb then
    local homes = {}
    for bar = 1, 2 do
      for i, entry in pairs(kb[bar] or {}) do
        local key = (bar == 2 and "Shift+" or "") .. (KEYS[i] or ("#" .. i))
        if entry.flyout or entry.petauto or entry.overflow then Add("error", "layout-keyboard", class .. " keyboard " .. key .. " uses a controller-only entry") end
        for _, s in ipairs(Spells(entry)) do
          if homes[s] then Add("error", "layout-two-homes", class .. " keyboard: " .. s .. " at " .. homes[s] .. " and " .. key)
          else homes[s] = key end
        end
      end
    end
  end

  local ct = Layout.controller and Layout.controller[class]
  if ct then
    local homes = {}
    for p, page in ipairs(ct.pages or {}) do
      for key, entry in pairs(page) do
        if key ~= "title" then
          for _, s in ipairs(Spells(entry)) do
            local here = "page " .. p .. " " .. key
            if homes[s] then Add("error", "layout-two-homes", class .. " controller: " .. s .. " at " .. homes[s] .. " and " .. here)
            else homes[s] = here end
          end
        end
      end
    end
    local pads = {}
    for key, entry in pairs(ct.paddles or {}) do
      for _, s in ipairs(Spells(entry)) do
        if pads[s] then Add("error", "layout-two-homes", class .. " back buttons: " .. s .. " on " .. pads[s] .. " and " .. key) end
        pads[s] = key
        if homes[s] then Add("info", "layout-paddle-mirror", class .. " controller: " .. s .. " on back button " .. key .. " and " .. homes[s]) end
      end
    end
  end
  return out
end

return R
