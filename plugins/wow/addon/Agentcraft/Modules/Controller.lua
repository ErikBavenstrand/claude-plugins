-- Controller: fills WoW Forever's native Gamepad UI action bars and binds the
-- Steam Deck back buttons, from a per-class layout that leaves room to grow.
--
-- How the Gamepad UI works (Blizzard_GamepadActionBars, forever branch):
--   * 3 pages (LB+RB with D-pad left/right). Each page has 4 bars:
--       Top = nothing held, Left = LT held, Right = RT held, Bottom = LT+RT.
--   * Each bar is a D-pad diamond plus a face-button diamond (8 buttons).
--     The Top bar's face buttons are fixed (interact, inspect, back, jump).
--   * Actions live in action slots from C_GamepadUI.GetFirstGamepadActionStorageSlotIndex()
--     (181 on the live client); GamepadActionBarBindingUtil maps page + button to a slot.
--   * Only spell flyouts (like Aspects) open a radial: 8 entries, picked with the right stick.
--   * Pet commands (LB+LT) and pet abilities (RB+RT) are radials Blizzard fills itself.
--   * Newly learned spells are dropped into empty slots (RT+face first). Planned
--     slots for spells you haven't learned stay empty; Apply again after
--     training to move new spells to their planned button.
-- Back buttons: Steam Input maps L4, L5, R4, R5 to F13-F16; this module binds
-- those keys (and LT+key, since LT emulates Shift) to spells and macros.
local _, ns = ...
local UI = ns.UI
local M = ns.RegisterModule("Controller", {
  description = "fill the controller action bars and back buttons",
})

local BAR = { none = 0, LT = 1, RT = 2, ["LT+RT"] = 3 }
local BAR_TITLE = { [0] = "Top  (nothing held)", "Left  (hold LT)", "Right  (hold RT)", "Bottom  (hold LT+RT)" }
local BUTTON = { Left = 1, Up = 2, Right = 3, Down = 4, X = 5, Y = 6, B = 7, A = 8 }
local BUTTON_NAME = { "D-pad left", "D-pad up", "D-pad right", "D-pad down",
  "X / Square", "Y / Triangle", "B / Circle", "A / Cross" }

-- "RT A" -> page-unit slot ID (1-32).
local function SlotID(key)
  local layer, button = key:match("^(%S+) (%S+)$")
  return BAR[layer] * 8 + BUTTON[button]
end

-- Entry forms:
--   { "Feign Death", "Disengage" }   first spell you know
--   { flyout = 253 }                 spellbook flyout (a radial), by flyout ID or name
--   { macro = "Eat" }                macro from the Agentcraft library (installed if needed)
--   { utility = <ActionBars.utility entry> }  best matching item in your bags
--   { racial = true }                your race's active racial
local RACIALS = { "War Stomp", "Berserking", "Blood Fury", "Will of the Forsaken", "Stoneform",
  "Shadowmeld", "Escape Artist", "Perception" }

M.layouts = {
  HUNTER = {
    pages = {
      -- Page 1: combat, for any build (Beast Mastery, Marksmanship, Survival).
      --   RT    = ranged rotation (most pressed; face buttons keep the left thumb on the stick)
      --   LT    = melee, defensive and build cooldowns
      --   Top   = D-pad things used standing still: aspects radial, freezing trap, racial, eat
      --   LT+RT = crowd control and situational shots
      -- Each button lists spells best-first. Buttons are filled in PRIORITY order
      -- and a spell already on the page is skipped, so one layout adapts to the
      -- build: e.g. BM before Summon Hawk gets Aimed Shot on RT B and Multi-Shot on RT Y.
      [1] = {
        title = "Combat",
        ["RT A"] = { "Arcane Shot" },
        ["RT X"] = { "Serpent Sting" },
        ["RT B"] = { "Summon Hawk", "Sniper Shot", "Aimed Shot" },   -- build signature shot
        ["RT Y"] = { "Aimed Shot", "Multi-Shot" },
        ["RT Up"] = { "Hunter's Mark" },                             -- once per target, before moving
        ["RT Down"] = { "Explosive Trap", "Immolation Trap" },       -- damage trap (usable in combat in Forever)
        ["RT Left"] = { "Concussive Shot" },
        ["RT Right"] = { "Rapid Fire", "Multi-Shot", "Volley" },
        ["LT A"] = { "Raptor Strike" },
        ["LT X"] = { "Mongoose Bite" },
        ["LT B"] = { "Disengage" },
        ["LT Y"] = { "Wing Clip" },
        ["LT Up"] = { "Mend Pet" },
        ["LT Down"] = { "Feign Death" },
        ["LT Left"] = { "Intimidation", "Counterattack", "Scatter Shot" },  -- build control button
        ["LT Right"] = { "Bestial Wrath", "Deterrence", "Trueshot Aura" },  -- build cooldown
        ["none Up"] = { flyout = 253, "Aspect of the Hawk" },        -- aspects radial
        ["none Left"] = { "Freezing Trap" },
        ["none Right"] = { racial = true },
        ["none Down"] = { macro = "Eat" },
        ["LT+RT A"] = { "Frost Trap" },
        ["LT+RT X"] = { "Wyvern Sting", "Scatter Shot" },
        ["LT+RT B"] = { "Tranquilizing Shot" },
        ["LT+RT Y"] = { "Flare" },
        ["LT+RT Up"] = { "Scare Beast" },
        ["LT+RT Down"] = { "Immolation Trap", "Volley" },
        ["LT+RT Left"] = { "Distracting Shot" },
        ["LT+RT Right"] = { "Viper Sting", "Scorpid Sting" },
      },
      -- Page 2: pet care, consumables, travel and professions.
      [2] = {
        title = "Utility",
        ["RT A"] = { "Revive Pet" },
        ["RT X"] = { "Call Pet" },
        ["RT Y"] = { "Dismiss Pet" },
        ["RT B"] = { macro = "Feed" },
        ["RT Up"] = { "Beast Lore" },
        ["RT Left"] = { "Eyes of the Beast" },
        ["RT Right"] = { "Tame Beast" },
        ["RT Down"] = { "Beast Training" },
        ["LT A"] = { utility = 2 },
        ["LT X"] = { utility = 3 },
        ["LT Y"] = { utility = 4 },
        ["LT B"] = { utility = 11 },
        ["LT Up"] = { utility = 1 },
        ["LT Left"] = { utility = 5 },
        ["LT Right"] = { utility = 6 },
        ["LT Down"] = { utility = 7 },
        ["none Up"] = { macro = "Hearth" },
        ["none Left"] = { macro = "Fish" },
        ["none Right"] = { macro = "Track" },
        ["none Down"] = { macro = "Campfire" },
        ["LT+RT A"] = { "Smelting" },
        ["LT+RT X"] = { "Cooking" },
        ["LT+RT Y"] = { "Engineering" },
        ["LT+RT B"] = { "First Aid" },
        ["LT+RT Up"] = { "Alchemy", "Blacksmithing", "Leatherworking", "Tailoring", "Enchanting" },
        ["LT+RT Left"] = { "Disenchant", "Skinning" },
        ["LT+RT Right"] = { macro = "Lure" },
        ["LT+RT Down"] = { macro = "SellGrays" },
      },
    },
    -- Back buttons: plain press and with LT held (LT emulates Shift).
    paddles = {
      ["L4"] = { macro = "PetAttack" },
      ["L5"] = { macro = "Recall" },
      ["R4"] = { "Feign Death", "Disengage" },
      ["R5"] = { "Concussive Shot" },
      ["LT+L4"] = { "Intimidation", "Counterattack", "Scatter Shot" },
      ["LT+L5"] = { "Bestial Wrath", "Deterrence", "Rapid Fire" },
      ["LT+R4"] = { "Freezing Trap" },
      ["LT+R5"] = { racial = true },
    },
  },
}

local PADDLE_KEY = { L4 = "F13", L5 = "F14", R4 = "F15", R5 = "F16" }
local PADDLE_ORDER = { "L4", "L5", "R4", "R5", "LT+L4", "LT+L5", "LT+R4", "LT+R5" }
local function PaddleBinding(p)
  local lt, base = p:match("^(LT%+)(.+)$")
  return (lt and "SHIFT-" or "") .. PADDLE_KEY[base or p]
end

-- Resolving entries -------------------------------------------------------------

local function Util() return GamepadActionBarBindingUtil end
local KnownID -- defined below

local function Layout()
  local _, class = UnitClass("player")
  return M.layouts[class], class
end

local function Known()
  local AB = ns.modules.actionbars
  return AB and AB.KnownSpellIDs and AB.KnownSpellIDs() or {}
end

-- Spellbook index of a flyout, by flyout ID or name.
local function FindFlyout(want)
  if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return end
  local bank = Enum.SpellBookSpellBank.Player
  for tab = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local line = C_SpellBook.GetSpellBookSkillLineInfo(tab)
    if line then
      for i = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
        local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
        if item and item.itemType == Enum.SpellBookItemType.Flyout
          and (item.actionID == want or item.name == want) then
          return i, item.actionID, item.name, item.iconID
        end
      end
    end
  end
end

local function MacroIndex(name)
  local i = GetMacroIndexByName(name)
  if i and i > 0 then return i end
  local L = ns.MacroLibrary
  if L then
    for _, m in ipairs(L.macros) do
      if m.name == name then
        L.Install({ m })
        i = GetMacroIndexByName(name)
        return i and i > 0 and i or nil
      end
    end
  end
end

-- Spell ID for a name you know. The class spellbook map misses profession
-- spells (Smelting, Cooking) and renamed ones ("Call Pet" shows as
-- "Call <pet name>"), so fall back to the game's own lookup.
function KnownID(name, known)
  if known[name] then return known[name] end
  local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
  local id = info and info.spellID
  if id and ((IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id))) then return id end
end

-- Returns a plan item: { kind, id, name, icon } or { missing = "label" }.
function M.Resolve(entry, known, used)
  if entry.flyout then
    local index, id, name, icon = FindFlyout(entry.flyout)
    if index then return { kind = "flyout", index = index, id = id, name = name .. " (radial)", icon = icon } end
  end
  if entry.racial then
    for _, n in ipairs(RACIALS) do
      local id = KnownID(n, known)
      if id then return { kind = "spell", id = id, name = n } end
    end
    return { missing = "racial" }
  end
  if entry.macro then
    local exists = GetMacroIndexByName(entry.macro)
    return { kind = "macro", name = entry.macro, installed = exists and exists > 0 }
  end
  if entry.utility then
    local AB = ns.modules.actionbars
    local spec = AB and AB.utility and AB.utility[entry.utility]
    local id = spec and AB.ResolveUtilityItem(spec)
    if id then return { kind = "item", id = id, name = C_Item.GetItemNameByID(id) or ("item " .. id) } end
    return { missing = type(spec) == "table" and (spec[#spec] .. " (or better)") or tostring(spec) }
  end
  for _, n in ipairs(entry) do
    local id = KnownID(n, known)
    if id and not (used and used[id]) then return { kind = "spell", id = id, name = n } end
  end
  return { missing = entry[#entry] or "?" }
end

-- Fill order: rotation layer first, most comfortable buttons first.
local LAYER_RANK = { RT = 1, LT = 2, none = 3, ["LT+RT"] = 4 }
local BUTTON_RANK = { A = 1, X = 2, B = 3, Y = 4, Up = 5, Down = 6, Left = 7, Right = 8 }
local function PriorityKeys(def)
  local keys = {}
  for key in pairs(def) do if key ~= "title" then keys[#keys + 1] = key end end
  table.sort(keys, function(a, b)
    local la, ba = a:match("^(%S+) (%S+)$")
    local lb, bb = b:match("^(%S+) (%S+)$")
    if LAYER_RANK[la] ~= LAYER_RANK[lb] then return LAYER_RANK[la] < LAYER_RANK[lb] end
    return BUTTON_RANK[ba] < BUTTON_RANK[bb]
  end)
  return keys
end

local function Icon(p)
  if not p or p.missing then return nil end
  if p.icon then return p.icon end
  if p.kind == "spell" then return UI.SpellIcon(p.id) end
  if p.kind == "item" then return UI.ItemIcon(p.id) end
  if p.kind == "macro" then
    local i = GetMacroIndexByName(p.name)
    if i and i > 0 then return select(2, GetMacroInfo(i)) end
    return "Interface\\Icons\\INV_Misc_Note_01"
  end
end

-- Storage slot for a page and page-unit slot ID, or nil.
local function Storage(page, slotID)
  local U = Util()
  if not U then return end
  local ok, index = pcall(U.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID, page, slotID)
  return ok and index or nil
end

-- Full plan: plan[page][slotID] = { key, entry, item, slot, state }.
function M.Plan()
  local layout, class = Layout()
  if not layout then return nil, class end
  local known = Known()
  local plan = { changes = 0, missing = 0 }
  for page, def in ipairs(layout.pages) do
    plan[page] = { title = def.title }
    local used = {}
    for _, key in ipairs(PriorityKeys(def)) do
      local entry = def[key]
      do
        local slotID = SlotID(key)
        local item = M.Resolve(entry, known, used)
        if item.kind == "spell" then used[item.id] = true end
        local slot = Storage(page, slotID)
        local state = "missing"
        if not item.missing and slot then
          local t, id = GetActionInfo(slot)
          local same = (item.kind == "spell" and t == "spell" and id == item.id)
            or (item.kind == "item" and t == "item" and id == item.id)
            or (item.kind == "flyout" and t == "flyout" and id == item.id)
            or (item.kind == "macro" and t == "macro" and GetActionText(slot) == item.name)
          state = same and "same" or "new"
          if state == "new" then plan.changes = plan.changes + 1 end
        else
          plan.missing = plan.missing + 1
        end
        plan[page][slotID] = { key = key, entry = entry, item = item, slot = slot, state = state }
      end
    end
  end
  plan.paddles = {}
  local paddleUsed = {}
  for _, p in ipairs(PADDLE_ORDER) do
    local entry = layout.paddles and layout.paddles[p]
    if entry then
      local item = M.Resolve(entry, known, paddleUsed)
      if item.kind == "spell" then paddleUsed[item.id] = true end
      local binding = PaddleBinding(p)
      local current = GetBindingAction(binding)
      local want = item.missing and "" or (item.kind == "macro" and ("MACRO " .. item.name) or ("SPELL " .. item.name))
      plan.paddles[p] = { item = item, binding = binding, state = item.missing and "missing" or (current == want and "same" or "new") }
      if plan.paddles[p].state == "new" then plan.changes = plan.changes + 1 end
    end
  end
  return plan, class
end

-- Placement ------------------------------------------------------------------------

local function Pickup(item)
  ClearCursor()
  if item.kind == "spell" then
    if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(item.id) else PickupSpell(item.id) end
  elseif item.kind == "item" then
    if C_Item and C_Item.PickupItem then C_Item.PickupItem(item.id) else PickupItem(item.id) end
  elseif item.kind == "flyout" then
    C_SpellBook.PickupSpellBookItem(item.index, Enum.SpellBookSpellBank.Player)
  elseif item.kind == "macro" then
    local i = MacroIndex(item.name)
    if i then PickupMacro(i) end
  end
end

local function Place(slot, item)
  Pickup(item)
  if GetCursorInfo() then PlaceAction(slot) end
  ClearCursor()
end

local function ManagedSlots(plan)
  local slots = {}
  for page = 1, #plan do
    for slotID = 1, 32 do
      local s = Storage(page, slotID)
      if s then slots[#slots + 1] = s end
    end
  end
  return slots
end

function M.Apply()
  if InCombatLockdown() then return ns.Print("can't change controller bars in combat.") end
  if not Util() then return ns.Print("turn on the Gamepad UI first (Options > Gameplay > Gamepad).") end
  local plan, class = M.Plan()
  if not plan then return ns.Print("no controller layout for " .. tostring(class) .. " yet.") end

  -- Save the current layout once per apply, for undo.
  local backup = { slots = {}, binds = {} }
  for _, slot in ipairs(ManagedSlots(plan)) do
    local t, id = GetActionInfo(slot)
    if t then backup.slots[slot] = { t, id, t == "macro" and GetActionText(slot) or nil } end
  end
  for _, p in pairs(plan.paddles) do backup.binds[p.binding] = GetBindingAction(p.binding) end
  M.charDB.backup = backup

  ClearCursor()
  local placed = 0
  for page = 1, #plan do
    for slotID = 1, 32 do
      local s = Storage(page, slotID)
      local want = plan[page][slotID]
      if s then
        if want and not want.item.missing then
          if want.state ~= "same" then Place(s, want.item); placed = placed + 1 end
        elseif HasAction(s) then
          -- Planned for a spell you don't have yet, or not in the layout:
          -- clear it so the layout stays predictable.
          PickupAction(s); ClearCursor()
        end
      end
    end
  end

  for _, p in pairs(plan.paddles) do
    SetBinding(p.binding)
    if not p.item.missing then
      if p.item.kind == "macro" then MacroIndex(p.item.name); SetBindingMacro(p.binding, p.item.name)
      else SetBindingSpell(p.binding, p.item.name) end
    end
  end
  SaveBindings(GetCurrentBindingSet())
  ns.Print(string.format("controller layout applied (%d changes). /ac controller undo to go back.", placed))
  if plan.missing > 0 then ns.Print(plan.missing .. " planned buttons wait for spells or items you don't have yet.") end
end

function M.Undo()
  if InCombatLockdown() then return ns.Print("can't change controller bars in combat.") end
  local backup = M.charDB.backup
  if not backup then return ns.Print("nothing to undo.") end
  ClearCursor()
  local plan = M.Plan() or { 1, 2 }
  for _, slot in ipairs(ManagedSlots(plan)) do
    if HasAction(slot) then PickupAction(slot); ClearCursor() end
    local saved = backup.slots[slot]
    if saved then
      local t, id, text = saved[1], saved[2], saved[3]
      if t == "spell" then Pickup({ kind = "spell", id = id })
      elseif t == "item" then Pickup({ kind = "item", id = id })
      elseif t == "macro" then local i = GetMacroIndexByName(text or "") if i and i > 0 then PickupMacro(i) end
      elseif t == "flyout" then local index = FindFlyout(id) if index then Pickup({ kind = "flyout", index = index }) end
      end
      if GetCursorInfo() then PlaceAction(slot) end
      ClearCursor()
    end
  end
  for key, action in pairs(backup.binds) do
    SetBinding(key)
    if action and action ~= "" then SetBinding(key, action) end
  end
  SaveBindings(GetCurrentBindingSet())
  M.charDB.backup = nil
  ns.Print("controller layout restored.")
end

-- Window page ----------------------------------------------------------------------
-- Four bar panels drawn like the controller: a D-pad diamond and a face diamond.

local SLOT, GAP = 30, 2
local DIAMOND = { { -1, 0 }, { 0, 1 }, { 1, 0 }, { 0, -1 } } -- left, up, right, down
local PANEL_W, PANEL_H = 296, 112
local PANEL_POS = { [0] = { 0, -1 }, { 0, 0 }, { 1, 0 }, { 1, -1 } } -- Top bottom-left, Left top-left, Right top-right, Bottom bottom-right

local function FillSlot(s, p)
  s:SetMark(nil)
  s:SetEdge(nil)
  if not p then s:SetIcon(nil); s:SetTip({ title = "Free" , text = "Not in the layout. Blizzard may drop new spells here." , color = { 0.7, 0.7, 0.7 } }); return end
  if p.item.missing then
    s:SetIcon(UI.SpellIcon(p.item.missing) or UI.QUESTION, true)
    s:SetMark(UI.RED)
    s:SetTip({ title = p.item.missing, text = "Reserved for when you learn or carry it. Apply again then.", color = UI.RED })
    return
  end
  s:SetIcon(Icon(p.item))
  if p.state == "new" then s:SetMark(UI.GREEN) end
  if p.item.kind == "flyout" then s:SetEdge(UI.GOLD) end
  local tip = { title = p.item.name, text = p.state == "new" and "Placed here on apply." or nil }
  if p.item.kind == "spell" then tip.spellID = p.item.id elseif p.item.kind == "item" then tip.itemID = p.item.id end
  s:SetTip(tip)
end

local page = ns.RegisterPage({
  id = "controller",
  title = "Controller",
  icon = "Interface\\Icons\\INV_Gizmo_02",
  order = 25,

  Build = function(page, f)
    page.current = 1
    page.tabs = {}
    for i = 1, 3 do
      local b = UI.Button(f, "Page " .. i, 80, function() page.current = i; ns.UI.Refresh() end)
      b:SetPoint("TOPLEFT", (i - 1) * 84, 0)
      page.tabs[i] = b
    end
    page.pageTitle = UI.Text(f, "", "GameFontNormalLarge")
    page.pageTitle:SetPoint("LEFT", page.tabs[3], "RIGHT", 14, 0)

    page.slots = {}
    for bar = 0, 3 do
      local pos = PANEL_POS[bar]
      local panel = CreateFrame("Frame", nil, f)
      panel:SetSize(PANEL_W, PANEL_H)
      panel:SetPoint("TOPLEFT", pos[1] * (PANEL_W + 12), -32 + pos[2] * (PANEL_H + 8))
      UI.Fill(panel, 0, 0, 0, 0.3)
      UI.Border(panel, 1, 0.82, 0, 0.18)
      local t = UI.Text(panel, BAR_TITLE[bar], "GameFontNormalSmall")
      t:SetPoint("TOPLEFT", 6, -4)
      for b = 1, 8 do
        local d = DIAMOND[((b - 1) % 4) + 1]
        local cx = (b <= 4) and 70 or 220
        local s = UI.Slot(panel, SLOT)
        s:SetPoint("CENTER", panel, "TOPLEFT", cx + d[1] * (SLOT + GAP), -62 - d[2] * (SLOT + GAP))
        s.key:SetText(b <= 4 and "" or ({ "X", "Y", "B", "A" })[b - 4])
        page.slots[bar * 8 + b] = s
      end
    end

    local py = -32 - 2 * (PANEL_H + 8) - 6
    UI.Header(f, "Back buttons  |cff999999Steam Input: L4=F13, L5=F14, R4=F15, R5=F16|r", 0, py, 604)
    page.paddles = {}
    for i, p in ipairs(PADDLE_ORDER) do
      local s = UI.Slot(f, 30)
      s:SetPoint("TOPLEFT", (i - 1) * 74, py - 22)
      s.key:SetText(p)
      s.key:ClearAllPoints()
      s.key:SetPoint("TOP", s, "BOTTOM", 0, -2)
      s.key:SetFontObject("GameFontHighlightSmall")
      page.paddles[p] = s
    end
    page.empty = UI.Text(f, "", "GameFontHighlight")
    page.empty:SetPoint("CENTER")
  end,

  Refresh = function(page)
    local plan, class = M.Plan()
    page.plan = plan
    if not plan then
      page.empty:SetText("No controller layout for " .. tostring(class) .. " yet.")
      return
    end
    page.empty:SetText("")
    local cur = plan[page.current] or {}
    page.pageTitle:SetText(cur.title or "Free page")
    for i, b in ipairs(page.tabs) do b:SetEnabled(i ~= page.current) end
    for id = 1, 32 do
      local s = page.slots[id]
      if id >= 5 and id <= 8 then
        s:SetIcon(nil); s:SetMark(nil); s:SetEdge(nil)
        s.center:SetText("fixed")
        s:SetTip({ title = BUTTON_NAME[id], text = "Fixed by the Gamepad UI: interact, inspect, back, jump.", color = { 0.7, 0.7, 0.7 } })
      else
        s.center:SetText("")
        FillSlot(s, cur[id])
      end
    end
    for p, s in pairs(page.paddles) do
      local pp = plan.paddles[p]
      if pp then
        if pp.item.missing then
          s:SetIcon(UI.SpellIcon(pp.item.missing) or UI.QUESTION, true); s:SetMark(UI.RED)
          s:SetTip({ title = pp.item.missing, text = "Bound once you learn it.", color = UI.RED })
        else
          s:SetIcon(Icon(pp.item)); s:SetMark(pp.state == "new" and UI.GREEN or nil)
          s:SetTip({ title = p .. ": " .. pp.item.name, text = "Key " .. pp.binding, color = { 0.8, 0.8, 0.8 } })
        end
      end
    end
  end,

  Status = function(page)
    local p = page.plan
    if not p then return "" end
    local enabled = C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()
    return string.format("%s%d to change|r  ·  |cffff5a4a%d waiting for spells|r%s",
      p.changes > 0 and "|cff4cff4c" or "|cffaaaaaa", p.changes, p.missing,
      enabled and "" or "  ·  |cffffd100Gamepad UI is off|r")
  end,

  actions = {
    { label = "Undo", fn = M.Undo, tooltip = "Put back the controller bars and back-button keys from before the last apply." },
    { label = "Apply", fn = M.Apply, tooltip = "Fill controller pages 1-2 and bind the back-button keys. Your current layout is saved for undo." },
  },
})

ns.RegisterCommand("controller", "controller layout: /ac controller [apply|undo]", function(arg)
  arg = (arg or ""):lower()
  if arg == "apply" then M.Apply() elseif arg == "undo" then M.Undo() else ns.OpenPage("controller") end
end)
