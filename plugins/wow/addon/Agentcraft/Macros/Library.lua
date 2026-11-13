-- Macro library core: categories, the macro registry, placeholder filling,
-- install state and install/remove. Macro data lives in Macros/Data/*.lua;
-- the window page is Macros/Page.lua.
--
-- Adding a macro (in a Data file):
--   L.Add({
--     name = "Opener",            -- shown on the action button; 16 characters max
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
--     desc = "One sentence: what pressing it does.",
--     body = "#showtooltip ...\n/cast ...",   -- 255 characters max after filling
--   })
--
-- Conventions every macro follows:
--   * Start with #showtooltip so the button shows the right icon and cooldown.
--   * Install once, works forever: name only spells and slash commands, never
--     an item (food, pole, weapon, potion). Items go on bars as item buttons.
--   * No Shift/Ctrl variants (they are bar layers) and no @mouseover/@cursor.
--   * Harmful casts use [@target,harm,nodead] so they never hit friends or corpses.
--   * Name it after what it does, one word where possible ("Opener", "Fish").
--   * Install and Remove touch only macros Agentcraft wrote (bodies recorded
--     in AgentcraftDB.macroBodies). A player's own macro of the same name is
--     "taken" until they pick Replace. Remove also unbinds the macro's keys.
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
    -- Any of the five can be nil (no second primary, no First Aid...), and
    -- ipairs stops at the first nil, so take them by name.
    local a, b, c, d, e = GetProfessions()
    for _, idx in pairs({ a, b, c, d, e }) do
      local name = GetProfessionInfo(idx)
      if name then have[name] = true end
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


-- Fishing poles are weapon class 2, subclass 20 on every client and
-- language; the subtype text differs ("Fishing Poles" vs "Fishing Pole").
function L.IsPole(id)
  if not (id and C_Item and C_Item.GetItemInfoInstant) then return false end
  local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
  return classID == 2 and subClassID == 20
end
local IsPole = L.IsPole

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
  main, off = nil, nil
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
L.FindPole = FindPole

-- Placeholders ({KEY} in a body). Library macros must not depend on what is in
-- your bags or what you wear: a macro is installed once and has to keep
-- working without Agentcraft rewriting it. So no macro uses one today; the
-- mechanism stays for macros that fill in fixed facts (none yet).
L.placeholders = {}

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

local function Trim(s) return (s or ""):gsub("%s+$", "") end

-- Bodies Agentcraft wrote, by macro name (account SavedVariables), so a macro
-- of yours that happens to share a library name is never overwritten or deleted.
local function Written()
  if not ns.db then return {} end
  ns.db.macroBodies = ns.db.macroBodies or {}
  return ns.db.macroBodies
end

-- Whether the macro at index is one Agentcraft wrote.
local function IsOurs(m, index, legacy, body)
  if legacy then return true end
  local current = Trim(GetMacroBody(index))
  if body and current == Trim(body) then
    Written()[m.name] = current
    return true
  end
  -- An older Agentcraft text of a macro that kept its name (L.retired) is ours too.
  return Written()[m.name] == current or (L.retired and L.retired[m.name] == current) or false
end

-- A class or racial macro sitting in the shared account tab (installed
-- before it was marked perCharacter). EditMacro can't move it between tabs.
local function InWrongTab(m, index)
  return m.perCharacter and index <= (MAX_ACCOUNT_MACROS or 120)
end

-- Returns state, index, detail. States:
--   installed  in /macro and up to date
--   update     in /macro but its text differs (spell or item changed)
--   taken      a macro of yours already has this name; left alone unless
--              you pick Replace on that macro
--   blocked    can't be installed yet; detail says why
--   ready      can be installed
function L.State(m)
  local index, legacy = IndexOf(m.name)
  local body, why = L.Resolve(m)
  local missing = L.MissingSpell(m)
  if index > 0 then
    if not IsOurs(m, index, legacy, body) then return "taken", index, "your own macro has this name" end
    if legacy or InWrongTab(m, index) or (body and Trim(GetMacroBody(index)) ~= Trim(body)) then return "update", index end
    return "installed", index
  end
  if missing then return "blocked", 0, "learn " .. missing end
  if not body then return "blocked", 0, why end
  return "ready", 0
end

local function IconFor(m) return m.iconFile or "INV_Misc_QuestionMark" end

-- replace = true also overwrites a macro of yours with the same name (the
-- detail panel's Replace button); ticked installs never do.
function L.Install(list, replace)
  if InCombatLockdown() then return ns.Print("can't change macros in combat.") end
  local done, skipped = {}, {}
  for _, m in ipairs(list) do
    local body, why = L.Resolve(m)
    local missing = L.MissingSpell(m)
    local index, legacy = IndexOf(m.name)
    if missing then
      skipped[#skipped + 1] = m.name .. " (learn " .. missing .. ")"
    elseif not body then
      skipped[#skipped + 1] = m.name .. " (" .. why .. ")"
    elseif index > 0 and not replace and not IsOurs(m, index, legacy, body) then
      skipped[#skipped + 1] = m.name .. " (your own macro has this name)"
    else
      local ok, err
      if index > 0 and InWrongTab(m, index) then
        -- Recreate it in the character tab; put it back on your bar after.
        DeleteMacro(index)
        index = 0
      end
      if index > 0 then
        ok, err = pcall(EditMacro, index, m.name, IconFor(m), body)
      else
        ok, err = pcall(CreateMacro, m.name, IconFor(m), body, m.perCharacter and true or nil)
      end
      if ok then
        done[#done + 1] = m.name
        Written()[m.name] = Trim(body)
      else
        skipped[#skipped + 1] = m.name .. " (" .. tostring(err) .. ")"
      end
    end
  end
  if #done > 0 then ns.Print("installed " .. table.concat(done, ", ") .. ". Use Pick up to put one on a bar.") end
  if #skipped > 0 then ns.Print("skipped " .. table.concat(skipped, "; ")) end
  if #done == 0 and #skipped == 0 then ns.Print("tick some macros first.") end
end

-- Clears every key bound to the macro, so no key is left pointing at nothing.
local function Unbind(index)
  local name = GetMacroInfo and GetMacroInfo(index)
  if not (name and GetBindingKey and SetBinding) then return false end
  local keys = { GetBindingKey("MACRO " .. name) }
  for _, key in ipairs(keys) do SetBinding(key) end
  return #keys > 0
end

-- Deletes only macros Agentcraft wrote; one of yours with the same name stays.
function L.Remove(list)
  if InCombatLockdown() then return ns.Print("can't change macros in combat.") end
  local removed, kept, unbound = {}, {}, false
  for _, m in ipairs(list) do
    local index, legacy = IndexOf(m.name)
    if index > 0 then
      if IsOurs(m, index, legacy, L.Resolve(m)) then
        unbound = Unbind(index) or unbound
        DeleteMacro(index)
        Written()[m.name] = nil
        removed[#removed + 1] = m.name
      else
        kept[#kept + 1] = m.name
      end
    end
  end
  if unbound and SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
  if #kept > 0 then ns.Print("kept " .. table.concat(kept, ", ") .. ": your own macro has that name; delete it in /macro.") end
  if #removed > 0 then ns.Print("removed " .. table.concat(removed, ", "))
  elseif #kept == 0 then ns.Print("none of those are installed.") end
end

-- Puts the installed macro on the cursor so it can be dropped on a bar.
function L.PickUp(m)
  if InCombatLockdown() then return ns.Print("can't pick up macros in combat.") end
  local index = IndexOf(m.name)
  if index == 0 then return ns.Print(m.name .. " isn't installed yet.") end
  PickupMacro(index)
end
