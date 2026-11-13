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

-- Per-class keyboard layouts for classes without a role layout in Layout.lua:
--   M.profiles.<CLASS> = { { 12 spell names for bar 1 }, { 12 for bar 2 }, [3] = utility override }
-- Classes with a role layout (Layout.lua) use it instead, shared with the controller.
M.profiles = {}

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
local IGNORE = { ["Attack"] = true, ["Auto Attack"] = true, ["Auto Shot"] = true, ["Shoot"] = true, ["Throw"] = true, ["Cultivation"] = true }
-- "Call Pet" shows in the spellbook as "Call <pet name>", so match it by ID.
local CALL_PET_ID = 883

local function PetRank(name, id) return PET_SPELLS[name] or (id == CALL_PET_ID and PET_SPELLS["Call Pet"]) or nil end
local function IsPet(name, id) return PetRank(name, id) or name:find("^Summon ") end
local function IsTracking(name) return name:find("^Track ") or name:find("^Find ") or name:find("^Sense ") end

-- Map of known (castable) spell name -> spell ID. Later ranks come later in
-- the spellbook, so the highest rank wins.
local function KnownSpells()
  local map = {}
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
    local bank = Enum.SpellBookSpellBank.Player
    local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    for tab = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local line = C_SpellBook.GetSpellBookSkillLineInfo(tab)
      if line then
        for i = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
          local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
          -- Spells only: no future (unlearned) spells, flyouts or pet actions.
          if item and item.spellID and item.name and not item.isPassive
            and (not spellType or item.itemType == nil or item.itemType == spellType) then
            map[item.name] = item.spellID
          end
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

-- Spell ID for a spell you know by name, from the game's own lookup.
local function LookupKnown(name)
  local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(name)
  local id = info and info.spellID
  if id and ((IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id))) then return id end
end

-- Names the class skill lines miss: profession spells and the pet spells.
local SIDE_EXTRAS = { "Find Minerals", "Find Herbs" }
for _, name in ipairs(PROFESSIONS) do table.insert(SIDE_EXTRAS, name) end
for name in pairs(PET_SPELLS) do table.insert(SIDE_EXTRAS, name) end

-- The known map plus profession spells, which live outside the class skill
-- lines. Returns name -> ID and the set of names from your professions.
local function SideKnown(known)
  local ids, have, prof = {}, {}, {}
  for name, id in pairs(known) do ids[name] = id; have[id] = true end
  local function Add(name, id, fromProfession)
    if name and id and not ids[name] and not have[id] then
      ids[name], have[id] = id, true
      if fromProfession then prof[name] = true end
    end
  end
  if GetProfessions and GetProfessionInfo and C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
    local bank = Enum.SpellBookSpellBank.Player
    local list = { GetProfessions() }
    for p = 1, select("#", GetProfessions()) do
      if list[p] then
        local _, _, _, _, numSpells, offset = GetProfessionInfo(list[p])
        for i = (offset or 0) + 1, (offset or 0) + (numSpells or 0) do
          local ok, item = pcall(C_SpellBook.GetSpellBookItemInfo, i, bank)
          if ok and item and item.spellID and item.name and not item.isPassive then Add(item.name, item.spellID, true) end
        end
      end
    end
  end
  for _, name in ipairs(SIDE_EXTRAS) do
    if not ids[name] then Add(name, LookupKnown(name)) end
  end
  return ids, prof
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

-- For other modules: "Food", "Drink", "Both" or nil for an item ID.
M.ConsumableKind = ConsumableKind

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

-- Bars 1-2 come from the shared role layout (Layout.lua) when the class has
-- one, so keyboard and controller agree; otherwise from M.profiles.
-- Returns { [1] = entries, [2] = entries, [3] = utility override }.
local function Profile()
  local _, class = UnitClass("player")
  local bars = ns.Layout and ns.Layout.KeyboardBars(class)
  local legacy = M.profiles[class]
  if bars then
    bars[3] = legacy and legacy[3]
    return bars, class
  end
  if not legacy then return nil, class end
  local out = { {}, {}, legacy[3] }
  for bar = 1, 2 do
    for i, name in pairs(legacy[bar] or {}) do out[bar][i] = { name } end
  end
  return out, class
end

-- Resolve a layout entry (spell names, flyout, macro, racial) with the
-- controller module's resolver, which knows every entry form.
local function ResolveEntry(entry, known)
  local C = ns.modules.controller
  if C and C.Resolve then return C.Resolve(entry, known) end
  for _, n in ipairs(entry) do
    if known[n] then return { kind = "spell", id = known[n], name = n } end
  end
  return { missing = entry[#entry] or "?" }
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
-- Also returns the name -> spell ID map the lists draw from.
local function SideBars(profile, known)
  local used = {}
  for bar = 1, 2 do
    for _, entry in pairs(profile[bar] or {}) do
      -- Only the spell a home picked is placed; the alternatives it skipped
      -- still need a home. A macro home places its spell and covers = { ... }.
      local item = ResolveEntry(entry, known)
      if item.kind == "spell" and item.name then used[item.name] = true end
      if item.kind == "macro" then
        if entry[1] then used[entry[1]] = true end
        for _, n in ipairs(entry.covers or {}) do used[n] = true end
      end
      -- { "Better", "Lower rank", upgrade = true }: the lower one needs no home.
      if entry.upgrade then
        for _, n in ipairs(entry) do used[n] = true end
      end
    end
  end
  local ids, fromProfession = SideKnown(known)
  local function Rank(name) return PetRank(name, ids[name]) or 99 end
  local function ProfRank(name) return PROFESSION_RANK[name] or 99 end
  local pet, other, tracking, prof = {}, {}, {}, {}
  for name in pairs(ids) do
    if not used[name] and not IGNORE[name] then
      if IsPet(name, ids[name]) then table.insert(pet, name)
      elseif IsTracking(name) then table.insert(tracking, name)
      elseif PROFESSION_RANK[name] or fromProfession[name] then table.insert(prof, name)
      else table.insert(other, name) end
    end
  end
  table.sort(pet, function(a, b) return Rank(a) < Rank(b) or (Rank(a) == Rank(b) and a < b) end)
  table.sort(other)
  table.sort(tracking)
  table.sort(prof, function(a, b) return ProfRank(a) < ProfRank(b) or (ProfRank(a) == ProfRank(b) and a < b) end)
  local right, right2 = {}, {}
  for _, n in ipairs(pet) do table.insert(right, n) end
  for _, n in ipairs(other) do table.insert(right, n) end
  for _, n in ipairs(tracking) do table.insert(right2, n) end
  for _, n in ipairs(prof) do table.insert(right2, n) end
  -- Spill extras from one side bar into free room on the other.
  while #right > 12 and #right2 < 12 do table.insert(right2, table.remove(right)) end
  return right, right2, ids
end

-- Spellbook index of a flyout, by flyout ID (for undo).
local function FlyoutIndex(want)
  if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return end
  local bank = Enum.SpellBookSpellBank.Player
  for tab = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local line = C_SpellBook.GetSpellBookSkillLineInfo(tab)
    if line then
      for i = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
        local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
        if item and item.itemType == Enum.SpellBookItemType.Flyout and item.actionID == want then return i end
      end
    end
  end
end

-- Action types undo can put back. Apply leaves slots of any other type alone.
local function Restorable(t)
  if t == "spell" or t == "item" or t == "macro" then return true end
  if t == "flyout" then return C_SpellBook and C_SpellBook.PickupSpellBookItem and true end
  if t == "summonmount" then return C_MountJournal and C_MountJournal.GetMountInfoByID and true end
  if t == "summonpet" then return _G.C_PetJournal and _G.C_PetJournal.PickupPet and true end
  if t == "equipmentset" then return C_EquipmentSet and C_EquipmentSet.PickupEquipmentSet and true end
  return false
end

-- Puts a backed-up action on the cursor. Macros go back by name, since
-- macro indexes shift when macros are created or deleted.
local function PickupSaved(t, id, text)
  if t == "spell" then PickupSpellID(id)
  elseif t == "item" then PickupItemID(id)
  elseif t == "macro" then
    local i = text and GetMacroIndexByName(text)
    if i and i > 0 then PickupMacro(i)
    elseif not text then PickupMacro(id) end -- backup from an older version
  elseif t == "flyout" then
    local index = FlyoutIndex(id)
    if index then C_SpellBook.PickupSpellBookItem(index, Enum.SpellBookSpellBank.Player) end
  elseif t == "summonmount" then
    local _, spellID = C_MountJournal.GetMountInfoByID(id)
    if spellID then PickupSpellID(spellID) end
  elseif t == "summonpet" then pcall(_G.C_PetJournal.PickupPet, id)
  elseif t == "equipmentset" then
    local setID = id
    if type(id) == "string" and C_EquipmentSet.GetEquipmentSetID then setID = C_EquipmentSet.GetEquipmentSetID(id) end
    if setID then pcall(C_EquipmentSet.PickupEquipmentSet, setID) end
  end
end

local function Apply()
  if InCombatLockdown() then return ns.Print("can't change bars in combat.") end
  local profile, class = Profile()
  if not profile then return ns.Print("no profile for " .. class .. " yet.") end
  local known = KnownSpells()
  local bags, bagList = BagItems()

  -- Keep the very first backup, so undo always returns to the bars from
  -- before the first apply. Slots holding something undo can't put back
  -- are left alone.
  local first = not M.charDB.backup
  local backup = M.charDB.backup or {}
  local keep, kept = {}, 0
  for _, slot in ipairs(ManagedSlots()) do
    local t, id = GetActionInfo(slot)
    if t and not Restorable(t) then keep[slot] = true; kept = kept + 1 end
    if first and t then backup[slot] = { t, id, t == "macro" and GetActionText(slot) or nil } end
  end
  M.charDB.backup = backup

  ClearCursor()
  for _, slot in ipairs(ManagedSlots()) do
    if not keep[slot] then ClearSlot(slot) end
  end

  local missing = {}
  local C = ns.modules.controller
  for bar = 1, 2 do
    for i = 1, 12 do
      local entry = profile[bar] and profile[bar][i]
      local slot = BAR_OFFSET[bar] + i
      if entry and not keep[slot] then
        local item = ResolveEntry(entry, known)
        if item.missing then table.insert(missing, item.missing)
        elseif C and C.Place then C.Place(slot, item)
        elseif item.kind == "spell" then PlaceSpell(slot, item.id) end
      end
    end
  end

  local utility = profile[3] or M.utility
  for i = 1, 12 do
    local entry = utility[i]
    if entry and not keep[BAR_OFFSET[3] + i] then
      local id = ResolveUtility(entry, bags, bagList)
      if id then PlaceItem(BAR_OFFSET[3] + i, id) end
    end
  end

  local right, right2, ids = SideBars(profile, known)
  for i, name in ipairs(right) do
    if i <= 12 and not keep[RIGHT_BAR + i] then PlaceSpell(RIGHT_BAR + i, ids[name]) end
  end
  for i, name in ipairs(right2) do
    if i <= 12 and not keep[RIGHT_BAR_2 + i] then PlaceSpell(RIGHT_BAR_2 + i, ids[name]) end
  end
  if #right > 12 or #right2 > 12 then ns.Print("side bars full; some spells stay in the spellbook.") end

  ns.Print("bars set for " .. class .. ". /ac spells undo to go back.")
  if kept > 0 then ns.Print(kept .. " slots kept as they were (undo can't restore what they hold).") end
  if #missing > 0 then ns.Print("left empty (not learned yet, or macro not installed): " .. table.concat(missing, ", ")) end
end

local function Undo()
  if InCombatLockdown() then return ns.Print("can't change bars in combat.") end
  local backup = M.charDB.backup
  if not backup then return ns.Print("nothing to undo.") end
  ClearCursor()
  for _, slot in ipairs(ManagedSlots()) do
    local saved = backup[slot]
    local cur = GetActionInfo(slot)
    -- Apply left slots it can't restore alone; so does undo.
    if not (cur and not Restorable(cur)) and not (saved and not Restorable(saved[1])) then
      ClearSlot(slot)
      if saved then
        PickupSaved(saved[1], saved[2], saved[3])
        if GetCursorInfo() then PlaceAction(slot) end
        ClearCursor()
      end
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
      local entry = profile[bar] and profile[bar][i]
      if entry then
        local item = ResolveEntry(entry, known)
        local what = item.missing and ("|cff888888" .. item.missing .. " (not learned)|r") or item.name
        print("  " .. (bar == 2 and "Shift+" or "") .. KEY_LABELS[i] .. " -> " .. what)
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
  local right, right2, ids = SideBars(profile, known)
  local utility = profile[3] or M.utility
  local plan = { changes = 0, spellsMissing = 0, itemsMissing = 0, macrosMissing = 0 }
  for r, row in ipairs(ROWS) do
    local entries = {}
    for i = 1, 12 do
      local e = { slot = row.first + i }
      if r <= 2 then
        local entry = profile[r] and profile[r][i]
        if entry then
          local item = ResolveEntry(entry, known)
          e.item = item
          -- A missing home keeps its entry's form: item, macro or spell.
          e.kind = item.kind or ((entry.item or entry.utility) and "item")
            or (item.macro and "macro") or "spell"
          e.id = item.id or (not item.missing and item.name) or nil
          e.name = item.name or item.missing
        end
      elseif r == 3 then
        local entry = utility[i]
        if entry then
          local id = ResolveUtility(entry, bags, bagList)
          e.kind, e.id, e.name = "item", id, id and ItemInfo(id) or UtilityLabel(entry)
        end
      else
        local name = (r == 4 and right or right2)[i]
        if name then e.kind, e.id, e.name = "spell", ids[name], name end
      end
      local cur, curID = GetActionInfo(e.slot)
      local C = ns.modules.controller
      if not e.kind then e.state = cur and "clear" or "empty"
      elseif not e.id then e.state = "missing"
      elseif e.item and C and C.Same then e.state = C.Same(e.slot, e.item) and "same" or "new"
      elseif cur == e.kind and curID == e.id then e.state = "same"
      else e.state = "new" end
      if e.state == "new" or e.state == "clear" then plan.changes = plan.changes + 1 end
      if e.state == "missing" then
        if e.kind == "spell" then plan.spellsMissing = plan.spellsMissing + 1
        elseif e.kind == "macro" then plan.macrosMissing = plan.macrosMissing + 1
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
      text = (e.kind == "spell" and "Not learned yet. Placed here once you train it and apply again.")
        or (e.kind == "macro" and "Macro not installed. Install it on the Macros page, then apply again.")
        or "None in your bags. Placed here once you carry one and apply again." })
  elseif e.kind == "flyout" or e.kind == "macro" then
    local C = ns.modules.controller
    s:SetIcon(C and C.Icon and C.Icon(e.item) or UI.QUESTION)
    if e.state == "new" then s:SetMark(UI.GREEN) end
    s:SetTip({ title = e.name, text = e.state == "new" and "Placed here on apply." or nil })
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
    if p.macrosMissing > 0 then parts[#parts + 1] = "|cffaaaaaa" .. p.macrosMissing .. " macros not installed|r" end
    return table.concat(parts, "  ·  ")
  end,

  actions = {
    { label = "Undo", fn = Undo, tooltip = "Put the bars back the way they were before the first apply." },
    { label = "Apply", fn = Apply, tooltip = "Fill all bars as shown. Your current bars are saved for undo." },
  },
})

ns.RegisterCommand("spells", "fill bars: /ac spells [apply|undo]", function(arg)
  arg = (arg or ""):lower()
  if arg == "apply" then Apply()
  elseif arg == "undo" then Undo()
  else Show() end
end)
