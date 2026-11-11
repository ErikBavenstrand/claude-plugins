-- Fishing: helpers around the "Fish" macro (which only equips a pole and
-- fishes; it never names your weapons).
--   * Remembers the weapons you wear. With the pole equipped, 15 seconds
--     after your last cast (out of combat, not channelling, no loot window)
--     or as soon as you mount, puts them back. Turn it off with
--     /ac off Fishing if you'd rather swap back yourself.
--   * Warns with a raid-warning style message and sound when the lure runs out.
local _, ns = ...
local M = ns.RegisterModule("Fishing", {
  description = "puts your weapons back after fishing; warns when the lure runs out",
  charDefaults = { idleSeconds = 15 },
})

local lastCast = 0
local ticker
local lureOn -- nil until we've seen the pole, then true/false

local function IsPole(id) return ns.MacroLibrary and ns.MacroLibrary.IsPole(id) end
local function PoleEquipped() return IsPole(GetInventoryItemID("player", 16)) end

local function RememberWeapons()
  local main = GetInventoryItemID("player", 16)
  if main and not IsPole(main) then
    ns.charDB.weapons = { main = main, off = GetInventoryItemID("player", 17) }
  end
end

local function Equip(id, slot)
  if not id then return end
  if C_Item and C_Item.EquipItemByName then C_Item.EquipItemByName(id, slot) else EquipItemByName(id, slot) end
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
  local w = ns.charDB.weapons
  local main, off
  if w then main, off = w.main, w.off
  elseif ns.MacroLibrary and ns.MacroLibrary.Weapons then main, off = ns.MacroLibrary.Weapons() end
  if not main then return end
  Equip(main, 16)
  if off then Equip(off, 17) end
end

local function Watch()
  lastCast = GetTime()
  if not ticker then ticker = C_Timer.NewTicker(3, RestoreIfIdle) end
end

M.events = {
  PLAYER_ENTERING_WORLD = function() RememberWeapons(); CheckLure() end,
  PLAYER_EQUIPMENT_CHANGED = function(_, slot)
    if slot == 16 or slot == 17 then
      RememberWeapons()
      if PoleEquipped() then Watch() end
      CheckLure()
    end
  end,
  UNIT_INVENTORY_CHANGED = function(_, unit) if unit == "player" then CheckLure() end end,
  PLAYER_MOUNT_DISPLAY_CHANGED = function() if PoleEquipped() then RestoreIfIdle() end end,
  UNIT_SPELLCAST_CHANNEL_START = function(_, unit)
    if unit == "player" and PoleEquipped() then Watch() end
  end,
}
