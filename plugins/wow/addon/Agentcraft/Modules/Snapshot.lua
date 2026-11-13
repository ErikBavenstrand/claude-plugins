-- Snapshot: saves your whole character state to AgentcraftDB 10 seconds
-- after something changes (after combat ends) and on logout, so it can be
-- read outside the game (WTF\Account\<account>\SavedVariables\Agentcraft.lua,
-- written on /reload and logout). A save while the character isn't loaded
-- (often the case on logout) only records skippedIncomplete.
-- Each section runs on its own. If one fails, its last good table is kept
-- with staleSince/lastError (or the error is stored when there is none), and
-- fields that turned "<secret>" keep their last readable value (secretKept).
local _, ns = ...
local M = ns.RegisterModule("Snapshot", {
  description = "save your full character state on every reload and logout",
})

-- Compat helpers ----------------------------------------------------------------

local function SpellName(id)
  if not id then return end
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  if GetSpellInfo then return (GetSpellInfo(id)) end
end

local function ItemName(id)
  if C_Item and C_Item.GetItemNameByID then return C_Item.GetItemNameByID(id) end
  if C_Item and C_Item.GetItemInfo then return (C_Item.GetItemInfo(id)) end
end

local function LinkName(link) return link and link:match("%[(.-)%]") end

local function Money(c)
  c = c or 0
  return string.format("%dg %ds %dc", math.floor(c / 10000), math.floor(c / 100) % 100, c % 100)
end

local function Pack(...) return { n = select("#", ...), ... } end
-- Values the client hides from addons ("secret") can't be turned into text.
local function Safe(v)
  if issecretvalue and issecretvalue(v) then return "<secret>" end
  return tostring(v)
end
local function IsSecret(v) return issecretvalue and issecretvalue(v) end
-- Like Safe, but keeps numbers as numbers. A secret stored as is becomes nil.
local function Keep(v)
  if IsSecret(v) then return "<secret>" end
  return v
end

local function Join(t)
  local parts = {}
  for i = 1, t.n or #t do parts[i] = Safe(t[i]) end
  return table.concat(parts, ", ")
end

-- Sections ----------------------------------------------------------------------

local function Basics()
  local xpMax = UnitXPMax("player")
  local race = UnitRace("player")
  return {
    name = UnitName("player"),
    realm = GetRealmName(),
    race = race,
    class = select(2, UnitClass("player")),
    level = UnitLevel("player"),
    xp = string.format("%d / %d (%.0f%%)", UnitXP("player"), xpMax, xpMax > 0 and UnitXP("player") / xpMax * 100 or 0),
    rested = GetXPExhaustion and GetXPExhaustion() or 0,
    money = Money(GetMoney()),
    zone = GetZoneText() .. (GetSubZoneText() ~= "" and (" / " .. GetSubZoneText()) or ""),
    hearthstone = GetBindLocation and GetBindLocation(),
    guild = GetGuildInfo("player"),
    health = Safe(UnitHealth("player")) .. " / " .. Safe(UnitHealthMax("player")),
    mana = Safe(UnitPower("player", 0)) .. " / " .. Safe(UnitPowerMax("player", 0)),
  }
end

-- Each stat is read on its own: a secret value (no maths or formatting
-- allowed on it) stores "<secret>" and the other stats still save.
local function Stats()
  local s = {}
  local function Put(label, fn, ...)
    if not fn then return end
    local ok, v = pcall(fn, ...)
    if ok then s[label] = Keep(v) end
  end
  local function Sum(base, pos, neg)
    if IsSecret(base) or IsSecret(pos) or IsSecret(neg) then return "<secret>" end
    return (base or 0) + (pos or 0) + (neg or 0)
  end
  local function Pct(fn)
    local v = fn()
    if IsSecret(v) then return "<secret>" end
    return string.format("%.2f", v)
  end
  local names = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }
  for i, n in ipairs(names) do
    Put(n, function() return (select(2, UnitStat("player", i))) end)
  end
  Put("Armor", function() return (select(2, UnitArmor("player"))) end)
  if UnitRangedAttackPower then
    Put("Ranged attack power", function() return Sum(UnitRangedAttackPower("player")) end)
  end
  if UnitAttackPower then
    Put("Melee attack power", function() return Sum(UnitAttackPower("player")) end)
  end
  if UnitRangedDamage then
    Put("Ranged damage", function()
      local speed, minD, maxD = UnitRangedDamage("player")
      if IsSecret(speed) or IsSecret(minD) or IsSecret(maxD) then return "<secret>" end
      return string.format("%.0f-%.0f, speed %.2f", minD or 0, maxD or 0, speed or 0)
    end)
  end
  if GetRangedCritChance then Put("Ranged crit %", Pct, GetRangedCritChance) end
  if GetCritChance then Put("Melee crit %", Pct, GetCritChance) end
  if GetDodgeChance then Put("Dodge %", Pct, GetDodgeChance) end
  Put("Hit bonus %", GetHitModifier)
  return s
end

local SLOT_NAMES = { "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist",
  "Hands", "Finger 1", "Finger 2", "Trinket 1", "Trinket 2", "Back", "Main hand", "Off hand",
  "Ranged", "Tabard" }

local function Equipment()
  local out = {}
  for slot = 1, 19 do
    local link = GetInventoryItemLink("player", slot)
    if link then
      local ilvl = C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)
      local cur, max = GetInventoryItemDurability(slot)
      out[SLOT_NAMES[slot]] = string.format("%s | id %s | ilvl %s%s", LinkName(link) or "?",
        tostring(GetInventoryItemID("player", slot)), tostring(ilvl or "?"),
        cur and string.format(" | durability %d/%d", cur, max) or "")
    end
  end
  if GetInventoryItemCount then
    local ammo = GetInventoryItemID("player", 0)
    if ammo then out["Ammo"] = (ItemName(ammo) or tostring(ammo)) .. " x" .. GetInventoryItemCount("player", 0) end
  end
  return out
end

local function Bags()
  local counts, free, total = {}, 0, 0
  local numSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
  for bag = 0, 4 do
    local n = numSlots(bag) or 0
    total = total + n
    for slot = 1, n do
      local name, count
      if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then name, count = info.itemName or LinkName(info.hyperlink) or tostring(info.itemID), info.stackCount end
      else
        local _, c, _, _, _, _, link = GetContainerItemInfo(bag, slot)
        if link then name, count = LinkName(link), c end
      end
      if name then counts[name] = (counts[name] or 0) + (count or 1) else free = free + 1 end
    end
  end
  local list = {}
  for name, c in pairs(counts) do table.insert(list, name .. " x" .. c) end
  table.sort(list)
  return { slots = (total - free) .. " used / " .. total, items = list }
end

-- Skills: weapon skills, professions, languages, with rank/max.
local function Skills()
  local out = {}
  if C_SkillInfo and C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo then
    -- Modern-engine clients (WoW Forever): "Name rank/max (+mod)" grouped
    -- under their header, such as "Weapon Skills".
    local section = "Skills"
    for i = 1, C_SkillInfo.GetNumSkillLines() do
      local ok, s = pcall(C_SkillInfo.GetSkillLineInfo, i)
      if ok and type(s) == "table" and s.name then
        if s.isHeader then
          section = s.name
        else
          out[section] = out[section] or {}
          local text = string.format("%s %d/%d%s", s.name, s.rank or 0, s.maxRank or 0,
            (s.modifier and s.modifier ~= 0) and (" (+" .. s.modifier .. ")") or "")
          local dup = false
          for _, existing in ipairs(out[section]) do if existing == text then dup = true end end
          if not dup then table.insert(out[section], text) end
        end
      end
    end
  end
  if GetNumSkillLines then
    local section = "Skills"
    for i = 1, GetNumSkillLines() do
      local name, isHeader, _, rank, _, mod, max = GetSkillLineInfo(i)
      if isHeader then
        section = name
      elseif name then
        out[section] = out[section] or {}
        table.insert(out[section], string.format("%s %d/%d%s", name, rank or 0, max or 0,
          (mod and mod ~= 0) and (" (+" .. mod .. ")") or ""))
      end
    end
  end
  if GetProfessions then
    -- Empty profession slots are nil, so walk every slot (ipairs stops at the first nil).
    local list = {}
    local slots = Pack(GetProfessions())
    for i = 1, slots.n do
      local idx = slots[i]
      if idx then
        local name, _, rank, max = GetProfessionInfo(idx)
        table.insert(list, string.format("%s %d/%d", name, rank or 0, max or 0))
      end
    end
    out.Professions = list
  end
  return out
end

-- Spellbook for the player or pet: "name | rank | spellID [| passive]".
local function Spellbook(pet)
  local out = {}
  if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
    local bank = pet and Enum.SpellBookSpellBank.Pet or Enum.SpellBookSpellBank.Player
    local function Entry(i)
      local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
      if not (item and item.name) then return end
      local rank = C_SpellBook.GetSpellBookItemName and select(2, C_SpellBook.GetSpellBookItemName(i, bank))
      return string.format("%s | %s | %s%s", item.name, rank or "", tostring(item.spellID),
        item.isPassive and " | passive" or "")
    end
    if pet then
      local n = C_SpellBook.HasPetSpells and C_SpellBook.HasPetSpells() or 0
      local list = {}
      for i = 1, n or 0 do
        local e = Entry(i)
        if e then list[#list + 1] = e end
      end
      return list
    end
    for tab = 1, C_SpellBook.GetNumSpellBookSkillLines() do
      local line = C_SpellBook.GetSpellBookSkillLineInfo(tab)
      if line then
        local list = {}
        for i = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
          local e = Entry(i)
          if e then list[#list + 1] = e end
        end
        out[line.name or ("Tab " .. tab)] = list
      end
    end
  else
    local book = pet and BOOKTYPE_PET or BOOKTYPE_SPELL
    local function Entry(i)
      local name, rank = GetSpellBookItemName(i, book)
      local _, id = GetSpellBookItemInfo(i, book)
      local passive = IsPassiveSpell and IsPassiveSpell(i, book)
      return string.format("%s | %s | %s%s", name or "?", rank or "", tostring(id), passive and " | passive" or "")
    end
    if pet then
      local list = {}
      for i = 1, (HasPetSpells and HasPetSpells() or 0) do table.insert(list, Entry(i)) end
      return list
    end
    for tab = 1, GetNumSpellTabs() do
      local tabName, _, offset, num = GetSpellTabInfo(tab)
      local list = {}
      for i = offset + 1, offset + num do table.insert(list, Entry(i)) end
      out[tabName or ("Tab " .. tab)] = list
    end
  end
  return out
end

-- Modern trait trees (C_Traits): every node with points in it.
local function TraitTalents()
  if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits) then return end
  local configID = C_ClassTalents.GetActiveConfigID()
  local cfg = configID and C_Traits.GetConfigInfo(configID)
  if not (cfg and cfg.treeIDs) then return end
  local list = {}
  for _, treeID in ipairs(cfg.treeIDs) do
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
      local node = C_Traits.GetNodeInfo(configID, nodeID)
      if node and (node.activeRank or 0) > 0 and node.activeEntry then
        local entry = C_Traits.GetEntryInfo(configID, node.activeEntry.entryID)
        local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
        local spellID = def and (def.spellID or def.overriddenSpellID)
        local desc = spellID and C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(spellID)
        table.insert(list, string.format("%s %d/%d (spell %s)%s", SpellName(spellID) or ("node " .. nodeID),
          node.activeRank, node.maxRanks or 0, tostring(spellID),
          (desc and desc ~= "") and (": " .. desc:gsub("\r?\n", " ")) or ""))
      end
    end
  end
  if #list > 0 then return { ["Trait tree"] = list } end
end

-- Classic-style talent trees. isPet = true reads pet talents where they exist.
local function TreeTalents(isPet)
  local out = {}
  if not (GetNumTalentTabs and GetTalentInfo) then return out end
  local tabs = isPet and GetNumTalentTabs(false, true) or GetNumTalentTabs()
  for tab = 1, tabs or 0 do
    local a, b = GetTalentTabInfo(tab, false, isPet)
    local treeName = type(a) == "string" and a or b -- older clients: name first
    local spent, list = 0, {}
    local num = isPet and GetNumTalents(tab, false, true) or GetNumTalents(tab)
    for i = 1, num or 0 do
      local name, _, tier, column, rank, maxRank = GetTalentInfo(tab, i, false, isPet)
      if name then
        rank = rank or 0
        spent = spent + rank
        table.insert(list, string.format("%s %d/%d (tier %s, col %s)", name, rank, maxRank or 0,
          tostring(tier), tostring(column)))
      end
    end
    out[(treeName or ("Tree " .. tab)) .. " (" .. spent .. " points)"] = list
  end
  return out
end

local function Talents()
  local ok, traits = pcall(TraitTalents)
  if ok and traits then return traits end
  return TreeTalents(false)
end

-- Which talent functions exist and what they return, for working out what
-- this client supports.
local function TalentDebug()
  local d = {}
  for _, n in ipairs({ "GetNumTalentTabs", "GetTalentTabInfo", "GetNumTalents", "GetTalentInfo",
      "UnitCharacterPoints", "GetUnspentTalentPoints", "GetNumSpecializations", "GetSpecialization",
      "GetActiveTalentGroup", "GetMaxTalentTier", "GetPetTrainingPoints", "C_ClassTalents", "C_Traits",
      "C_SpecializationInfo", "C_Talent", "C_PetTalents" }) do
    d[n] = type(_G[n])
  end
  local function Try(label, fn, ...)
    if fn then d[label] = Join(Pack(pcall(fn, ...))) end
  end
  Try("GetNumTalentTabs()", GetNumTalentTabs)
  Try("GetTalentTabInfo(1)", GetTalentTabInfo, 1)
  Try("GetNumTalents(1)", GetNumTalents, 1)
  Try("GetTalentInfo(1,1)", GetTalentInfo, 1, 1)
  Try("GetTalentInfo(1,1,1)", GetTalentInfo, 1, 1, 1)
  Try("UnitCharacterPoints", UnitCharacterPoints, "player")
  Try("GetUnspentTalentPoints()", GetUnspentTalentPoints)
  Try("GetNumTalentTabs(false,true)", GetNumTalentTabs, false, true)
  if C_ClassTalents then Try("C_ClassTalents.GetActiveConfigID()", C_ClassTalents.GetActiveConfigID) end
  return d
end

local function Pet()
  if not UnitExists("pet") then return { active = false } end
  local p = {
    active = true,
    name = UnitName("pet"),
    family = UnitCreatureFamily and UnitCreatureFamily("pet"),
    level = UnitLevel("pet"),
    health = Safe(UnitHealth("pet")) .. " / " .. Safe(UnitHealthMax("pet")),
  }
  if GetPetHappiness then
    local happiness, damagePct, loyaltyRate = GetPetHappiness()
    p.happiness = ({ "Unhappy", "Content", "Happy" })[happiness or 0] or tostring(happiness)
    p.damagePercent = damagePct
    p.loyaltyRate = loyaltyRate
  end
  -- Modern-engine clients keep these in C_PetInfo (as Simulationcraft's Forever mode does).
  if C_PetInfo then
    if C_PetInfo.GetPetHappiness then
      local r = Pack(pcall(C_PetInfo.GetPetHappiness))
      if r[1] then
        local happiness = r[2]
        p.happiness = ({ "Unhappy", "Content", "Happy" })[tonumber(happiness) or 0] or tostring(happiness)
        p.happinessRaw = Join({ n = r.n - 1, select(2, unpack(r, 1, r.n)) })
      end
    end
    if C_PetInfo.GetPetTrainingPoints then
      local ok, total, spent = pcall(C_PetInfo.GetPetTrainingPoints)
      if ok and tonumber(total) then
        p.trainingPoints = string.format("%d total, %d spent, %d free", total, spent or 0, total - (spent or 0))
      end
    end
    if C_PetInfo.GetPetTalentTree then
      local ok, tree = pcall(C_PetInfo.GetPetTalentTree)
      if ok and tree then p.talentTree = Safe(tree) end
    end
    if C_PetInfo.GetPetLoyalty then
      local ok, v = pcall(C_PetInfo.GetPetLoyalty)
      if ok then p.loyalty = v end
    end
  end
  if GetPetLoyalty then p.loyalty = GetPetLoyalty() end
  if GetPetExperience then
    local cur, max = GetPetExperience()
    p.xp = tostring(cur) .. " / " .. tostring(max)
  end
  if GetPetTrainingPoints then
    local total, spent = GetPetTrainingPoints()
    p.trainingPoints = string.format("%s total, %s spent", tostring(total), tostring(spent))
  end
  -- Modern-engine clients have it only as C_PetInfo.GetPetFoodTypes.
  local foodTypes = GetPetFoodTypes or (C_PetInfo and C_PetInfo.GetPetFoodTypes)
  if foodTypes then
    local r = Pack(pcall(foodTypes))
    if r[1] then
      if type(r[2]) == "table" then
        p.diet = Join({ n = #r[2], unpack(r[2]) })
      else
        p.diet = Join({ n = r.n - 1, select(2, unpack(r, 1, r.n)) })
      end
    end
  end
  local stats = {}
  for i, n in ipairs({ "Strength", "Agility", "Stamina", "Intellect", "Spirit" }) do
    local _, eff = UnitStat("pet", i)
    stats[n] = Keep(eff)
  end
  local _, armor = UnitArmor("pet")
  stats.Armor = Keep(armor)
  p.stats = stats
  local ok, book = pcall(Spellbook, true)
  p.spellbook = ok and book or ("error: " .. tostring(book))
  local bar = {}
  for i = 1, 10 do
    local name, _, isToken, isActive, autoAllowed, autoOn = GetPetActionInfo(i)
    if isToken then name = _G[name] end
    if name then
      bar[i] = name .. (autoOn and " (autocast on)" or autoAllowed and " (autocast off)" or "")
        .. (isActive and " (active)" or "")
    end
  end
  p.actionBar = bar
  local okT, talents = pcall(TreeTalents, true)
  p.talents = okT and talents or ("error: " .. tostring(talents))
  return p
end

-- Auras can't be read while they are secret. Then this raises, and Save
-- keeps the previous buff list.
local function Buffs()
  local list = {}
  for i = 1, 40 do
    local name
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
      local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
      if not ok then error("auras are secret right now: " .. tostring(a), 0) end
      name = a and a.name
    elseif UnitBuff then
      name = UnitBuff("player", i)
    end
    if not name then break end
    table.insert(list, name)
  end
  return list
end

local function Reputation()
  local list = {}
  if C_Reputation and C_Reputation.GetFactionDataByIndex then
    for i = 1, C_Reputation.GetNumFactions() do
      local f = C_Reputation.GetFactionDataByIndex(i)
      if f and not f.isHeader then
        table.insert(list, string.format("%s: %s (%d/%d)", f.name, _G["FACTION_STANDING_LABEL" .. f.reaction] or f.reaction,
          (f.currentStanding or 0) - (f.currentReactionThreshold or 0),
          (f.nextReactionThreshold or 0) - (f.currentReactionThreshold or 0)))
      end
    end
  elseif GetNumFactions then
    for i = 1, GetNumFactions() do
      local name, _, standing, barMin, barMax, value, _, _, isHeader = GetFactionInfo(i)
      if name and not isHeader then
        table.insert(list, string.format("%s: %s (%d/%d)", name, _G["FACTION_STANDING_LABEL" .. standing] or standing,
          value - barMin, barMax - barMin))
      end
    end
  end
  return list
end

local function Quests()
  local list = {}
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
      local q = C_QuestLog.GetInfo(i)
      if q and not q.isHeader then
        local done = C_QuestLog.IsComplete and C_QuestLog.IsComplete(q.questID)
        table.insert(list, string.format("[%d] %s%s", q.level or 0, q.title, done and " (complete)" or ""))
      end
    end
  elseif GetNumQuestLogEntries then
    for i = 1, GetNumQuestLogEntries() do
      local title, level, _, isHeader, _, isComplete = GetQuestLogTitle(i)
      if title and not isHeader then
        table.insert(list, string.format("[%d] %s%s", level or 0, title, isComplete == 1 and " (complete)" or ""))
      end
    end
  end
  return list
end

-- Action slots 1-180 plus the Gamepad UI's slots after them (from 181 on this
-- client), with their key, e.g. "Q | spell | 13550 | Serpent Sting".
local SLOT_COMMANDS = {
  { 0, "ACTIONBUTTON" }, { 60, "MULTIACTIONBAR1BUTTON" }, { 48, "MULTIACTIONBAR2BUTTON" },
  { 24, "MULTIACTIONBAR3BUTTON" }, { 36, "MULTIACTIONBAR4BUTTON" },
  -- Bars 6-8 (same offsets as UI.DescribeCommand); unbound keys read nil.
  { 144, "MULTIACTIONBAR5BUTTON" }, { 156, "MULTIACTIONBAR6BUTTON" }, { 168, "MULTIACTIONBAR7BUTTON" },
}
local function Bars()
  local keyFor = {}
  for _, c in ipairs(SLOT_COMMANDS) do
    for i = 1, 12 do keyFor[c[1] + i] = GetBindingKey(c[2] .. i) end
  end
  local last = 180
  if C_GamepadUI and C_GamepadUI.GetFirstGamepadActionStorageSlotIndex then
    local ok, first = pcall(C_GamepadUI.GetFirstGamepadActionStorageSlotIndex)
    local K = Constants and Constants.GamepadActionBarConstants
    local pages = K and K.NUM_STANDARD_PAGES_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT or 3
    if ok and type(first) == "number" and not IsSecret(first) then last = math.max(last, first + pages * 32 - 1) end
  end
  local slots = {}
  for s = 1, last do
    local t, id = GetActionInfo(s)
    if t then
      local name
      if t == "spell" then name = SpellName(id) elseif t == "item" then name = ItemName(id) end
      slots[s] = string.format("%s | %s | %s | %s", keyFor[s] or "-", t, tostring(id),
        name or GetActionText(s) or "?")
    end
  end
  return slots
end

-- Writer ------------------------------------------------------------------------

local SECTIONS = {
  { "basics", Basics }, { "stats", Stats }, { "equipment", Equipment }, { "bags", Bags },
  { "skills", Skills }, { "spellbook", Spellbook }, { "talents", Talents },
  { "talentDebug", TalentDebug }, { "pet", Pet }, { "buffs", Buffs },
  { "reputation", Reputation }, { "quests", Quests }, { "bars", Bars },
}

-- Extension points for SnapshotMore.lua and SnapshotCached.lua -----------------

M.util = { SpellName = SpellName, ItemName = ItemName, LinkName = LinkName, Money = Money,
  Pack = Pack, Join = Join }

function M.CharKey()
  return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

-- A section rebuilt on every save.
function M.AddSection(name, fn) table.insert(SECTIONS, { name, fn }) end

-- A section that can only be read at certain times (bank open, server reply).
-- It is stored with a "seen" time and kept across saves until read again.
local CACHED = {}
function M.SetCached(name, data)
  CACHED[name] = true
  local key = M.CharKey()
  M.db[key] = M.db[key] or {}
  if type(data) == "table" then data.seen = date("%Y-%m-%d %H:%M:%S") end
  M.db[key][name] = data
end
function M.DeclareCached(name) CACHED[name] = true end

-- Several files can listen to the same event.
local handlers = {}
function M.On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    local existing = M.events[event]
    if existing then table.insert(handlers[event], existing) end
    M.events[event] = function(self, ...)
      for _, h in ipairs(handlers[event]) do
        local ok, err = pcall(h, self, ...)
        if not ok then ns.lastSnapshotError = event .. ": " .. tostring(err) end
      end
    end
  end
  table.insert(handlers[event], fn)
end

-- While the game loads or quits, the client reports an empty character
-- (no XP, no spellbook, wrong level). Such a snapshot must not replace a
-- good one.
-- Cheap check, run before building any section.
local function CharacterLoaded()
  if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
    if C_SpellBook.GetNumSpellBookSkillLines() == 0 then return false end
  elseif GetNumSpellTabs and GetNumSpellTabs() == 0 then
    return false
  end
  local maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel() or 60
  return UnitXPMax("player") > 0 or UnitLevel("player") >= maxLevel
end

local function LooksComplete(snap)
  local book = snap.spellbook
  if type(book) ~= "table" or next(book) == nil then return false end
  return CharacterLoaded()
end

-- "<secret>", "<secret> / <secret>", "<secret>, <secret>": nothing readable.
local function SecretOnly(v)
  return type(v) == "string" and v:find("<secret>", 1, true) ~= nil
    and (v:gsub("<secret>", "")):find("^[%s,/]*$") ~= nil
end

-- Puts old values back into fields that are secret now. Returns the field names.
local function KeepOld(new, old, prefix, kept)
  for k, v in pairs(new) do
    local o = old[k]
    if type(v) == "table" and type(o) == "table" then
      KeepOld(v, o, prefix .. tostring(k) .. ".", kept)
    elseif SecretOnly(v) and o ~= nil and type(o) ~= "table" and not SecretOnly(o) then
      new[k] = o
      kept[#kept + 1] = prefix .. tostring(k)
    end
  end
  return kept
end

-- Returns the character key and whether the snapshot was stored.
function M:Save()
  local key = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
  local now = date("%Y-%m-%d %H:%M:%S")
  -- Checked first, so a save during loading or logout costs nothing.
  if not CharacterLoaded() then
    if self.db[key] then self.db[key].skippedIncomplete = now end
    return key, false
  end
  local snap = { time = now }
  for _, s in ipairs(SECTIONS) do
    local ok, result = pcall(s[2])
    snap[s[1]] = ok and result or ("error: " .. tostring(result))
  end
  if not LooksComplete(snap) then
    if self.db[key] then self.db[key].skippedIncomplete = snap.time end
    return key, false
  end
  local old = self.db[key]
  if old then
    -- Secret restrictions hide some values at times. Keep the last readable
    -- ones instead of replacing them with an error or "<secret>".
    for _, s in ipairs(SECTIONS) do
      local name = s[1]
      local new, prev = snap[name], old[name]
      if type(prev) == "table" then
        if type(new) == "string" and new:find("^error: ") then
          prev.staleSince = prev.staleSince or snap.time
          prev.lastError = new
          snap[name] = prev
        elseif type(new) == "table" then
          local kept = KeepOld(new, prev, "", {})
          if #kept > 0 then new.secretKept = kept end
        end
      end
    end
    for name in pairs(CACHED) do snap[name] = old[name] end
  end
  self.db[key] = snap
  return key, true
end

-- Save soon after something changes, at most once per 10 seconds, so the
-- last good snapshot is recent when the game quits. In combat, wait until
-- it ends: many values are secret then.
local pending, afterCombat
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function SaveSoon(self)
  if InCombat() then afterCombat = true; return end
  if pending then return end
  pending = true
  C_Timer.After(10, function()
    pending = false
    if InCombat() then afterCombat = true; return end
    self:Save()
  end)
end

function M:OnEnable()
  ns.db.modules.BarDump = nil -- replaced by this module
  ns.db.enabled.BarDump = nil
end

M.events = {
  PLAYER_ENTERING_WORLD = SaveSoon,
  PLAYER_LEVEL_UP = SaveSoon,
  PLAYER_XP_UPDATE = SaveSoon,
  PLAYER_MONEY = SaveSoon,
  PLAYER_EQUIPMENT_CHANGED = SaveSoon,
  BAG_UPDATE_DELAYED = SaveSoon,
  QUEST_TURNED_IN = SaveSoon,
  SPELLS_CHANGED = SaveSoon,
  TRAIT_CONFIG_UPDATED = SaveSoon,
  SKILL_LINES_CHANGED = SaveSoon,
  UNIT_PET = SaveSoon,
  PLAYER_REGEN_ENABLED = function(self)
    if afterCombat then afterCombat = false; SaveSoon(self) end
  end,
  -- Also fires on /reload. On quit the data is often already gone; Save
  -- then keeps the previous snapshot.
  PLAYER_LOGOUT = function(self) self:Save() end,
}

local function SaveNow()
  local key, stored = M:Save()
  if stored then
    ns.Print("snapshot saved for " .. key .. ". It's written to disk on /reload or logout.")
  else
    ns.Print("character data isn't loaded yet; kept the previous snapshot. Try again in a few seconds.")
  end
end

ns.RegisterAction("Snapshot", "Save now", SaveNow,
  "Save your character state now (written to disk on /reload or logout).")
ns.RegisterCommand("snapshot", "save your character state now (written on /reload)", SaveNow)
