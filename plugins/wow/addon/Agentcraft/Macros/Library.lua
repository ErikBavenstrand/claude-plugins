-- Macro library core: categories, the macro registry, placeholder filling,
-- install state and install/remove. Macro data lives in Macros/Data/*.lua;
-- the window page is Macros/Page.lua.
--
-- Adding a macro (in a Data file):
--   L.Add({
--     name = "Pull",              -- shown on the action button; 16 characters max
--     category = "combat",        -- a key from L.categories
--     class = "HUNTER",           -- omit for every class
--     order = 10,                 -- position inside its category (lower first)
--     icon = "Serpent Sting",     -- spell or item name for the picture; or iconFile = "INV_..."
--     requires = { "Serpent Sting" }, -- spells that must be in your spellbook
--     perCharacter = true,        -- character tab (class macros) or account tab
--     untested = true,            -- shows a warning: not yet confirmed on this game version
--     desc = "One sentence: what pressing it does.",
--     modifiers = { "Shift: ...", "Ctrl: ..." },
--     body = "#showtooltip ...\n/cast ...",   -- 255 characters max after filling
--   })
--
-- Conventions every macro follows:
--   * Start with #showtooltip so the button shows the right icon and cooldown.
--   * Plain press does the common thing; Shift is the alternative; Ctrl the rare one.
--   * Harmful casts use [@target,harm,nodead] so they never hit friends or corpses.
--   * Name it after what it does, one word where possible ("Pull", "Fish").
local _, ns = ...
local L = {}
ns.MacroLibrary = L

L.categories = {
  { key = "combat", title = "Combat", icon = "Interface\\Icons\\Ability_Marksmanship" },
  { key = "pet", title = "Pet", icon = "Interface\\Icons\\Ability_Hunter_BeastCall" },
  { key = "fishing", title = "Fishing", icon = "Interface\\Icons\\Trade_Fishing" },
  { key = "professions", title = "Professions", icon = "Interface\\Icons\\Trade_Engineering" },
  { key = "utility", title = "Utility", icon = "Interface\\Icons\\INV_Misc_Bag_08" },
}
local CATEGORY_RANK = {}
for i, c in ipairs(L.categories) do CATEGORY_RANK[c.key] = i end

L.macros = {}

function L.Add(m)
  assert(m.name and #m.name <= 16, "macro name missing or longer than 16 characters: " .. tostring(m.name))
  assert(CATEGORY_RANK[m.category], "unknown macro category: " .. tostring(m.category))
  table.insert(L.macros, m)
end

-- Macros for this character, sorted by category, then order, then name.
function L.Entries()
  local _, class = UnitClass("player")
  local list = {}
  for _, m in ipairs(L.macros) do
    if not m.class or m.class == class then list[#list + 1] = m end
  end
  table.sort(list, function(a, b)
    local ca, cb = CATEGORY_RANK[a.category], CATEGORY_RANK[b.category]
    if ca ~= cb then return ca < cb end
    if (a.order or 50) ~= (b.order or 50) then return (a.order or 50) < (b.order or 50) end
    return a.name < b.name
  end)
  return list
end

-- Known spells ----------------------------------------------------------------------

local known

local function ScanBank(map, bank, from, to)
  for i = from, to do
    local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
    if item and item.name then map[item.name] = true end
  end
end

-- Spells in the player and pet spellbooks, cached until L.Invalidate().
function L.Known()
  if known then return known end
  known = {}
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
    local player = Enum.SpellBookSpellBank.Player
    for tab = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local line = C_SpellBook.GetSpellBookSkillLineInfo(tab)
      if line then ScanBank(known, player, line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems) end
    end
    if C_SpellBook.HasPetSpells then
      ScanBank(known, Enum.SpellBookSpellBank.Pet, 1, C_SpellBook.HasPetSpells() or 0)
    end
  end
  return known
end

function L.Invalidate() known = nil end

-- { { spell, true/false }, ... } for the detail panel.
function L.Requirements(m)
  local out, k = {}, L.Known()
  for _, spell in ipairs(m.requires or {}) do out[#out + 1] = { spell, k[spell] and true or false } end
  return out
end

function L.MissingSpell(m)
  for _, r in ipairs(L.Requirements(m)) do
    if not r[2] then return r[1] end
  end
end

-- Placeholders ----------------------------------------------------------------------

local function ItemName(id) return C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id) end
local function SubType(id) return C_Item and C_Item.GetItemInfoInstant and select(3, C_Item.GetItemInfoInstant(id)) end
local function IsPole(id) return id and SubType(id) == "Fishing Poles" end

local function BagItemIDs()
  local ids, seen = {}, {}
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local id = C_Container.GetContainerItemID(bag, slot)
      if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
  end
  return ids
end

-- Best food or drink you can use: highest required level.
local function BestConsumable(spellNames)
  local best, bestLevel
  local level = UnitLevel("player")
  for _, id in ipairs(BagItemIDs()) do
    local spell = C_Item.GetItemSpell and C_Item.GetItemSpell(id)
    if spell and spellNames[spell] then
      local minLevel = select(5, C_Item.GetItemInfo(id)) or 0
      if minLevel <= level and (not bestLevel or minLevel > bestLevel) then best, bestLevel = id, minLevel end
    end
  end
  return best and ItemName(best)
end

L.placeholders = {
  PETFOOD = function()
    if not (C_PetInfo and C_PetInfo.CanPetEatItem) then return nil, "can't check pet food here" end
    if not UnitExists("pet") then return nil, "summon your pet" end
    for _, id in ipairs(BagItemIDs()) do
      local ok, eats = pcall(C_PetInfo.CanPetEatItem, id)
      if ok and eats then return ItemName(id) end
    end
    return nil, "no pet food in bags"
  end,
  FOOD = function()
    return BestConsumable({ Food = true, Refreshment = true }) or nil, "no food in bags"
  end,
  DRINK = function()
    return BestConsumable({ Drink = true, Refreshment = true }) or nil, "no drink in bags"
  end,
  FISHINGPOLE = function()
    local main = GetInventoryItemID("player", 16)
    if IsPole(main) then return ItemName(main) end
    for _, id in ipairs(BagItemIDs()) do if IsPole(id) then return ItemName(id) end end
    return nil, "no fishing pole"
  end,
  MAINHAND = function()
    local id = GetInventoryItemID("player", 16)
    if not id then return nil, "no main-hand weapon" end
    if IsPole(id) then return nil, "unequip the fishing pole" end
    return ItemName(id)
  end,
  OFFHAND = function()
    local id = GetInventoryItemID("player", 17)
    return id and ItemName(id) or nil
  end,
}

-- The body with placeholders filled, or nil and a short reason.
-- {KEY?} is optional: when it can't be filled, its line is dropped.
function L.Resolve(m)
  local reason
  local lines = {}
  for line in (m.body .. "\n"):gmatch("(.-)\n") do
    local drop = false
    line = line:gsub("{(%u+)(%??)}", function(key, optional)
      local fn = L.placeholders[key]
      local value, why
      if fn then value, why = fn() end
      if value then return value end
      if optional == "?" then drop = true else reason = reason or why or ("can't fill " .. key) end
      return ""
    end)
    if not drop then lines[#lines + 1] = line end
  end
  if reason then return nil, reason end
  local body = table.concat(lines, "\n")
  if #body > 255 then return nil, "longer than 255 characters" end
  return body
end

-- State -----------------------------------------------------------------------------

local function IndexOf(name)
  local i = GetMacroIndexByName(name)
  if i and i > 0 then return i end
  -- Macros installed by the first catalog used an "AC " prefix.
  i = GetMacroIndexByName("AC " .. name)
  if i and i > 0 then return i, true end
  return 0
end

-- Returns state, index, detail. States:
--   installed  in /macro and up to date
--   update     in /macro but its text differs (spell or item changed)
--   blocked    can't be installed yet; detail says why
--   ready      can be installed
function L.State(m)
  local index, legacy = IndexOf(m.name)
  local body, why = L.Resolve(m)
  local missing = L.MissingSpell(m)
  if index > 0 then
    local current = (GetMacroBody(index) or ""):gsub("%s+$", "")
    if legacy or (body and current ~= body:gsub("%s+$", "")) then return "update", index end
    return "installed", index
  end
  if missing then return "blocked", 0, "learn " .. missing end
  if not body then return "blocked", 0, why end
  return "ready", 0
end

local function IconFor(m) return m.iconFile or "INV_Misc_QuestionMark" end

function L.Install(list)
  if InCombatLockdown() then return ns.Print("can't change macros in combat.") end
  local done, skipped = {}, {}
  for _, m in ipairs(list) do
    local body, why = L.Resolve(m)
    if not body then
      skipped[#skipped + 1] = m.name .. " (" .. why .. ")"
    else
      local index = IndexOf(m.name)
      local ok, err
      if index > 0 then
        ok, err = pcall(EditMacro, index, m.name, IconFor(m), body)
      else
        ok, err = pcall(CreateMacro, m.name, IconFor(m), body, m.perCharacter and true or nil)
      end
      if ok then done[#done + 1] = m.name else skipped[#skipped + 1] = m.name .. " (" .. tostring(err) .. ")" end
    end
  end
  if #done > 0 then ns.Print("installed " .. table.concat(done, ", ") .. ". Use Pick up to put one on a bar.") end
  if #skipped > 0 then ns.Print("skipped " .. table.concat(skipped, "; ")) end
  if #done == 0 and #skipped == 0 then ns.Print("tick some macros first.") end
end

function L.Remove(list)
  if InCombatLockdown() then return ns.Print("can't change macros in combat.") end
  local removed = {}
  for _, m in ipairs(list) do
    local index = IndexOf(m.name)
    if index > 0 then DeleteMacro(index); removed[#removed + 1] = m.name end
  end
  ns.Print(#removed > 0 and ("removed " .. table.concat(removed, ", ")) or "none of those are installed.")
end

-- Puts the installed macro on the cursor so it can be dropped on a bar.
function L.PickUp(m)
  if InCombatLockdown() then return ns.Print("can't pick up macros in combat.") end
  local index = IndexOf(m.name)
  if index == 0 then return ns.Print(m.name .. " isn't installed yet.") end
  PickupMacro(index)
end
