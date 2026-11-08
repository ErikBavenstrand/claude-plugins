-- Macros: a catalog of ready-made macros. The Macros page lists the ones
-- that fit your class; tick the ones you want and press Install.
-- Bodies may hold placeholders, filled in from your character at install:
--   {PETFOOD}      first item in your bags your pet can eat
--   {FISHINGPOLE}  your fishing pole (equipped or in bags)
--   {MAINHAND}     equipped main-hand weapon (not a fishing pole)
--   {OFFHAND?}     equipped off-hand; the "?" drops the line when empty
-- A macro whose required placeholder can't be filled shows why and is skipped.
local _, ns = ...
local UI = ns.UI
local M = ns.RegisterModule("Macros", {
  description = "install ready-made macros from a catalog",
})

-- Names are prefixed "AC " so installed macros are easy to find. Max 16 characters.
-- perCharacter: class macros go in the character tab, utility in the account tab.
M.catalog = {
  { name = "AC Pull", class = "HUNTER", group = "Hunter", icon = "Serpent Sting", perCharacter = true,
    desc = "Send your pet in and cast Serpent Sting.",
    body = "#showtooltip Serpent Sting\n/petattack [@target,harm,nodead]\n/cast [@target,harm,nodead] Serpent Sting" },
  { name = "AC Mark", class = "HUNTER", group = "Hunter", icon = "Hunter's Mark", perCharacter = true,
    desc = "Send your pet in and cast Hunter's Mark.",
    body = "#showtooltip Hunter's Mark\n/petattack [@target,harm,nodead]\n/cast [@target,harm,nodead] Hunter's Mark" },
  { name = "AC Arcane", class = "HUNTER", group = "Hunter", icon = "Arcane Shot", perCharacter = true,
    desc = "Arcane Shot that also starts Auto Shot and sends your pet in.",
    body = "#showtooltip Arcane Shot\n/petattack [@target,harm,nodead]\n/cast !Auto Shot\n/cast Arcane Shot" },
  { name = "AC Pet", class = "HUNTER", group = "Hunter", icon = "Mend Pet", perCharacter = true,
    desc = "Call your pet, revive it if dead, otherwise Mend Pet. Shift forces Revive Pet.",
    body = "#showtooltip\n/cast [mod:shift][@pet,dead] Revive Pet; [nopet] Call Pet; Mend Pet" },
  { name = "AC Feed", class = "HUNTER", group = "Hunter", icon = "Feed Pet", perCharacter = true,
    desc = "Feed your pet the first food in your bags it can eat.",
    body = "#showtooltip Feed Pet\n/cast Feed Pet\n/use {PETFOOD}" },
  { name = "AC Aspect", class = "HUNTER", group = "Hunter", icon = "Aspect of the Hawk", perCharacter = true,
    desc = "Hawk in combat, Cheetah out of combat, Ctrl for Monkey.",
    body = "#showtooltip\n/cast [mod:ctrl] Aspect of the Monkey; [combat] Aspect of the Hawk; Aspect of the Cheetah" },
  { name = "AC Melee", class = "HUNTER", group = "Hunter", icon = "Raptor Strike", perCharacter = true,
    desc = "Mongoose Bite when it's up (after a dodge), otherwise Raptor Strike.",
    body = "#showtooltip Raptor Strike\n/cast Mongoose Bite\n/cast Raptor Strike" },
  { name = "AC Trap", class = "HUNTER", group = "Hunter", icon = "Freezing Trap", perCharacter = true,
    desc = "Stop attacking, call your pet back and lay Freezing Trap.",
    body = "#showtooltip Freezing Trap\n/stopattack\n/petfollow\n/cast Freezing Trap" },
  { name = "AC Growl", class = "HUNTER", group = "Hunter", icon = "Growl", perCharacter = true,
    iconFile = "Ability_Physical_Taunt",
    desc = "Turn your pet's Growl autocast on or off (off in groups, so it doesn't steal threat).",
    body = "/petautocasttoggle Growl" },

  { name = "AC Fish", group = "Fishing and professions", icon = "Fishing",
    desc = "Equip your fishing pole if needed and fish. Shift applies a Shiny Bauble lure.",
    body = "#showtooltip Fishing\n/equip [noequipped:Fishing Poles] {FISHINGPOLE}\n/use [mod:shift] Shiny Bauble\n/use [mod:shift] 16\n/cast [nomod] Fishing" },
  { name = "AC Weapons", group = "Fishing and professions", iconFile = "INV_Sword_04",
    desc = "Swap back to the weapons you have equipped now (run it after fishing).",
    body = "/equip {MAINHAND}\n/equip {OFFHAND?}" },
  { name = "AC Track", group = "Fishing and professions", icon = "Find Minerals",
    desc = "Find Minerals, Shift for Track Humanoids, Ctrl for Track Beasts.",
    body = "#showtooltip\n/cast [mod:shift] Track Humanoids; [mod:ctrl] Track Beasts; Find Minerals" },
  { name = "AC Campfire", group = "Fishing and professions", icon = "Basic Campfire",
    desc = "Light a campfire for cooking.",
    body = "#showtooltip\n/cast Basic Campfire" },

  { name = "AC Sell Grays", group = "Utility", iconFile = "INV_Misc_Coin_02",
    desc = "Sell every grey item in your bags. Click it with a vendor window open.",
    body = "/run for b=0,4 do for s=1,C_Container.GetContainerNumSlots(b) do local i=C_Container.GetContainerItemInfo(b,s) if i and i.quality==0 and not i.hasNoValue then C_Container.UseContainerItem(b,s) end end end" },
  { name = "AC Hearth", group = "Utility", icon = "Hearthstone",
    desc = "Use your Hearthstone, with its cooldown shown on the button.",
    body = "#showtooltip Hearthstone\n/use Hearthstone" },
}

-- Placeholders ------------------------------------------------------------------

local function ItemName(id)
  if C_Item and C_Item.GetItemNameByID then return C_Item.GetItemNameByID(id) end
end

local function SubType(id)
  if C_Item and C_Item.GetItemInfoInstant then return select(3, C_Item.GetItemInfoInstant(id)) end
end

local function BagItemIDs()
  local ids = {}
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local id = C_Container.GetContainerItemID(bag, slot)
      if id then ids[#ids + 1] = id end
    end
  end
  return ids
end

local function IsPole(id) return id and SubType(id) == "Fishing Poles" end

local RESOLVERS = {
  PETFOOD = function()
    if not (C_PetInfo and C_PetInfo.CanPetEatItem) then return nil, "can't check pet food on this client" end
    if not UnitExists("pet") then return nil, "summon your pet first" end
    for _, id in ipairs(BagItemIDs()) do
      local ok, eats = pcall(C_PetInfo.CanPetEatItem, id)
      if ok and eats then return ItemName(id) end
    end
    return nil, "no food your pet eats in your bags"
  end,
  FISHINGPOLE = function()
    local main = GetInventoryItemID("player", 16)
    if IsPole(main) then return ItemName(main) end
    for _, id in ipairs(BagItemIDs()) do
      if IsPole(id) then return ItemName(id) end
    end
    return nil, "no fishing pole equipped or in bags"
  end,
  MAINHAND = function()
    local id = GetInventoryItemID("player", 16)
    if not id then return nil, "no main-hand weapon equipped" end
    if IsPole(id) then return nil, "equip your weapons first, not the fishing pole" end
    return ItemName(id)
  end,
  OFFHAND = function()
    local id = GetInventoryItemID("player", 17)
    return id and ItemName(id) or nil
  end,
}

-- Returns the body with placeholders filled, or nil and the reason.
function M.Resolve(entry)
  local reason
  local lines = {}
  for line in (entry.body .. "\n"):gmatch("(.-)\n") do
    local drop = false
    line = line:gsub("{(%u+)(%??)}", function(key, optional)
      local fn = RESOLVERS[key]
      local value, why
      if fn then value, why = fn() end
      if value then return value end
      if optional == "?" then drop = true else reason = reason or why or ("can't fill " .. key) end
      return ""
    end)
    if not drop then lines[#lines + 1] = line end
  end
  if reason then return nil, reason end
  return table.concat(lines, "\n")
end

function M.Entries()
  local _, class = UnitClass("player")
  local list = {}
  for _, e in ipairs(M.catalog) do
    if not e.class or e.class == class then list[#list + 1] = e end
  end
  return list
end

-- "installed", "different", "missing" plus the macro index.
function M.State(entry)
  local index = GetMacroIndexByName(entry.name)
  if not index or index == 0 then return "missing", 0 end
  local body = M.Resolve(entry)
  local current = GetMacroBody(index) or ""
  if body and current:gsub("%s+$", "") ~= body:gsub("%s+$", "") then return "different", index end
  return "installed", index
end

local function Icon(entry)
  return entry.iconFile or "INV_Misc_QuestionMark"
end

function M.Install(entries)
  if InCombatLockdown() then return ns.Print("can't change macros in combat.") end
  local done, skipped = {}, {}
  for _, e in ipairs(entries) do
    local body, why = M.Resolve(e)
    if not body then
      skipped[#skipped + 1] = e.name .. " (" .. why .. ")"
    else
      local state, index = M.State(e)
      local ok, err
      if index > 0 then
        ok, err = pcall(EditMacro, index, e.name, Icon(e), body)
      else
        ok, err = pcall(CreateMacro, e.name, Icon(e), body, e.perCharacter and true or nil)
      end
      if ok then done[#done + 1] = e.name else skipped[#skipped + 1] = e.name .. " (" .. tostring(err) .. ")" end
    end
  end
  if #done > 0 then ns.Print("installed: " .. table.concat(done, ", ") .. ". Drag them from /macro onto your bars.") end
  if #skipped > 0 then ns.Print("skipped: " .. table.concat(skipped, "; ")) end
  if #done == 0 and #skipped == 0 then ns.Print("tick the macros you want first.") end
end

function M.Remove(entries)
  if InCombatLockdown() then return ns.Print("can't change macros in combat.") end
  local removed = {}
  for _, e in ipairs(entries) do
    local index = GetMacroIndexByName(e.name)
    if index and index > 0 then
      DeleteMacro(index)
      removed[#removed + 1] = e.name
    end
  end
  ns.Print(#removed > 0 and ("removed: " .. table.concat(removed, ", ")) or "none of the ticked macros are installed.")
end

-- Window page ----------------------------------------------------------------------

local ROW_H, WIDTH = 40, 560
local STATE_TEXT = {
  installed = "|cff4cff4cInstalled|r",
  different = "|cffffd100Changed: Install updates it|r",
  missing = "|cff888888Not installed|r",
}

local function DisplayIcon(entry)
  if entry.icon then
    local tex = UI.SpellIcon(entry.icon)
    if tex then return tex end
    if C_Item and C_Item.GetItemInfoInstant then
      local tex2 = select(5, C_Item.GetItemInfoInstant(entry.icon))
      if tex2 then return tex2 end
    end
  end
  return "Interface\\Icons\\" .. Icon(entry)
end

local page = ns.RegisterPage({
  id = "macros",
  title = "Macros",
  icon = "Interface\\Icons\\INV_Misc_Note_01",
  order = 30,

  Build = function(page, f)
    page.checked = {}
    page.rows = {}
    local scroll = CreateFrame("ScrollFrame", "AgentcraftMacroScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -26, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(WIDTH)
    scroll:SetScrollChild(child)

    local y, group = 0, nil
    for _, e in ipairs(M.Entries()) do
      if e.group ~= group then
        group = e.group
        if y < 0 then y = y - 8 end
        UI.Header(child, group, 0, y, WIDTH)
        y = y - 22
      end
      local row = CreateFrame("Button", nil, child)
      row:SetSize(WIDTH, ROW_H - 2)
      row:SetPoint("TOPLEFT", 0, y)
      local hl = row:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 1, 1, 0.05)

      local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
      cb:SetSize(24, 24)
      cb:SetPoint("LEFT", 0, 0)
      cb:SetScript("OnClick", function(self)
        page.checked[e.name] = self:GetChecked() and true or nil
        ns.UI.Refresh()
      end)
      row:SetScript("OnClick", function() cb:Click() end)

      local slot = UI.Slot(row, 30)
      slot:SetPoint("LEFT", 28, 0)
      slot:SetIcon(DisplayIcon(e))
      slot:SetTip({ title = e.name, text = e.body, color = { 0.9, 0.9, 0.9 } })

      local name = UI.Text(row, e.name, "GameFontHighlight")
      name:SetPoint("TOPLEFT", slot, "TOPRIGHT", 8, 0)
      local desc = UI.Text(row, e.desc, "GameFontDisableSmall")
      desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
      desc:SetWidth(330)
      desc:SetJustifyH("LEFT")
      desc:SetWordWrap(false)
      local state = UI.Text(row, "", "GameFontHighlightSmall")
      state:SetPoint("RIGHT", -6, 0)
      state:SetJustifyH("RIGHT")

      page.rows[#page.rows + 1] = { entry = e, cb = cb, state = state }
      y = y - ROW_H
    end
    child:SetHeight(-y + 10)
  end,

  Refresh = function(page)
    for _, r in ipairs(page.rows) do
      local st = M.State(r.entry)
      local text = STATE_TEXT[st]
      if st ~= "installed" then
        local body, why = M.Resolve(r.entry)
        if not body then text = "|cffff5a4aNeeds: " .. why .. "|r" end
      end
      r.state:SetText(text)
      r.cb:SetChecked(page.checked[r.entry.name] or false)
    end
  end,

  Status = function(page)
    local installed, total, selected = 0, #page.rows, 0
    for _, r in ipairs(page.rows) do
      if M.State(r.entry) == "installed" then installed = installed + 1 end
      if page.checked[r.entry.name] then selected = selected + 1 end
    end
    local acct, char = GetNumMacros()
    return string.format("%d of %d installed  ·  %d ticked  ·  macro slots: account %d/%d, character %d/%d",
      installed, total, selected, acct or 0, MAX_ACCOUNT_MACROS or 120, char or 0, MAX_CHARACTER_MACROS or 18)
  end,
})

local function Ticked()
  local list = {}
  for _, r in ipairs(page.rows or {}) do
    if page.checked[r.entry.name] then list[#list + 1] = r.entry end
  end
  return list
end

page.actions = {
  { label = "Tick all", width = 80, tooltip = "Tick every macro that isn't installed yet.", fn = function()
    for _, r in ipairs(page.rows or {}) do
      if M.State(r.entry) ~= "installed" then page.checked[r.entry.name] = true end
    end
  end },
  { label = "Remove", width = 80, tooltip = "Delete the ticked macros.", fn = function()
    M.Remove(Ticked())
    wipe(page.checked)
  end },
  { label = "Install", width = 80, tooltip = "Create or update the ticked macros. Drag them from /macro onto your bars.", fn = function()
    M.Install(Ticked())
    wipe(page.checked)
  end },
}

ns.RegisterCommand("macros", "open the macro catalog", function() ns.OpenPage("macros") end)
