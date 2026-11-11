-- Fishing: keeps the "Fish" macro one button, and puts your weapons back.
--   * While a non-pole weapon is equipped, it is saved as your weapons.
--   * With the pole equipped, 15 seconds after your last cast (out of combat,
--     not channelling, no loot window) or as soon as you mount, your weapons
--     are equipped again.
--   * In combat addons can't change gear; pressing Fish then swaps back.
--   * The Fish macro is rewritten as things change: while the pole has no
--     lure and you carry one, the button shows the lure and puts it on.
--   * When the lure runs out you get a raid-warning style message and sound.
local _, ns = ...
local M = ns.RegisterModule("Fishing", {
  description = "one-button fishing: lures, weapon swap, lure warnings",
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

-- Rewrites the Fish macro (a live macro) when its steps change (lure or fish).
local function RefreshFish()
  if ns.MacroLibrary and ns.MacroLibrary.RefreshLive then ns.MacroLibrary.RefreshLive() end
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
  RefreshFish()
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
  BAG_UPDATE_DELAYED = function() RefreshFish() end,
  PLAYER_REGEN_ENABLED = function() RefreshFish() end,
  PLAYER_MOUNT_DISPLAY_CHANGED = function() if PoleEquipped() then RestoreIfIdle() end end,
  UNIT_SPELLCAST_CHANNEL_START = function(_, unit)
    if unit == "player" and PoleEquipped() then Watch() end
  end,
}
