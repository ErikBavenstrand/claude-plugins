-- ActionBars: fills your action bars from a per-class profile.
--   /ac spells        show the plan for your class
--   /ac spells apply  place everything (saves current bar contents first)
--   /ac spells undo   put the bars back the way they were
--
-- Keyed bars (keys come from the Keybinds module):
--   slot:  1 2 3 4 5 6 7 8 9 10 11 12
--   key:   Q E R T F G C V 1 2  3  4
--   Bar 1 = key, Bar 2 = Shift+key, Bar 3 = Alt+key (utilities, all classes)
-- Click-only side bars, grouped automatically from your spellbook:
--   Right bar   = pet spells, then other class spells not on a keyed bar
--   Right bar 2 = tracking, then professions
-- Spells/items you don't have yet are skipped; apply again after training
-- or when you get new items.
local _, ns = ...
local M = ns.RegisterModule("ActionBars", {
  description = "fill action bars from a per-class profile",
})

-- First action slot of each keyed bar: bar 1 = 1-12,
-- bar 2 (bottom left) = 61-72, bar 3 (bottom right) = 49-60.
local BAR_OFFSET = { 0, 60, 48 }
local RIGHT_BAR, RIGHT_BAR_2 = 24, 36 -- slots 25-36 and 37-48

M.profiles = {
  -- Beast Mastery leveling, WoW Forever. Main source: Wowhead's Forever BM
  -- leveling guide (patch 1.60.1, updated 2026-11-04), single-target
  -- priority: Hunter's Mark > Serpent Sting > Summon Hawk > Arcane Shot
  -- (only every third rotation once Hawk is talented) > Aimed Shot.
  -- Extra buttons (Disengage, Intimidation, Bestial Wrath) come from the
  -- Icy Veins Forever guide. Reach: Q E R T easiest, then 1 2 3 4, then
  -- F G C V. Most-pressed spells go on the easiest keys.
  HUNTER = {
    -- Bar 1
    {
      "Serpent Sting",    -- Q   rotation 1 (after Mark)
      "Summon Hawk",      -- E   rotation 2, keep 2 hawks up
      "Arcane Shot",      -- R   rotation 3 (every third rotation with Hawk)
      "Aimed Shot",       -- T   rotation 4
      "Disengage",        -- F   drop threat / get out of melee
      "Intimidation",     -- G   pet stun + threat
      "Bestial Wrath",    -- C   cooldown for elites
      "Rapid Fire",       -- V   cooldown for elites
      "Hunter's Mark",    -- 1   opener, once per target
      "Multi-Shot",       -- 2   groups
      "Concussive Shot",  -- 3   slow / kite
      "Mend Pet",         -- 4
    },
    -- Bar 2 (Shift)
    {
      "Aspect of the Hawk",    -- Shift+Q
      "Aspect of the Cheetah", -- Shift+E
      "Wing Clip",             -- Shift+R
      "Feign Death",           -- Shift+T  escape
      "Raptor Strike",         -- Shift+F
      "Mongoose Bite",         -- Shift+G
      "War Stomp",             -- Shift+C  (Tauren racial; skipped on other races)
      "Volley",                -- Shift+V
      "Freezing Trap",         -- Shift+1
      "Frost Trap",            -- Shift+2
      "Immolation Trap",       -- Shift+3
      "Explosive Trap",        -- Shift+4
    },
    -- Bar 3 is the shared UTILITY bar below.
  },
}

-- Bar 3 (Alt) for every class: items, picked from your bags/trinkets.
-- Each entry is a list of item names, best first (the first one you carry
-- is used), or a special: food / drink (best you carry), trinket1/trinket2
-- (equipped on-use trinkets).
M.utility = {
  -- Alt+Q: bomb
  { "Thorium Grenade", "Dark Iron Bomb", "Hi-Explosive Bomb", "Iron Grenade",
    "Big Iron Bomb", "Big Bronze Bomb", "Small Bronze Bomb", "Large Copper Bomb",
    "Rough Copper Bomb" },
  -- Alt+E: healing potion
  { "Major Healing Potion", "Superior Healing Potion", "Greater Healing Potion",
    "Healing Potion", "Lesser Healing Potion", "Minor Healing Potion" },
  -- Alt+R: bandage
  { "Heavy Runecloth Bandage", "Runecloth Bandage", "Heavy Mageweave Bandage",
    "Mageweave Bandage", "Heavy Silk Bandage", "Silk Bandage", "Heavy Wool Bandage",
    "Wool Bandage", "Heavy Linen Bandage", "Linen Bandage" },
  -- Alt+T: mana potion
  { "Major Mana Potion", "Superior Mana Potion", "Greater Mana Potion",
    "Mana Potion", "Lesser Mana Potion", "Minor Mana Potion" },
  -- Alt+F: dynamite
  { "Dense Dynamite", "Solid Dynamite", "Heavy Dynamite", "Coarse Dynamite",
    "Rough Dynamite", "EZ-Thro Dynamite II", "EZ-Thro Dynamite" },
  -- Alt+G: engineering gadget
  { "Gnomish Net-o-Matic Projector", "Goblin Land Mine", "Explosive Sheep",
    "Masterwork Target Dummy", "Advanced Target Dummy", "Target Dummy",
    "Arcane Bomb", "Goblin Rocket Boots", "Gnomish Rocket Boots" },
  "trinket1",     -- Alt+C
  "trinket2",     -- Alt+V
  "food",         -- Alt+1
  "drink",        -- Alt+2
  { "Swiftness Potion", "Free Action Potion", "Living Action Potion",
    "Restorative Potion", "Elixir of Fortitude" }, -- Alt+3: utility potion
  { "Hearthstone" }, -- Alt+4
}

-- Groups for the click-only side bars.
local PET_SPELLS = {
  ["Call Pet"] = 1, ["Dismiss Pet"] = 2, ["Revive Pet"] = 3, ["Feed Pet"] = 4,
  ["Tame Beast"] = 5, ["Beast Training"] = 6, ["Beast Lore"] = 7,
  ["Eyes of the Beast"] = 8, ["Scare Beast"] = 9,
}
local PROFESSIONS = {
  "Alchemy", "Blacksmithing", "Enchanting", "Disenchant", "Engineering",
  "Leatherworking", "Tailoring", "Mining", "Smelting", "Herbalism", "Skinning",
  "Cooking", "Basic Campfire", "Fishing", "First Aid", "Pick Lock", "Survey",
}
local PROFESSION_RANK = {}
for i, name in ipairs(PROFESSIONS) do PROFESSION_RANK[name] = i end
local IGNORE = { ["Attack"] = true, ["Auto Attack"] = true }

local function IsPet(name) return PET_SPELLS[name] or name:find("^Summon ") end
local function IsTracking(name) return name:find("^Track ") or name:find("^Find ") or name:find("^Sense ") end
local function IsProfession(name) return PROFESSION_RANK[name] end

-- Map of known (castable) spell name -> spell ID. Later ranks come later in
-- the spellbook, so the highest rank wins.
local function KnownSpells()
  local map = {}
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
    local bank = Enum.SpellBookSpellBank.Player
    for tab = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local line = C_SpellBook.GetSpellBookSkillLineInfo(tab)
      for i = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
        local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
        if item and item.spellID and item.name and not item.isPassive then
          map[item.name] = item.spellID
        end
      end
    end
  else
    for tab = 1, GetNumSpellTabs() do
      local _, _, offset, num = GetSpellTabInfo(tab)
      for i = offset + 1, offset + num do
        local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
        local _, id = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
        local passive = IsPassiveSpell and IsPassiveSpell(i, BOOKTYPE_SPELL)
        if name and id and not passive then map[name] = id end
      end
    end
  end
  return map
end

-- Items ------------------------------------------------------------------

local GetItemInfoCompat = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local function ItemInfo(id)
  local name, _, _, _, minLevel = GetItemInfoCompat(id)
  -- GetItemInfo returns nothing for items not cached yet; the name lookup still works.
  if not name and C_Item and C_Item.GetItemNameByID then name = C_Item.GetItemNameByID(id) end
  return name, minLevel or 0
end

local function ItemSpell(id)
  if C_Item and C_Item.GetItemSpell then return C_Item.GetItemSpell(id) end
  return GetItemSpell(id)
end

-- Every distinct item in your bags: { [name] = id }, plus a list.
local function BagItems()
  local byName, list = {}, {}
  local numSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
  local itemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID
  for bag = 0, 4 do
    for slot = 1, numSlots(bag) or 0 do
      local id = itemID(bag, slot)
      if id then
        local name = ItemInfo(id)
        if name and not byName[name] then
          byName[name] = id
          table.insert(list, id)
        end
      end
    end
  end
  return byName, list
end

-- "Food", "Drink", "Both" or nil. The item's spell name says so on some
-- clients; WoW Forever doesn't report it, so fall back to the tooltip text.
local function ConsumableKind(id)
  local spell = ItemSpell(id)
  if spell == "Food" or spell == "Drink" then return spell end
  if spell == "Refreshment" then return "Both" end
  if C_TooltipInfo and C_TooltipInfo.GetItemByID then
    local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
    if ok and data and data.lines then
      for _, l in ipairs(data.lines) do
        local t = type(l.leftText) == "string" and l.leftText:lower() or ""
        if t:find("while eating and drinking") then return "Both" end
        if t:find("while eating") then return "Food" end
        if t:find("while drinking") then return "Drink" end
      end
    end
  end
end

-- Best food/drink you carry: highest required level you can use.
local function BestConsumable(list, kind)
  local best, bestLevel
  local level = UnitLevel("player")
  for _, id in ipairs(list) do
    local k = ConsumableKind(id)
    if k == kind or k == "Both" then
      local _, minLevel = ItemInfo(id)
      if minLevel <= level and (not bestLevel or minLevel > bestLevel) then
        best, bestLevel = id, minLevel
      end
    end
  end
  return best
end

local function ResolveUtility(entry, bags, list)
  if entry == "food" then return BestConsumable(list, "Food") end
  if entry == "drink" then return BestConsumable(list, "Drink") end
  if entry == "trinket1" or entry == "trinket2" then
    local id = GetInventoryItemID("player", entry == "trinket1" and 13 or 14)
    if id and ItemSpell(id) then return id end -- only on-use trinkets
    return nil
  end
  for _, name in ipairs(entry) do
    if bags[name] then return bags[name] end
  end
end

-- For other modules (Controller): item ID for a utility entry, or nil.
function M.ResolveUtilityItem(entry)
  local bags, list = BagItems()
  return ResolveUtility(entry, bags, list)
end

-- For other modules: name of the best "Food" or "Drink" in your bags, or nil.
function M.BestConsumableName(kind)
  local _, list = BagItems()
  local id = BestConsumable(list, kind)
  return id and ItemInfo(id) or nil
end

-- For other modules: known spell name -> highest-rank spell ID.
function M.KnownSpellIDs() return KnownSpells() end

local function UtilityLabel(entry)
  if type(entry) == "string" then return entry end
  return entry[#entry] .. " (or better)"
end

-- Placement ----------------------------------------------------------------

local function PickupSpellID(id)
  if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(id) else PickupSpell(id) end
end

local function PickupItemID(id)
  if C_Item and C_Item.PickupItem then C_Item.PickupItem(id) else PickupItem(id) end
end

local function ClearSlot(slot)
  if HasAction(slot) then PickupAction(slot); ClearCursor() end
end

local function PlaceSpell(slot, id) PickupSpellID(id); PlaceAction(slot); ClearCursor() end
local function PlaceItem(slot, id) PickupItemID(id); if GetCursorInfo() then PlaceAction(slot) end; ClearCursor() end

local function Profile()
  local _, class = UnitClass("player")
  return M.profiles[class], class
end

local function ManagedSlots()
  local slots = {}
  for bar = 1, 3 do
    for i = 1, 12 do table.insert(slots, BAR_OFFSET[bar] + i) end
  end
  for s = RIGHT_BAR + 1, RIGHT_BAR_2 + 12 do table.insert(slots, s) end
  return slots
end

-- Learned spells not on a keyed bar, split into the two side-bar lists.
local function SideBars(profile, known)
  local used = {}
  for bar = 1, 2 do
    for _, name in pairs(profile[bar] or {}) do used[name] = true end
  end
  local pet, other, tracking, prof = {}, {}, {}, {}
  for name in pairs(known) do
    if not used[name] and not IGNORE[name] then
      if IsPet(name) then table.insert(pet, name)
      elseif IsTracking(name) then table.insert(tracking, name)
      elseif IsProfession(name) then table.insert(prof, name)
      else table.insert(other, name) end
    end
  end
  table.sort(pet, function(a, b) return (PET_SPELLS[a] or 99) < (PET_SPELLS[b] or 99) or ((PET_SPELLS[a] or 99) == (PET_SPELLS[b] or 99) and a < b) end)
  table.sort(other)
  table.sort(tracking)
  table.sort(prof, function(a, b) return PROFESSION_RANK[a] < PROFESSION_RANK[b] end)
  local right, right2 = {}, {}
  for _, n in ipairs(pet) do table.insert(right, n) end
  for _, n in ipairs(other) do table.insert(right, n) end
  for _, n in ipairs(tracking) do table.insert(right2, n) end
  for _, n in ipairs(prof) do table.insert(right2, n) end
  -- Spill extras from one side bar into free room on the other.
  while #right > 12 and #right2 < 12 do table.insert(right2, table.remove(right)) end
  return right, right2
end

local function Apply()
  if InCombatLockdown() then return ns.Print("can't change bars in combat.") end
  local profile, class = Profile()
  if not profile then return ns.Print("no profile for " .. class .. " yet.") end
  local known = KnownSpells()
  local bags, bagList = BagItems()

  -- Back up every slot we touch, for undo.
  local backup = {}
  for _, slot in ipairs(ManagedSlots()) do
    local t, id = GetActionInfo(slot)
    if t then backup[slot] = { t, id } end
  end
  M.charDB.backup = backup

  ClearCursor()
  for _, slot in ipairs(ManagedSlots()) do ClearSlot(slot) end

  local missing = {}
  for bar = 1, 2 do
    for i = 1, 12 do
      local name = profile[bar] and profile[bar][i]
      if name then
        if known[name] then PlaceSpell(BAR_OFFSET[bar] + i, known[name])
        else table.insert(missing, name) end
      end
    end
  end

  local utility = profile[3] or M.utility
  for i = 1, 12 do
    local entry = utility[i]
    if entry then
      local id = ResolveUtility(entry, bags, bagList)
      if id then PlaceItem(BAR_OFFSET[3] + i, id) end
    end
  end

  local right, right2 = SideBars(profile, known)
  for i, name in ipairs(right) do
    if i <= 12 then PlaceSpell(RIGHT_BAR + i, known[name]) end
  end
  for i, name in ipairs(right2) do
    if i <= 12 then PlaceSpell(RIGHT_BAR_2 + i, known[name]) end
  end
  if #right > 12 or #right2 > 12 then ns.Print("side bars full; some spells stay in the spellbook.") end

  ns.Print("bars set for " .. class .. ". /ac spells undo to go back.")
  if #missing > 0 then ns.Print("not learned yet (left empty): " .. table.concat(missing, ", ")) end
end

local function Undo()
  if InCombatLockdown() then return ns.Print("can't change bars in combat.") end
  local backup = M.charDB.backup
  if not backup then return ns.Print("nothing to undo.") end
  ClearCursor()
  for _, slot in ipairs(ManagedSlots()) do
    ClearSlot(slot)
    local saved = backup[slot]
    if saved then
      local t, id = saved[1], saved[2]
      if t == "spell" then PickupSpellID(id)
      elseif t == "item" then PickupItemID(id)
      elseif t == "macro" then PickupMacro(id)
      end
      if GetCursorInfo() then PlaceAction(slot) end
      ClearCursor()
    end
  end
  M.charDB.backup = nil
  ns.Print("bars restored.")
end

local KEY_LABELS = { "Q", "E", "R", "T", "F", "G", "C", "V", "1", "2", "3", "4" }

local function Show()
  local profile, class = Profile()
  if not profile then return ns.Print("no profile for " .. class .. " yet.") end
  local known = KnownSpells()
  local bags, bagList = BagItems()
  for bar = 1, 2 do
    print("|cffffd100Bar " .. bar .. (bar == 2 and " (Shift)" or "") .. "|r")
    for i = 1, 12 do
      local name = profile[bar] and profile[bar][i]
      if name then
        local mark = known[name] and "" or " |cff888888(not learned)|r"
        print("  " .. (bar == 2 and "Shift+" or "") .. KEY_LABELS[i] .. " -> " .. name .. mark)
      end
    end
  end
  print("|cffffd100Bar 3 (Alt, utilities)|r")
  local utility = profile[3] or M.utility
  for i = 1, 12 do
    local entry = utility[i]
    if entry then
      local id = ResolveUtility(entry, bags, bagList)
      local what = id and (ItemInfo(id)) or ("|cff888888" .. UtilityLabel(entry) .. " (none in bags)|r")
      print("  Alt+" .. KEY_LABELS[i] .. " -> " .. what)
    end
  end
  local right, right2 = SideBars(profile, known)
  print("|cffffd100Right bar (click: pet, other)|r  " .. table.concat(right, ", "))
  print("|cffffd100Right bar 2 (click: tracking, professions)|r  " .. table.concat(right2, ", "))
end

-- Plan for the window: what each managed slot will hold after Apply.
-- Entry states: same (already there), new (placed on apply), missing (spell
-- not learned / item not in bags), clear (removed on apply), empty.
local ROWS = {
  { label = "Bar 1",   command = "ACTIONBUTTON",          first = BAR_OFFSET[1] },
  { label = "Shift",   command = "MULTIACTIONBAR1BUTTON", first = BAR_OFFSET[2] },
  { label = "Alt",     command = "MULTIACTIONBAR2BUTTON", first = BAR_OFFSET[3] },
  { label = "Right",   command = "MULTIACTIONBAR3BUTTON", first = RIGHT_BAR },
  { label = "Right 2", command = "MULTIACTIONBAR4BUTTON", first = RIGHT_BAR_2 },
}

function M.Plan()
  local profile, class = Profile()
  if not profile then return nil, class end
  local known = KnownSpells()
  local bags, bagList = BagItems()
  local right, right2 = SideBars(profile, known)
  local utility = profile[3] or M.utility
  local plan = { changes = 0, spellsMissing = 0, itemsMissing = 0 }
  for r, row in ipairs(ROWS) do
    local entries = {}
    for i = 1, 12 do
      local e = { slot = row.first + i }
      if r <= 2 then
        local name = profile[r] and profile[r][i]
        if name then e.kind, e.id, e.name = "spell", known[name], name end
      elseif r == 3 then
        local entry = utility[i]
        if entry then
          local id = ResolveUtility(entry, bags, bagList)
          e.kind, e.id, e.name = "item", id, id and ItemInfo(id) or UtilityLabel(entry)
        end
      else
        local name = (r == 4 and right or right2)[i]
        if name then e.kind, e.id, e.name = "spell", known[name], name end
      end
      local cur, curID = GetActionInfo(e.slot)
      if not e.kind then e.state = cur and "clear" or "empty"
      elseif not e.id then e.state = "missing"
      elseif cur == e.kind and curID == e.id then e.state = "same"
      else e.state = "new" end
      if e.state == "new" or e.state == "clear" then plan.changes = plan.changes + 1 end
      if e.state == "missing" then
        if e.kind == "spell" then plan.spellsMissing = plan.spellsMissing + 1
        else plan.itemsMissing = plan.itemsMissing + 1 end
      end
      entries[i] = e
    end
    plan[r] = entries
  end
  return plan, class
end

-- Window page ----------------------------------------------------------------

local UI = ns.UI
local SLOT, STEP, LABEL_W = 34, 38, 62

-- Extra gap after every 4 slots, matching the key groups Q E R T | F G C V | 1 2 3 4.
local function SlotX(i) return LABEL_W + (i - 1) * STEP + math.floor((i - 1) / 4) * 10 end

local function FillSlot(s, e, command)
  s:SetKey(UI.KeyText(GetBindingKey(command)))
  s:SetMark(nil)
  if e.state == "empty" then
    s:SetIcon(nil); s:SetTip(nil)
  elseif e.state == "clear" then
    s:SetIcon(GetActionTexture(e.slot), true)
    s:SetMark(UI.ORANGE)
    s:SetTip({ action = e.slot, text = "Removed on apply.", color = UI.ORANGE })
  elseif e.state == "missing" then
    s:SetIcon((e.kind == "spell" and UI.SpellIcon(e.name)) or UI.QUESTION, true)
    s:SetMark(UI.RED)
    s:SetTip({ title = e.name, color = UI.RED,
      text = e.kind == "spell" and "Not learned yet. Placed here once you train it and apply again."
        or "None in your bags. Placed here once you carry one and apply again." })
  else
    local spell = e.kind == "spell" and e.id or nil
    local item = e.kind == "item" and e.id or nil
    s:SetIcon(spell and UI.SpellIcon(spell) or UI.ItemIcon(item))
    if e.state == "new" then s:SetMark(UI.GREEN) end
    s:SetTip({ spellID = spell, itemID = item, text = e.state == "new" and "Placed here on apply." or nil })
  end
end

ns.RegisterPage({
  id = "bars",
  title = "Action bars",
  icon = "Interface\\Icons\\Ability_Marksmanship",
  order = 10,

  Build = function(page, f)
    page.grid = CreateFrame("Frame", nil, f)
    page.grid:SetAllPoints()
    local g = page.grid
    local width = SlotX(12) + SLOT
    page.slots = {}
    local y = 0
    local groups = {
      { title = "Keyed bars", rows = { 1, 2, 3 } },
      { title = "Click-only bars  |cff999999pet, other spells, tracking, professions|r", rows = { 4, 5 } },
    }
    for _, group in ipairs(groups) do
      UI.Header(g, group.title, 0, y, width)
      y = y - 24
      for _, r in ipairs(group.rows) do
        local label = UI.Text(g, ROWS[r].label, "GameFontNormalSmall")
        label:SetPoint("LEFT", g, "TOPLEFT", 0, y - SLOT / 2)
        page.slots[r] = {}
        for i = 1, 12 do
          local s = UI.Slot(g, SLOT)
          s:SetPoint("TOPLEFT", SlotX(i), y)
          page.slots[r][i] = s
        end
        y = y - (SLOT + 8)
      end
      y = y - 14
    end

    local legend = {
      { UI.GREEN, "Placed on apply" },
      { UI.RED, "Not learned / not in bags" },
      { UI.ORANGE, "Removed on apply" },
    }
    local x = 0
    for _, l in ipairs(legend) do
      local sw = UI.Swatch(g, l[1], l[2])
      sw:SetPoint("TOPLEFT", x, y - 4)
      x = x + 30 + sw.label:GetStringWidth() + 12
    end
    local hint = UI.Text(g, "Hover a slot for its tooltip. Bar 1 and Shift come from your class profile; "
      .. "Alt picks the best item you carry.", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 0, y - 24)
    hint:SetWidth(width)
    hint:SetJustifyH("LEFT")

    page.empty = UI.Text(f, "", "GameFontHighlight")
    page.empty:SetPoint("CENTER")
  end,

  Refresh = function(page)
    local plan, class = M.Plan()
    page.plan = plan
    page.grid:SetShown(plan ~= nil)
    page.empty:SetShown(plan == nil)
    if not plan then
      page.empty:SetText("No bar profile for " .. (class or "?") .. " yet.")
      return
    end
    for r, row in ipairs(ROWS) do
      for i = 1, 12 do FillSlot(page.slots[r][i], plan[r][i], row.command .. i) end
    end
  end,

  Status = function(page)
    local p = page.plan
    if not p then return "" end
    local parts = {}
    if p.changes > 0 then
      parts[#parts + 1] = "|cff4cff4c" .. p.changes .. " slots change on apply|r"
    else
      parts[#parts + 1] = "|cff4cff4cBars match the plan|r"
    end
    if p.spellsMissing > 0 then parts[#parts + 1] = "|cffff5a4a" .. p.spellsMissing .. " not learned|r" end
    if p.itemsMissing > 0 then parts[#parts + 1] = "|cffaaaaaa" .. p.itemsMissing .. " not in bags|r" end
    return table.concat(parts, "  ·  ")
  end,

  actions = {
    { label = "Undo", fn = Undo, tooltip = "Put the bars back the way they were before the last apply." },
    { label = "Apply", fn = Apply, tooltip = "Fill all bars as shown. Your current bars are saved for undo." },
  },
})

ns.RegisterCommand("spells", "fill bars: /ac spells [apply|undo]", function(arg)
  arg = (arg or ""):lower()
  if arg == "apply" then Apply()
  elseif arg == "undo" then Undo()
  else Show() end
end)
