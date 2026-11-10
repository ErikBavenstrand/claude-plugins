-- Snapshot sections that can be read at any time, rebuilt on every save:
-- gear and bag detail with tooltips, quest objectives and history, combat
-- stats, macros, currencies and PvP, collections, social, addons and an API
-- probe. Each call is guarded, because game versions differ in what exists.
local _, ns = ...
local M = ns.modules.snapshot
local U = M.util

-- Run fn with pcall and return its results joined as text, or nil.
local function Try(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = U.Pack(pcall(fn, ...))
  if not r[1] then return nil end
  return U.Join({ n = r.n - 1, select(2, unpack(r, 1, r.n)) })
end

-- Plain fields of a table (drops nested tables and functions).
local function Flat(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do
    local tv = type(v)
    if tv == "string" or tv == "number" or tv == "boolean" then out[k] = v end
  end
  return out
end

-- Tooltip text as a list of lines ("left  |  right").
local function TooltipLines(data)
  if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
  local out = {}
  for _, l in ipairs(data.lines) do
    local left, right = l.leftText, l.rightText
    if type(left) == "string" and left ~= "" then
      if type(right) == "string" and right ~= "" then left = left .. "  |  " .. right end
      out[#out + 1] = left
    end
  end
  return out
end

local function Tip(method, ...)
  if not (C_TooltipInfo and C_TooltipInfo[method]) then return nil end
  local ok, data = pcall(C_TooltipInfo[method], ...)
  if ok then return TooltipLines(data) end
end

-- item:ID:enchant:gem1:gem2:gem3:gem4:suffix:...
local function ParseLink(link)
  if not link then return {} end
  local id, enchant, g1, g2, g3, g4, suffix = link:match("item:(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*)")
  local function n(v) v = tonumber(v); return (v and v ~= 0) and v or nil end
  return { id = n(id), enchantID = n(enchant), suffixID = n(suffix),
    gems = (n(g1) or n(g2) or n(g3) or n(g4)) and { n(g1), n(g2), n(g3), n(g4) } or nil }
end

local QUALITY = { [0] = "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact", "Heirloom" }

local SLOT_NAMES = { "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist",
  "Hands", "Finger 1", "Finger 2", "Trinket 1", "Trinket 2", "Back", "Main hand", "Off hand",
  "Ranged", "Tabard" }

-- Gear: every equipped item with enchant, random suffix and full tooltip.
M.AddSection("gear", function()
  local out = {}
  for slot = 1, 19 do
    local link = GetInventoryItemLink("player", slot)
    if link then
      local p = ParseLink(link)
      local cur, max = GetInventoryItemDurability(slot)
      out[SLOT_NAMES[slot]] = {
        name = U.LinkName(link), itemID = p.id, enchantID = p.enchantID, suffixID = p.suffixID, gems = p.gems,
        quality = QUALITY[GetInventoryItemQuality("player", slot) or -1],
        durability = cur and (cur .. "/" .. max) or nil,
        tooltip = Tip("GetInventoryItem", "player", slot),
      }
    end
  end
  return out
end)

-- Bag items: one entry per item type with total count, quality and tooltip.
M.AddSection("bagItems", function()
  local byID, order = {}, {}
  for bag = 0, NUM_BAG_SLOTS or 4 do
    local n = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, n do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then
        local e = byID[info.itemID]
        if not e then
          e = { name = info.itemName or U.LinkName(info.hyperlink), itemID = info.itemID, count = 0,
            quality = QUALITY[info.quality or -1], soulbound = info.isBound or nil,
            tooltip = Tip("GetBagItem", bag, slot) }
          byID[info.itemID] = e
          order[#order + 1] = e
        end
        e.count = e.count + (info.stackCount or 1)
      end
    end
  end
  local bags = {}
  for i = 1, NUM_BAG_SLOTS or 4 do
    local inv = C_Container.ContainerIDToInventoryID and C_Container.ContainerIDToInventoryID(i)
    local link = inv and GetInventoryItemLink("player", inv)
    if link then bags[#bags + 1] = U.LinkName(link) .. " (" .. (C_Container.GetContainerNumSlots(i) or 0) .. " slots)" end
  end
  table.sort(order, function(a, b) return (a.name or "") < (b.name or "") end)
  return { equippedBags = bags, items = order }
end)

-- Quests with objectives and progress, grouped under their zone header.
M.AddSection("questLog", function()
  local out = {}
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return out end
  local header = "?"
  for i = 1, C_QuestLog.GetNumQuestLogEntries() do
    local q = C_QuestLog.GetInfo(i)
    if q and q.isHeader then
      header = q.title
    elseif q and q.questID then
      local objectives = {}
      local objs = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(q.questID)
      for _, o in ipairs(objs or {}) do
        objectives[#objectives + 1] = (o.text or "?") .. (o.finished and " (done)" or "")
      end
      out[#out + 1] = {
        questID = q.questID, title = q.title, level = q.level, zone = header,
        complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(q.questID) or nil,
        failed = q.isFailed or nil, suggestedGroup = (q.suggestedGroup or 0) > 0 and q.suggestedGroup or nil,
        objectives = objectives,
      }
    end
  end
  return out
end)

-- Every quest this character has turned in (IDs; look names up on Wowhead).
M.AddSection("completedQuests", function()
  local ids = C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs and C_QuestLog.GetAllCompletedQuestIDs()
  if not ids then return nil end
  return { count = #ids, ids = table.concat(ids, ",") }
end)

-- Combat stats beyond the basics. Missing functions are skipped.
M.AddSection("combatStats", function()
  local s = {}
  local function Put(label, fn, ...) s[label] = Try(fn, ...) end
  Put("Melee crit %", GetCritChance)
  Put("Ranged crit %", GetRangedCritChance)
  Put("Spell crit % (holy..arcane)", function()
    local t = {}
    for school = 2, 7 do t[#t + 1] = string.format("%.2f", GetSpellCritChance(school)) end
    return table.concat(t, " ")
  end)
  Put("Hit bonus %", GetHitModifier)
  Put("Spell hit bonus %", GetSpellHitModifier)
  Put("Melee haste %", GetMeleeHaste)
  Put("Ranged haste %", GetRangedHaste)
  Put("Spell haste %", UnitSpellHaste, "player")
  Put("Dodge %", GetDodgeChance)
  Put("Parry %", GetParryChance)
  Put("Block %", GetBlockChance)
  Put("Defense (base, bonus)", UnitDefense, "player")
  Put("Expertise", GetExpertise)
  Put("Melee speed (main, off)", UnitAttackSpeed, "player")
  Put("Melee damage (min, max, offMin, offMax, bonusPos, bonusNeg, pct)", UnitDamage, "player")
  Put("Ranged (speed, min, max, bonusPos, bonusNeg, pct)", UnitRangedDamage, "player")
  Put("Spell bonus damage (holy..arcane)", function()
    local t = {}
    for school = 2, 7 do t[#t + 1] = tostring(GetSpellBonusDamage(school)) end
    return table.concat(t, " ")
  end)
  Put("Spell bonus healing", GetSpellBonusHealing)
  Put("Mana regen (base, casting)", GetManaRegen)
  local res = {}
  for i, name in ipairs({ "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane" }) do
    local v = Try(UnitResistance, "player", i)
    if v then res[name] = v end
  end
  s.Resistances = res
  return s
end)

-- Macros, with their text.
M.AddSection("macros", function()
  if not GetNumMacros then return nil end
  local numGlobal, numChar = GetNumMacros()
  local base = MAX_ACCOUNT_MACROS or 120
  local function Read(i)
    local name, icon, body = GetMacroInfo(i)
    if name then return { name = name, body = body } end
  end
  local out = { account = {}, character = {} }
  for i = 1, numGlobal or 0 do out.account[#out.account + 1] = Read(i) end
  for i = base + 1, base + (numChar or 0) do out.character[#out.character + 1] = Read(i) end
  return out
end)

-- Currencies, honor and lifetime PvP stats.
M.AddSection("currencyPvp", function()
  local out = {}
  if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize then
    local list = {}
    for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
      local c = C_CurrencyInfo.GetCurrencyListInfo(i)
      if c and not c.isHeader and c.name then list[#list + 1] = c.name .. ": " .. tostring(c.quantity) end
    end
    out.currencies = list
  end
  out.honor = Try(UnitHonor, "player")
  out["lifetime PvP (honorable kills, dishonorable kills, highest rank)"] = Try(GetPVPLifetimeStats)
  out["PvP rank"] = Try(UnitPVPRank, "player")
  return out
end)

-- Mounts, companions and equipment sets.
M.AddSection("collections", function()
  local out = {}
  if GetNumCompanions then
    for _, kind in ipairs({ "MOUNT", "CRITTER" }) do
      local list = {}
      for i = 1, (GetNumCompanions(kind) or 0) do
        local _, name = GetCompanionInfo(kind, i)
        if name then list[#list + 1] = name end
      end
      out[kind == "MOUNT" and "mounts" or "companions"] = list
    end
  end
  if C_MountJournal and C_MountJournal.GetMountIDs and (not out.mounts or #out.mounts == 0) then
    local list = {}
    for _, id in ipairs(C_MountJournal.GetMountIDs() or {}) do
      local name, _, _, _, _, _, _, _, _, _, collected = C_MountJournal.GetMountInfoByID(id)
      if collected then list[#list + 1] = name end
    end
    out.mounts = list
  end
  if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs then
    local sets = {}
    for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs() or {}) do
      sets[#sets + 1] = (C_EquipmentSet.GetEquipmentSetInfo(id))
    end
    out.equipmentSets = sets
  end
  return out
end)

-- Friends, guild roster and current group.
M.AddSection("social", function()
  local out = {}
  if C_FriendList and C_FriendList.GetNumFriends then
    local list = {}
    for i = 1, C_FriendList.GetNumFriends() or 0 do
      local f = C_FriendList.GetFriendInfoByIndex(i)
      if f then
        list[#list + 1] = string.format("%s, level %s %s, %s%s", tostring(f.name), tostring(f.level),
          tostring(f.className), tostring(f.area), f.connected and " (online)" or "")
      end
    end
    out.friends = list
  end
  if IsInGuild and IsInGuild() and GetNumGuildMembers then
    local list = {}
    local total = GetNumGuildMembers()
    for i = 1, math.min(total or 0, 500) do
      local name, rank, _, level, class, zone, _, _, online = GetGuildRosterInfo(i)
      if name then
        list[#list + 1] = string.format("%s, %s, level %s %s%s", name, tostring(rank), tostring(level),
          tostring(class), online and (" (online in " .. tostring(zone) .. ")") or "")
      end
    end
    out.guild = { name = GetGuildInfo("player"), members = total, roster = list }
  end
  local group = {}
  local raid = IsInRaid and IsInRaid()
  for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
    local unit = raid and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
    if UnitExists(unit) then
      group[#group + 1] = string.format("%s, level %s %s", tostring(UnitName(unit)), tostring(UnitLevel(unit)),
        tostring(select(2, UnitClass(unit))))
    end
  end
  out.group = group
  return out
end)

-- Installed addons and whether they are loaded.
M.AddSection("addons", function()
  local A = C_AddOns
  if not (A and A.GetNumAddOns) then return nil end
  local list = {}
  for i = 1, A.GetNumAddOns() do
    local name, title, _, loadable = A.GetAddOnInfo(i)
    local version = A.GetAddOnMetadata and A.GetAddOnMetadata(i, "Version")
    list[#list + 1] = string.format("%s%s%s", name, version and (" " .. version) or "",
      A.IsAddOnLoaded(i) and "" or (loadable and " (not loaded)" or " (disabled)"))
  end
  return list
end)

-- Controller: whether controller mode is on, the connected pad, its settings
-- and every binding on a pad button. Default controller bindings are never
-- written to bindings-cache.wtf until changed, so only the game knows them.
M.AddSection("controller", function()
  local out = { settings = {}, bindings = {} }
  local G = C_GamePad
  if G then
    out.enabled = Try(G.IsEnabled)
    local id = G.GetActiveDeviceID and G.GetActiveDeviceID()
    out.activeDeviceID = id
    if id and G.GetDeviceMappedState then
      local ok, st = pcall(G.GetDeviceMappedState, id)
      if ok and type(st) == "table" then out.device = Flat(st) end
    end
  end
  for _, cv in ipairs({ "GamePadEnable", "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt",
      "GamePadEmulateEsc", "GamePadCursorLeftClick", "GamePadCursorRightClick", "GamePadCursorAutoEnable",
      "GamePadCameraYawSpeed", "GamePadCameraPitchSpeed", "GamePadFaceMovementMaxAngle", "GamePadTouchCursorEnable",
      "GamePadVibrationStrength", "SoftTargetEnemy", "SoftTargetFriend", "SoftTargetInteract" }) do
    local ok, v = pcall(C_CVar.GetCVar, cv)
    if ok and v then out.settings[cv] = v end
  end
  local function Label(command)
    local label = _G["BINDING_NAME_" .. command] or command
    local d = ns.UI and ns.UI.DescribeCommand and ns.UI.DescribeCommand(command)
    if d and d.kind ~= "other" and d.name then label = label .. " -> " .. d.name end
    return label
  end
  local function IsPad(key) return key:find("PAD") and not key:find("NUMPAD") end

  -- Saved bindings: GetBinding(i) returns command, category, key1, key2, ...
  for i = 1, GetNumBindings() do
    local r = { GetBinding(i) }
    for k = 3, #r do
      local key = r[k]
      if type(key) == "string" and IsPad(key) then out.bindings[key] = Label(r[1]) end
    end
  end

  -- The controller UI binds buttons with override bindings, which GetBinding
  -- doesn't list. Ask what every pad button (with each modifier) does now.
  local buttons = { "PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6", "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",
    "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER", "PADLSTICK", "PADRSTICK", "PADBACK",
    "PADFORWARD", "PADSOCIAL", "PADSYSTEM", "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4",
    "PADLSTICKUP", "PADLSTICKDOWN", "PADLSTICKLEFT", "PADLSTICKRIGHT",
    "PADRSTICKUP", "PADRSTICKDOWN", "PADRSTICKLEFT", "PADRSTICKRIGHT" }
  local mods = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-" }
  out.current = {}
  for _, m in ipairs(mods) do
    for _, b in ipairs(buttons) do
      local key = m .. b
      local ok, action = pcall(GetBindingAction, key, true)
      if ok and action and action ~= "" then out.current[key] = Label(action) end
    end
  end
  out.note = "current = what each button does right now, including the controller UI's override bindings"

  -- Steam Deck back buttons arrive as F13-F16 (plain and with LT = Shift).
  out.backButtons = {}
  for _, b in ipairs({ "F13", "F14", "F15", "F16" }) do
    for _, m in ipairs({ "", "SHIFT-" }) do
      local ok, action = pcall(GetBindingAction, m .. b, true)
      if ok and action and action ~= "" then out.backButtons[m .. b] = action end
    end
  end

  -- The controller UI routes buttons to click frames. Describe those frames
  -- and every action button whose hotkey shows a controller glyph, so the
  -- button -> action slot -> spell chain can be followed.
  local function FrameInfo(f)
    local info = { frame = f:GetName(), parent = f:GetParent() and f:GetParent():GetName(), shown = f:IsShown() or nil }
    for _, a in ipairs({ "type", "action", "spell", "macro", "item", "clickbutton", "function", "binding", "actionpage" }) do
      local ok, v = pcall(f.GetAttribute, f, a)
      if ok and v ~= nil then
        info[a] = (type(v) == "table" and v.GetName and (v:GetName() or "unnamed frame")) or tostring(v)
      end
    end
    local slot = f.action
    if not slot and f.CalculateAction then
      local ok, v = pcall(f.CalculateAction, f)
      if ok then slot = v end
    end
    if type(slot) == "number" and slot > 0 then
      info.slot = slot
      local d = ns.UI and ns.UI.DescribeSlot and ns.UI.DescribeSlot(slot)
      info.slotHolds = d and d.name
    end
    if f.HotKey and f.HotKey.GetText then info.hotkey = f.HotKey:GetText() end
    return info
  end

  -- Controller action bars (Blizzard_GamepadActionBars). Each page has four
  -- bars (Top, Left = left shoulder/trigger, Right = right shoulder/trigger,
  -- Bottom), each with a D-pad diamond and a face-button diamond: 32
  -- positions numbered as in ActionBindingUtil.lua. Actions live in
  -- dedicated action slots that Blizzard's util maps from page + position.
  local Util = GamepadActionBarBindingUtil
  local K = Constants and Constants.GamepadActionBarConstants
  if Util and Util.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID and C_GamepadUI then
    local BARS = { "Top", "Left", "Right", "Bottom" }
    local DPAD = { "D-pad left", "D-pad up", "D-pad right", "D-pad down" }
    local FACE = { "X/Square (face left)", "Y/Triangle (face up)", "B/Circle (face right)", "A/Cross (face down)" }
    local pages = {}
    for page = 1, (K and K.NUM_STANDARD_PAGES_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT) or 3 do
      local p = {}
      for id = 1, 32 do
        local bar = BARS[math.floor((id - 1) / 8) + 1]
        local inBar = (id - 1) % 8
        local button = (inBar < 4 and DPAD or FACE)[(inBar % 4) + 1]
        local label = string.format("%s bar: %s", bar, button)
        if Util.IsReservedPageUnitSlotID and Util.IsReservedPageUnitSlotID(id) then
          if page == 1 then p[label] = "fixed by the controller UI" end
        else
          local ok, index = pcall(Util.GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID, page, id)
          if ok and index then
            local d = ns.UI and ns.UI.DescribeSlot and ns.UI.DescribeSlot(index)
            if d and d.name and d.name ~= "Empty slot" then p[label] = d.name .. " (action slot " .. index .. ")" end
          end
        end
      end
      pages["page " .. page] = p
    end
    out.gamepadBars = pages
    out.gamepadFirstActionSlot = Try(C_GamepadUI.GetFirstGamepadActionStorageSlotIndex)
  else
    out.gamepadBars = "controller action bars not loaded (turn on the Gamepad UI)"
  end

  out.clickTargets = {}
  for key, label in pairs(out.current) do
    local name = label:match("^CLICK ([^:]+):")
    local f = name and _G[name]
    if f and not out.clickTargets[name] then out.clickTargets[name] = FrameInfo(f) end
  end

  out.padButtons = {}
  local f = EnumerateFrames()
  local scanned = 0
  while f and scanned < 20000 do
    scanned = scanned + 1
    if f.HotKey and f.HotKey.GetText and (f.action or f.CalculateAction) then
      local ok, text = pcall(f.HotKey.GetText, f.HotKey)
      if ok and type(text) == "string" and (text:find("|A") or text:find("|T") or text:find("PAD")) then
        if #out.padButtons < 120 then out.padButtons[#out.padButtons + 1] = FrameInfo(f) end
      end
    end
    f = EnumerateFrames(f)
  end
  return out
end)

-- Which APIs this client has and what is hidden from addons. Answers
-- "can Agentcraft read X on this game version?".
M.AddSection("apiProbe", function()
  local out = { functions = {} }
  local names = {
    "GetSkillLineInfo", "GetPetHappiness", "GetPetLoyalty", "GetPVPRankInfo", "GetStablePetInfo",
    "GetNumTradeSkills", "GetNumCrafts", "GetTalentInfo", "GetNumAuctionItems", "GetAuctionItemInfo",
    "NumTaxiNodes", "GetAchievementInfo", "RequestTimePlayed", "RequestRaidInfo", "GetSavedInstanceInfo",
    "issecretvalue", "canaccessvalue", "UnitHealthPercent", "UnitPowerPercent",
    "C_SkillInfo", "C_PetInfo", "C_StableInfo", "C_TradeSkillUI", "C_TaxiMap", "C_AuctionHouse",
    "C_TooltipInfo", "C_Secrets", "C_CurrencyInfo", "C_MountJournal", "C_EquipmentSet", "C_Bank",
  }
  for _, n in ipairs(names) do out.functions[n] = type(_G[n]) end
  if issecretvalue then out["player health is secret"] = Try(function() return issecretvalue(UnitHealth("player")) end) end
  if C_Secrets and C_Secrets.HasSecretRestrictions then out["secret restrictions active"] = Try(C_Secrets.HasSecretRestrictions) end
  out["health %"] = Try(UnitHealthPercent, "player")
  out["power %"] = Try(UnitPowerPercent, "player")
  if C_PetInfo then
    local fns = {}
    for k, v in pairs(C_PetInfo) do if type(v) == "function" then fns[#fns + 1] = k end end
    table.sort(fns)
    out["C_PetInfo functions"] = table.concat(fns, ", ")
  end
  out.lastHandlerError = ns.lastSnapshotError
  return out
end)
