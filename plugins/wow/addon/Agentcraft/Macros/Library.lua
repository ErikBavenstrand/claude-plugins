-- Macro library core: categories, the macro registry, placeholder filling,
-- install state and install/remove. Macro data lives in Macros/Data/*.lua;
-- the window page is Macros/Page.lua.
--
-- Adding a macro (in a Data file):
--   L.Add({
--     name = "Pull",              -- shown on the action button; 16 characters max
--     category = "combat",        -- a key from L.categories
--     class = "HUNTER",           -- omit for every class
--     race = "Tauren",            -- race file name (Scourge = Undead, NightElf); omit for every race
--     profession = "Fishing",     -- profession it needs; omit if none
--     tags = { "solo", "group" }, -- free topic tags shown as chips
--     order = 10,                 -- position inside its category (lower first)
--     icon = "Serpent Sting",     -- spell or item name for the picture; or iconFile = "INV_..."
--     requires = { "Serpent Sting" }, -- spells that must be in your spellbook
--     perCharacter = true,        -- character tab (class macros) or account tab
--     untested = true,            -- shows a warning: not yet confirmed on this game version
--     live = true,                -- rewritten when bags/level/pet/gear change (see RefreshLive)
--     fallback = "No food",       -- live only: red error shown when it can't be filled
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
  { key = "racial", title = "Racial", icon = "Interface\\Icons\\Ability_WarStomp" },
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

-- Tags ------------------------------------------------------------------------------
-- Every macro gets tags worked out from its fields: class, race, profession,
-- category, its own topic tags, and "Untested". The page filters on them.

L.tagTypes = {
  class = { order = 1 },
  race = { order = 2, color = { 0.85, 0.65, 0.45 } },
  profession = { order = 3, color = { 0.45, 0.85, 0.45 } },
  topic = { order = 4, color = { 0.8, 0.8, 0.8 } },
  status = { order = 5, color = { 1, 0.55, 0.2 } },
}

local RACE_LABELS = { Scourge = "Undead", NightElf = "Night Elf" }

local function Title(s) return (s:gsub("^%l", string.upper)) end

local function ClassLabel(class)
  local names = LOCALIZED_CLASS_NAMES_MALE
  return names and names[class] or Title(class:lower())
end

-- { { key, label, type, color }, ... } sorted by type then label.
function L.Tags(m)
  if m._tags then return m._tags end
  local tags = {}
  local function Add(kind, value, label, color)
    tags[#tags + 1] = { key = kind .. ":" .. value, label = label, type = kind,
      color = color or L.tagTypes[kind].color }
  end
  if m.class then
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
    Add("class", m.class, ClassLabel(m.class), c and { c.r, c.g, c.b })
  end
  if m.race then Add("race", m.race, RACE_LABELS[m.race] or m.race) end
  if m.profession then Add("profession", m.profession, m.profession) end
  for _, c in ipairs(L.categories) do
    if c.key == m.category then Add("topic", c.key, c.title) end
  end
  for _, t in ipairs(m.tags or {}) do Add("topic", t, Title(t)) end
  if m.untested then Add("status", "untested", "Untested") end
  table.sort(tags, function(a, b)
    local oa, ob = L.tagTypes[a.type].order, L.tagTypes[b.type].order
    if oa ~= ob then return oa < ob end
    return a.label < b.label
  end)
  m._tags = tags
  return tags
end

function L.HasTag(m, key)
  for _, t in ipairs(L.Tags(m)) do if t.key == key then return true end end
  return false
end

-- Professions this character has, by name.
local function MyProfessions()
  local have = {}
  if GetProfessions then
    for _, idx in ipairs({ GetProfessions() }) do
      if idx then
        local name = GetProfessionInfo(idx)
        if name then have[name] = true end
      end
    end
  end
  return have, GetProfessions ~= nil
end

-- Whether the macro suits this character's class, race and professions.
function L.Fits(m)
  local _, class = UnitClass("player")
  local _, race = UnitRace("player")
  if m.class and m.class ~= class then return false end
  if m.race and m.race ~= race then return false end
  if m.profession then
    local have, canCheck = MyProfessions()
    if canCheck and not have[m.profession] then return false end
  end
  return true
end

-- Macros sorted by category, then order, then name. Only the ones that
-- fit this character unless showAll.
function L.Entries(showAll)
  local list = {}
  for _, m in ipairs(L.macros) do
    if showAll or L.Fits(m) then list[#list + 1] = m end
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

-- Fishing poles are weapon class 2, subclass 20 on every client and
-- language; the subtype text differs ("Fishing Poles" vs "Fishing Pole").
function L.IsPole(id)
  if not (id and C_Item and C_Item.GetItemInfoInstant) then return false end
  local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
  return classID == 2 and subClassID == 20
end
local IsPole = L.IsPole

local function PoleSubType(id)
  return select(3, C_Item.GetItemInfoInstant(id))
end

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

-- Best food or drink you can use (the ActionBars module knows how to spot them).
local function BestConsumable(kind)
  local AB = ns.modules.actionbars
  return AB and AB.BestConsumableName and AB.BestConsumableName(kind)
end

-- The pole in your hands or bags: item ID.
local function FindPole()
  local main = GetInventoryItemID("player", 16)
  if IsPole(main) then return main end
  for _, id in ipairs(BagItemIDs()) do if IsPole(id) then return id end end
end

-- Weapons to return to after fishing: what you wear now, or what Agentcraft
-- saw you wearing before you picked up the pole.
local function Weapons()
  local main, off = GetInventoryItemID("player", 16), GetInventoryItemID("player", 17)
  if main and not IsPole(main) then return main, off end
  local saved = ns.charDB and ns.charDB.weapons
  if saved then return saved.main, saved.off end
  -- Never seen: take the first main-hand weapon and off-hand item in your bags.
  local main, off
  for _, id in ipairs(BagItemIDs()) do
    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(id)
    if not main and classID == 2 and not IsPole(id) and (equipLoc == "INVTYPE_WEAPON"
      or equipLoc == "INVTYPE_WEAPONMAINHAND" or equipLoc == "INVTYPE_2HWEAPON") then
      main = id
    elseif not off and (equipLoc == "INVTYPE_HOLDABLE" or equipLoc == "INVTYPE_SHIELD"
      or equipLoc == "INVTYPE_WEAPONOFFHAND") then
      off = id
    end
  end
  return main, off
end
L.Weapons = Weapons

-- Fishing lures, best first (item ID, fishing bonus).
L.lures = {
  { 6533, 100 }, -- Aquadynamic Fish Attractor
  { 6532, 75 },  -- Bright Baubles
  { 7307, 75 },  -- Flesh Eating Worm
  { 6530, 50 },  -- Nightcrawlers
  { 6529, 25 },  -- Shiny Bauble
}

-- The lure to put on now: the best one in your bags, but only while the
-- pole is in your hands without a lure on it. Otherwise nil.
function L.LureNeeded()
  if not IsPole(GetInventoryItemID("player", 16)) then return nil end
  if GetWeaponEnchantInfo and GetWeaponEnchantInfo() then return nil end
  for _, l in ipairs(L.lures) do
    local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(l[1]) or GetItemCount(l[1])
    if count and count > 0 then return ItemName(l[1]) end
  end
end

L.placeholders = {
  -- Fish macro steps: the lure while one is needed, else Fishing.
  LURE = function() return L.LureNeeded() end,
  LURESLOT = function() return L.LureNeeded() and "16" or nil end,
  FISHSPELL = function() if not L.LureNeeded() then return "Fishing" end end,
  FISHICON = function() return L.LureNeeded() or "Fishing" end,
  -- The Eat macro's icon and count: your best food, else your best drink.
  EATICON = function()
    local name = BestConsumable("Food") or BestConsumable("Drink")
    if name then return name end
    return nil, "no food or drink in bags"
  end,
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
    local name = BestConsumable("Food")
    if name then return name end
    return nil, "no food in bags"
  end,
  DRINK = function()
    local name = BestConsumable("Drink")
    if name then return name end
    return nil, "no drink in bags"
  end,
  FISHINGPOLE = function()
    local id = FindPole()
    if id then return ItemName(id) end
    return nil, "no fishing pole"
  end,
  -- The pole's type as the client spells it, for [equipped:...] conditions.
  POLETYPE = function()
    local id = FindPole()
    if id then return PoleSubType(id) end
    return nil, "no fishing pole"
  end,
  MAINHAND = function()
    local main = Weapons()
    if main then return ItemName(main) end
    return nil, "equip your weapon once"
  end,
  OFFHAND = function()
    local _, off = Weapons()
    return off and ItemName(off) or nil
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

-- Live macros (live = true) are rewritten whenever your bags, level, pet or
-- weapon change, so they always show and use what you carry right now. When
-- one can't be filled (no food at all), it shows m.fallback as a red error.
function L.RefreshLive()
  if InCombatLockdown() then return end
  for _, m in ipairs(L.macros) do
    if m.live then
      local index = IndexOf(m.name)
      if index > 0 then
        local body = L.Resolve(m)
        if not body and m.fallback then
          body = "/run UIErrorsFrame:AddMessage(\"" .. m.fallback .. "\", 1, 0.1, 0.1)"
        end
        local current = (GetMacroBody(index) or ""):gsub("%s+$", "")
        if body and current ~= body:gsub("%s+$", "") then
          pcall(EditMacro, index, m.name, IconFor(m), body)
        end
      end
    end
  end
end

do
  local pending
  local frame = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP",
    "PLAYER_REGEN_ENABLED", "UNIT_PET", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED" }) do
    pcall(frame.RegisterEvent, frame, e)
  end
  frame:SetScript("OnEvent", function()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function() pending = nil; L.Invalidate(); L.RefreshLive() end)
  end)
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
