-- Keybinds: applies one shared key layout to the action bars and pet bar.
--   /ac keys        show the layout
--   /ac keys apply  apply it (the first apply saves your original binds)
--   /ac keys undo   restore the binds from before the first apply
local _, ns = ...
local M = ns.RegisterModule("Keybinds", {
  description = "shared key layout for action bars and the pet bar",
})

-- Same keys on bars 1-3; Shift picks bar 2, Alt picks bar 3 (utilities).
-- Slots: Q E R T | F G | C V | 1 2 3 4  (keyboard rows, number row last)
local KEYS = { "Q", "E", "R", "T", "F", "G", "C", "V", "1", "2", "3", "4" }

-- keys = nil means the bar is managed but left unbound (old binds cleared).
local BARS = {
  { label = "Bar 1",           prefix = "",       command = "ACTIONBUTTON",          keys = KEYS },
  { label = "Bar 2",           prefix = "SHIFT-", command = "MULTIACTIONBAR1BUTTON", keys = KEYS },
  { label = "Bar 3 (utilities)", prefix = "ALT-", command = "MULTIACTIONBAR2BUTTON", keys = KEYS },
}

-- Pet bar slots (Classic): 1 Attack, 2 Follow, 3 Stay, 4-7 abilities,
-- 8 Aggressive, 9 Defensive, 10 Passive.
-- Commands live on the mouse; the 4 abilities on Z/X (+Shift), the free
-- bottom-row keys next to the pinky.
local PET = {
  [1] = "BUTTON5",        -- Attack
  [2] = "BUTTON4",        -- Follow
  [3] = "SHIFT-BUTTON4",  -- Stay
  [4] = "Z",              -- ability 1
  [5] = "X",              -- ability 2
  [6] = "SHIFT-Z",        -- ability 3
  [7] = "SHIFT-X",        -- ability 4
  [8] = "SHIFT-BUTTON3",  -- Aggressive (Shift + wheel click)
  [9] = "BUTTON3",        -- Defensive (wheel click)
  [10] = "SHIFT-BUTTON5", -- Passive
}
local PET_SLOTS = 10

local function Layout()
  local list = {}
  for _, bar in ipairs(BARS) do
    for i = 1, 12 do
      local key = bar.keys and bar.keys[i]
      table.insert(list, { key = key and (bar.prefix .. key), command = bar.command .. i, label = bar.label })
    end
  end
  for i = 1, PET_SLOTS do
    table.insert(list, { key = PET[i], command = "BONUSACTIONBUTTON" .. i, label = "Pet bar" })
  end
  return list
end

-- Where the backup lives: per character when this character uses
-- character-specific binds, otherwise account-wide like the binds.
local function Store()
  local set = GetCurrentBindingSet and GetCurrentBindingSet()
  if set == (_G.CHARACTER_BINDINGS or 2) then return M.charDB end
  return M.db
end

local function Apply()
  if InCombatLockdown() then return ns.Print("can't change keybinds in combat.") end
  local layout = Layout()

  -- Keep the very first backup, so undo always returns to your original binds.
  local store = Store()
  if not store.backup then
    local backup = { commands = {}, keys = {} }
    for _, b in ipairs(layout) do
      backup.commands[b.command] = { GetBindingKey(b.command) }
      if b.key then backup.keys[b.key] = GetBindingAction(b.key) end
    end
    store.backup = backup
  end

  -- Clear every key on the managed commands so nothing is left double-bound.
  for _, b in ipairs(layout) do
    for _, key in ipairs({ GetBindingKey(b.command) }) do SetBinding(key) end
  end
  for _, b in ipairs(layout) do
    if b.key then SetBinding(b.key, b.command) end
  end

  SaveBindings(GetCurrentBindingSet())
  ns.Print("keybinds applied. /ac keys undo to go back to your original binds.")
end

local function Undo()
  if InCombatLockdown() then return ns.Print("can't change keybinds in combat.") end
  local store = Store()
  local backup = store.backup
  if not backup then return ns.Print("nothing to undo.") end
  for _, b in ipairs(Layout()) do
    for _, key in ipairs({ GetBindingKey(b.command) }) do SetBinding(key) end
  end
  for key, action in pairs(backup.keys) do
    if action and action ~= "" then SetBinding(key, action) end
  end
  for command, keys in pairs(backup.commands) do
    for _, key in ipairs(keys) do SetBinding(key, command) end
  end
  SaveBindings(GetCurrentBindingSet())
  store.backup = nil
  ns.Print("original keybinds restored.")
end

local function Show()
  local last
  for _, b in ipairs(Layout()) do
    if b.key then
      if b.label ~= last then print("|cffffd100" .. b.label .. "|r"); last = b.label end
      print("  " .. b.key .. " -> " .. b.command)
    end
  end
end

-- Number of layout keys that aren't bound the way the layout says.
local function Diff()
  local wrong = 0
  for _, b in ipairs(Layout()) do
    if b.key and GetBindingAction(b.key) ~= b.command then wrong = wrong + 1 end
  end
  return wrong
end

-- Window page ----------------------------------------------------------------

local UI = ns.UI
local KEY, KSTEP = 42, 47
-- Keyboard rows with their real stagger (in key widths).
local KEYBOARD = {
  { x = 0,    keys = { "1", "2", "3", "4", "5" } },
  { x = 0.5,  keys = { "Q", "W", "E", "R", "T" } },
  { x = 0.75, keys = { "A", "S", "D", "F", "G" } },
  { x = 1.25, keys = { "Z", "X", "C", "V" } },
}
local MODS = { { "", "" }, { "SHIFT-", "Shift+" }, { "ALT-", "Alt+" } }
local MOUSE = { { "BUTTON5", "Mouse 5" }, { "BUTTON4", "Mouse 4" }, { "BUTTON3", "Wheel" } }
local MOUSE_X = 318

local function Short(name)
  return ((name or ""):match("^(%S+)") or ""):sub(1, 6)
end

-- Icon + name pair: a small slot with text to its right.
local function Entry(parent, size, nameWidth)
  local s = UI.Slot(parent, size)
  s.name = UI.Text(parent, "", "GameFontHighlightSmall")
  s.name:SetPoint("LEFT", s, "RIGHT", 6, 0)
  s.name:SetWidth(nameWidth)
  s.name:SetJustifyH("LEFT")
  s.name:SetWordWrap(false)
  return s
end

local function FillEntry(s, key)
  local d = UI.DescribeCommand(GetBindingAction(key))
  s:SetIcon(d and d.icon)
  s:SetTip(d and d.tip)
  s.name:SetText(d and d.name or "|cff666666Unbound|r")
  s:SetEdge(d and (d.kind == "bar" and UI.GOLD or d.kind == "pet" and UI.BLUE) or nil)
end

local function ShowKey(page, key)
  page.detailTitle:SetText("Key " .. key)
  for m, mod in ipairs(MODS) do
    local e = page.detail[m]
    e.mod:SetText(mod[2] .. key)
    FillEntry(e, mod[1] .. key)
  end
  page.shown = key
end

ns.RegisterPage({
  id = "keys",
  title = "Keybinds",
  icon = "Interface\\Icons\\INV_Misc_Key_03",
  order = 20,

  Build = function(page, f)
    -- Keyboard
    UI.Header(f, "Keyboard  |cff999999hover a key|r", 0, 0, 290)
    page.keys = {}
    for r, row in ipairs(KEYBOARD) do
      for i, key in ipairs(row.keys) do
        local s = UI.Slot(f, KEY)
        s:SetPoint("TOPLEFT", (row.x + i - 1) * KSTEP, -24 - (r - 1) * KSTEP)
        s.key:ClearAllPoints()
        s.key:SetPoint("TOPLEFT", 4, -4)
        s.key:SetFontObject("NumberFontNormal")
        s:HookScript("OnEnter", function() ShowKey(page, key) end)
        page.keys[key] = s
      end
    end

    -- Detail for the hovered key: plain / Shift / Alt.
    local y = -24 - #KEYBOARD * KSTEP - 10
    page.detailTitle = UI.Header(f, "", 0, y, 290)
    page.detail = {}
    for m = 1, #MODS do
      local e = Entry(f, 30, 190)
      e:SetPoint("TOPLEFT", 64, y - 22 - (m - 1) * 36)
      e.mod = UI.Text(f, "", "GameFontNormalSmall")
      e.mod:SetPoint("RIGHT", e, "LEFT", -8, 0)
      page.detail[m] = e
    end

    -- Mouse buttons (pet commands).
    UI.Header(f, "Mouse  |cff999999pet commands|r", MOUSE_X, 0, 286)
    UI.Text(f, "Plain", "GameFontDisableSmall"):SetPoint("TOPLEFT", MOUSE_X + 62, -24)
    UI.Text(f, "Shift", "GameFontDisableSmall"):SetPoint("TOPLEFT", MOUSE_X + 174, -24)
    page.mouse = {}
    for i, m in ipairs(MOUSE) do
      local yy = -40 - (i - 1) * 40
      UI.Text(f, m[2], "GameFontNormalSmall"):SetPoint("TOPLEFT", MOUSE_X, yy - 10)
      local plain = Entry(f, 30, 72)
      plain:SetPoint("TOPLEFT", MOUSE_X + 62, yy)
      local shift = Entry(f, 30, 72)
      shift:SetPoint("TOPLEFT", MOUSE_X + 174, yy)
      page.mouse[i] = { plain, shift, key = m[1] }
    end

    -- Legend.
    local ly = -40 - #MOUSE * 40 - 10
    local s1 = UI.Swatch(f, UI.GOLD, "Action bar")
    s1:SetPoint("TOPLEFT", MOUSE_X, ly)
    local s2 = UI.Swatch(f, UI.BLUE, "Pet bar")
    s2:SetPoint("TOPLEFT", MOUSE_X + 100, ly)
    local note = UI.Text(f, "Same 12 keys on every bar: plain = bar 1, Shift = bar 2, Alt = bar 3 "
      .. "(utilities). Pet abilities sit on Z and X. Works the same for every class.", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", MOUSE_X, ly - 20)
    note:SetWidth(280)
    note:SetJustifyH("LEFT")
  end,

  Refresh = function(page)
    for key, s in pairs(page.keys) do
      local d = UI.DescribeCommand(GetBindingAction(key))
      s:SetKey(key)
      s:SetIcon(d and d.icon)
      s:SetTip(d and d.tip)
      s.center:SetText(d and not d.icon and Short(d.name) or "")
      local bar, pet
      for _, mod in ipairs(MODS) do
        local c = UI.DescribeCommand(GetBindingAction(mod[1] .. key))
        if c and c.kind == "bar" then bar = true elseif c and c.kind == "pet" then pet = true end
      end
      s:SetEdge(bar and UI.GOLD or pet and UI.BLUE or nil)
    end
    for _, row in ipairs(page.mouse) do
      FillEntry(row[1], row.key)
      FillEntry(row[2], "SHIFT-" .. row.key)
    end
    ShowKey(page, page.shown or "Q")
  end,

  Status = function()
    local n = Diff()
    if n == 0 then return "|cff4cff4cLayout applied|r" end
    return "|cffffd100" .. n .. " keys differ from the layout|r"
  end,

  actions = {
    { label = "Undo", fn = Undo, tooltip = "Restore the binds you had before Agentcraft." },
    { label = "Apply", fn = Apply, tooltip = "Bind bars 1-3 and the pet bar. Your first original binds are saved." },
  },
})

ns.RegisterCommand("keys", "keybind layout: /ac keys [apply|undo]", function(arg)
  arg = (arg or ""):lower()
  if arg == "apply" then Apply()
  elseif arg == "undo" then Undo()
  else Show() end
end)
