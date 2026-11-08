-- Snapshot sections the game only reveals at certain times. Each is stored
-- with a "seen" time and kept until read again:
--   bank         when the bank is open
--   mail         when the mailbox is open (headers and attachments; the mail
--                text is skipped because reading it marks the mail as read)
--   recipes      per profession, when its window is open
--   flightPaths  known flight points, merged over flight master visits
--   stable       stabled pets, at the stable master
--   auctions     your own auctions, at the auction house
--   playedTime   asked from the server after login
--   lockouts     raid/dungeon saves, asked from the server after login
local _, ns = ...
local M = ns.modules.snapshot
local U = M.util

for _, name in ipairs({ "bank", "mail", "recipes", "flightPaths", "stable", "auctions", "playedTime", "lockouts" }) do
  M.DeclareCached(name)
end

local function Current(name)
  local snap = M.db[M.CharKey()]
  return snap and snap[name]
end

local function Pack(...) return U.Pack(...) end
local function Rest(r) return U.Join({ n = r.n - 1, select(2, unpack(r, 1, r.n)) }) end

-- Items in one container: { "Name xN", ... }.
local function ContainerItems(bag)
  local n = C_Container.GetContainerNumSlots(bag) or 0
  if n == 0 then return nil end
  local counts, order = {}, {}
  for slot = 1, n do
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info and info.itemID then
      local name = info.itemName or U.LinkName(info.hyperlink) or tostring(info.itemID)
      if not counts[name] then order[#order + 1] = name end
      counts[name] = (counts[name] or 0) + (info.stackCount or 1)
    end
  end
  local list = {}
  for _, name in ipairs(order) do list[#list + 1] = name .. " x" .. counts[name] end
  return { slots = n, items = list }
end

-- Bank -------------------------------------------------------------------------

local bankOpen = false

local function ScanBank()
  if not bankOpen then return end
  local out = { containers = {} }
  -- Bank container IDs differ between game versions, so try every known one.
  local ids = { -1 }
  if Enum and Enum.BagIndex then
    for k, v in pairs(Enum.BagIndex) do
      if type(k) == "string" and (k:find("Bank") or k == "Bank") and type(v) == "number" then ids[#ids + 1] = v end
    end
  end
  for id = (NUM_BAG_SLOTS or 4) + 1, (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 7) do ids[#ids + 1] = id end
  local seen = {}
  for _, id in ipairs(ids) do
    if not seen[id] then
      seen[id] = true
      local ok, c = pcall(ContainerItems, id)
      if ok and c and #c.items > 0 then out.containers["container " .. id] = c end
    end
  end
  M.SetCached("bank", out)
end

local function BankShown(interaction)
  local banker = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.Banker
  if interaction == nil or interaction == banker then
    bankOpen = true
    C_Timer.After(0.5, ScanBank)
  end
end

M.On("BANKFRAME_OPENED", function() BankShown(nil) end)
M.On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, t) BankShown(t) end)
M.On("BANKFRAME_CLOSED", function() bankOpen = false end)
M.On("PLAYERBANKSLOTS_CHANGED", function() C_Timer.After(0.5, ScanBank) end)

-- Mail -------------------------------------------------------------------------

local function ScanMail()
  if not GetInboxNumItems then return end
  local list = {}
  for i = 1, GetInboxNumItems() do
    local _, _, sender, subject, money, cod, daysLeft, hasItem, wasRead, wasReturned = GetInboxHeaderInfo(i)
    local items = {}
    if hasItem then
      for a = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
        local name, _, _, count = GetInboxItem(i, a)
        if name then items[#items + 1] = name .. " x" .. (count or 1) end
      end
    end
    list[#list + 1] = {
      from = sender, subject = subject, money = (money or 0) > 0 and U.Money(money) or nil,
      cod = (cod or 0) > 0 and U.Money(cod) or nil, daysLeft = daysLeft and math.floor(daysLeft * 10) / 10,
      read = wasRead or nil, returned = wasReturned or nil, items = #items > 0 and items or nil,
    }
  end
  M.SetCached("mail", { count = #list, messages = list })
end

M.On("MAIL_INBOX_UPDATE", function() C_Timer.After(0.3, ScanMail) end)

-- Recipes ----------------------------------------------------------------------

local function ScanModernRecipes()
  local T = C_TradeSkillUI
  if not (T and T.GetAllRecipeIDs) then return false end
  local ids = T.GetAllRecipeIDs()
  if not ids or #ids == 0 then return false end
  local prof = T.GetBaseProfessionInfo and T.GetBaseProfessionInfo()
  local profName = (prof and prof.professionName) or (T.GetTradeSkillLine and T.GetTradeSkillLine()) or "Profession"
  local list = {}
  for _, id in ipairs(ids) do
    local r = T.GetRecipeInfo(id)
    if r and r.learned then
      local reagents
      if T.GetRecipeSchematic then
        local ok, s = pcall(T.GetRecipeSchematic, id, false)
        if ok and s and s.reagentSlotSchematics then
          reagents = {}
          for _, slot in ipairs(s.reagentSlotSchematics) do
            local first = slot.reagents and slot.reagents[1]
            local itemName = first and first.itemID and U.ItemName(first.itemID)
            if itemName then reagents[#reagents + 1] = itemName .. " x" .. (slot.quantityRequired or 1) end
          end
        end
      end
      list[#list + 1] = { name = r.name, recipeID = id, canMake = r.numAvailable, reagents = reagents }
    end
  end
  return profName, list
end

-- Classic trade skill and craft windows (Enchanting and Beast Training use "craft").
local function ScanClassicRecipes(kind)
  local num = kind == "craft" and GetNumCrafts or GetNumTradeSkills
  if not num then return false end
  local profName = kind == "craft" and GetCraftDisplaySkillLine and GetCraftDisplaySkillLine()
    or (GetTradeSkillLine and GetTradeSkillLine()) or "Profession"
  local list = {}
  for i = 1, num() do
    local name, kindOrType, available
    if kind == "craft" then
      name, _, kindOrType, available = GetCraftInfo(i)
    else
      name, kindOrType, available = GetTradeSkillInfo(i)
    end
    if name and kindOrType ~= "header" then
      local reagents = {}
      local numR = kind == "craft" and GetCraftNumReagents(i) or GetTradeSkillNumReagents(i)
      for r = 1, numR or 0 do
        local rName, _, rCount
        if kind == "craft" then rName, _, rCount = GetCraftReagentInfo(i, r) else rName, _, rCount = GetTradeSkillReagentInfo(i, r) end
        if rName then reagents[#reagents + 1] = rName .. " x" .. (rCount or 1) end
      end
      list[#list + 1] = { name = name, canMake = available, reagents = reagents }
    end
  end
  return profName, list
end

local function ScanRecipes(kind)
  local profName, list = ScanModernRecipes()
  if not profName then profName, list = ScanClassicRecipes(kind) end
  if not profName or not list or #list == 0 then return end
  local all = Current("recipes") or {}
  all.seen = nil
  all[profName] = { seen = date("%Y-%m-%d %H:%M:%S"), count = #list, recipes = list }
  M.SetCached("recipes", all)
end

for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_UPDATE" }) do
  M.On(ev, function() C_Timer.After(0.5, function() ScanRecipes("trade") end) end)
end
for _, ev in ipairs({ "CRAFT_SHOW", "CRAFT_UPDATE" }) do
  M.On(ev, function() C_Timer.After(0.5, function() ScanRecipes("craft") end) end)
end

-- Flight paths -----------------------------------------------------------------

local function ScanTaxi()
  local known = (Current("flightPaths") or {}).known or {}
  local found = 0
  if C_TaxiMap and C_TaxiMap.GetAllTaxiNodes then
    local mapID = GetTaxiMapID and GetTaxiMapID() or (C_Map and C_Map.GetBestMapForUnit("player"))
    local ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, mapID)
    if ok and nodes then
      for _, node in ipairs(nodes) do
        -- state: 0 current, 1 reachable (known), 2 unreachable (not learned)
        if node.name and node.state ~= 2 then known[node.name] = true; found = found + 1 end
      end
    end
  end
  if found == 0 and NumTaxiNodes then
    for i = 1, NumTaxiNodes() do
      local t = TaxiNodeGetType(i)
      if t == "REACHABLE" or t == "CURRENT" then known[TaxiNodeName(i)] = true; found = found + 1 end
    end
  end
  if found > 0 then
    local list = {}
    for name in pairs(known) do list[#list + 1] = name end
    table.sort(list)
    M.SetCached("flightPaths", { known = known, list = list })
  end
end

M.On("TAXIMAP_OPENED", function() C_Timer.After(0.3, ScanTaxi) end)

-- Stable -----------------------------------------------------------------------

local function ScanStable()
  local list = {}
  for i = 1, 25 do
    local entry
    if C_StableInfo and C_StableInfo.GetStablePetInfo then
      local ok, info = pcall(C_StableInfo.GetStablePetInfo, i)
      if ok and type(info) == "table" and info.name then
        entry = string.format("slot %d: %s, level %s %s", i, info.name, tostring(info.level),
          tostring(info.familyName or info.type or ""))
      end
    elseif GetStablePetInfo then
      local _, name, level, family = GetStablePetInfo(i)
      if name then entry = string.format("slot %d: %s, level %s %s", i, name, tostring(level), tostring(family)) end
    end
    if entry then list[#list + 1] = entry end
  end
  M.SetCached("stable", { pets = list })
end

M.On("PET_STABLE_SHOW", function() C_Timer.After(0.5, ScanStable) end)
M.On("PET_STABLE_UPDATE", function() C_Timer.After(0.5, ScanStable) end)

-- Auctions ---------------------------------------------------------------------

local function ScanAuctions()
  local list = {}
  if C_AuctionHouse and C_AuctionHouse.GetNumOwnedAuctions then
    for i = 1, C_AuctionHouse.GetNumOwnedAuctions() do
      local a = C_AuctionHouse.GetOwnedAuctionInfo(i)
      if a and a.itemKey then
        local name = U.ItemName(a.itemKey.itemID) or tostring(a.itemKey.itemID)
        list[#list + 1] = string.format("%s x%s, buyout %s, %s", name, tostring(a.quantity),
          a.buyoutAmount and U.Money(a.buyoutAmount) or "none", a.status == 1 and "sold" or "active")
      end
    end
  end
  if #list == 0 and GetNumAuctionItems then
    for i = 1, GetNumAuctionItems("owner") do
      local name, _, count, _, _, _, _, minBid, _, buyout, bidAmount = GetAuctionItemInfo("owner", i)
      if name then
        list[#list + 1] = string.format("%s x%s, bid %s, buyout %s%s", name, tostring(count), U.Money(minBid),
          (buyout or 0) > 0 and U.Money(buyout) or "none", (bidAmount or 0) > 0 and " (has bid)" or "")
      end
    end
  end
  M.SetCached("auctions", { count = #list, auctions = list })
end

for _, ev in ipairs({ "AUCTION_OWNED_LIST_UPDATE", "OWNED_AUCTIONS_UPDATED" }) do
  M.On(ev, function() C_Timer.After(0.5, ScanAuctions) end)
end
M.On("AUCTION_HOUSE_SHOW", function()
  if C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions then pcall(C_AuctionHouse.QueryOwnedAuctions, {}) end
  C_Timer.After(1.5, ScanAuctions)
end)

-- Played time and lockouts (asked from the server after login) -----------------

local askedPlayed, quietPlayed = false, false

M.On("TIME_PLAYED_MSG", function(_, total, thisLevel)
  local function Fmt(sec)
    sec = tonumber(sec) or 0
    return string.format("%dd %dh %dm", math.floor(sec / 86400), math.floor(sec / 3600) % 24, math.floor(sec / 60) % 60)
  end
  M.SetCached("playedTime", { total = Fmt(total), thisLevel = Fmt(thisLevel), totalSeconds = total })
end)

M.On("UPDATE_INSTANCE_INFO", function()
  if not GetNumSavedInstances then return end
  local list = {}
  for i = 1, GetNumSavedInstances() do
    local name, _, reset, _, locked, _, _, isRaid, maxPlayers, difficultyName, numEncounters, progress = GetSavedInstanceInfo(i)
    if name and locked then
      list[#list + 1] = string.format("%s (%s%s): %s/%s bosses, resets in %dh", name, tostring(difficultyName),
        isRaid and ", raid" or "", tostring(progress), tostring(numEncounters), math.floor((reset or 0) / 3600))
    end
  end
  M.SetCached("lockouts", { instances = list })
end)

M.On("PLAYER_ENTERING_WORLD", function()
  if askedPlayed then return end
  askedPlayed = true
  C_Timer.After(8, function()
    if RequestRaidInfo then RequestRaidInfo() end
    if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
    if RequestTimePlayed then
      -- Hide the "Total time played" chat lines for this one request.
      local orig = ChatFrame_DisplayTimePlayed
      if orig then
        quietPlayed = true
        ChatFrame_DisplayTimePlayed = function(...)
          if quietPlayed then quietPlayed = false; ChatFrame_DisplayTimePlayed = orig; return end
          return orig(...)
        end
      end
      RequestTimePlayed()
    end
  end)
end)
