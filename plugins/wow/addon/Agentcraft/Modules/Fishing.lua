-- Fishing: backs the "Fish" macro, which names equipment sets instead of
-- items so its text never changes.
--   * Keeps two sets in the game's equipment manager: "Fishing" (the pole,
--     main hand only) and "Weapons" (main and off hand). Each is saved when
--     you equip that gear, so a new pole or weapon is picked up by itself.
--   * First login with a pole in your bags and no "Fishing" set: equips the
--     pole for a moment to save the set, then puts your weapons back.
--   * With the pole equipped, 15 seconds after your last cast (out of combat,
--     not channelling, no loot window) or as soon as you mount, your weapons
--     are equipped again. In combat addons can't change gear; the macro does.
--   * Warns with a raid-warning style message and sound when the lure runs out.
local _, ns = ...
local M = ns.RegisterModule("Fishing", {
  description = "equipment sets for the Fish macro, weapon swap, lure warnings",
  charDefaults = { idleSeconds = 15 },
})

local FISHING_SET, WEAPONS_SET = "Fishing", "Weapons"
local lastCast = 0
local ticker
local lureOn -- nil until we've seen the pole, then true/false
local settingUp

local function IsPole(id) return ns.MacroLibrary and ns.MacroLibrary.IsPole(id) end
local function PoleEquipped() return IsPole(GetInventoryItemID("player", 16)) end

local function Equip(id, slot)
  if not id then return end
  if C_Item and C_Item.EquipItemByName then C_Item.EquipItemByName(id, slot) else EquipItemByName(id, slot) end
end

-- Saves what you wear in the given slots as an equipment set, only when it
-- differs from what the set already holds.
local function SaveSet(name, slots)
  local ES = C_EquipmentSet
  if not ES or InCombatLockdown() then return end
  local id = ES.GetEquipmentSetID(name)
  if id then
    local items = ES.GetItemIDs(id) or {}
    local same = true
    for _, s in ipairs(slots) do
      if items[s] ~= GetInventoryItemID("player", s) then same = false end
    end
    if same then return end
  end
  local keep = {}
  for _, s in ipairs(slots) do keep[s] = true end
  ES.ClearIgnoredSlotsForSave()
  for s = 1, 19 do if not keep[s] then ES.IgnoreSlotForSave(s) end end
  if id then pcall(ES.SaveEquipmentSet, id) else pcall(ES.CreateEquipmentSet, name) end
  ES.ClearIgnoredSlotsForSave()
end

local function RememberGear()
  local main = GetInventoryItemID("player", 16)
  if not main then return end
  if IsPole(main) then
    SaveSet(FISHING_SET, { 16 })
  else
    ns.charDB.weapons = { main = main, off = GetInventoryItemID("player", 17) }
    SaveSet(WEAPONS_SET, { 16, 17 })
  end
end

local function EquipWeapons()
  local w = ns.charDB.weapons
  local main, off
  if w then main, off = w.main, w.off
  elseif ns.MacroLibrary and ns.MacroLibrary.Weapons then main, off = ns.MacroLibrary.Weapons() end
  if not main then return end
  Equip(main, 16)
  if off then Equip(off, 17) end
end

-- First run: no "Fishing" set yet, but a pole in your bags.
local function SetUpFishingSet()
  if InCombatLockdown() or not C_EquipmentSet or C_EquipmentSet.GetEquipmentSetID(FISHING_SET) then return end
  if PoleEquipped() then RememberGear(); return end
  local pole = ns.MacroLibrary and ns.MacroLibrary.FindPole and ns.MacroLibrary.FindPole()
  if not pole then return end
  RememberGear() -- weapons first
  settingUp = true
  Equip(pole, 16)
end

local function Warn(text)
  pcall(RaidNotice_AddMessage, RaidWarningFrame, text, ChatTypeInfo and ChatTypeInfo["RAID_WARNING"])
  if SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound, SOUNDKIT.RAID_WARNING) end
  ns.Print(text)
end

-- Notices the lure going on or running out while the pole is in your hands.
local function CheckLure()
  if not PoleEquipped() then lureOn = nil; return end
  local has, expires = GetWeaponEnchantInfo()
  has = has and true or false
  if lureOn == true and not has then
    Warn("Lure ran out")
  elseif lureOn == false and has then
    ns.Print(string.format("lure on for %d min.", math.floor((expires or 0) / 60000 + 0.5)))
  end
  lureOn = has
end

local function RestoreIfIdle()
  if not PoleEquipped() then
    if ticker then ticker:Cancel(); ticker = nil end
    return
  end
  CheckLure()
  if InCombatLockdown() or UnitChannelInfo("player") or (LootFrame and LootFrame:IsShown()) then return end
  local leaving = IsMounted and IsMounted()
  if not leaving and GetTime() - lastCast < (M.charDB.idleSeconds or 15) then return end
  EquipWeapons()
end

local function Watch()
  lastCast = GetTime()
  if not ticker then ticker = C_Timer.NewTicker(3, RestoreIfIdle) end
end

M.events = {
  PLAYER_ENTERING_WORLD = function()
    RememberGear(); CheckLure()
    C_Timer.After(5, SetUpFishingSet)
  end,
  PLAYER_EQUIPMENT_CHANGED = function(_, slot)
    if slot == 16 or slot == 17 then
      RememberGear()
      if settingUp and PoleEquipped() then
        settingUp = nil
        ns.Print("saved your pole as the \"Fishing\" equipment set for the Fish macro.")
        EquipWeapons()
        return
      end
      if PoleEquipped() then Watch() end
      CheckLure()
    end
  end,
  UNIT_INVENTORY_CHANGED = function(_, unit) if unit == "player" then CheckLure() end end,
  PLAYER_REGEN_ENABLED = function() RememberGear() end,
  PLAYER_MOUNT_DISPLAY_CHANGED = function() if PoleEquipped() then RestoreIfIdle() end end,
  UNIT_SPELLCAST_CHANNEL_START = function(_, unit)
    if unit == "player" and PoleEquipped() then Watch() end
  end,
}
