-- Fishing: remembers the weapons you wear, and puts them back once you stop
-- fishing. Works with the "Fish" macro, which equips the pole and fishes.
--   * While a non-pole weapon is equipped, it is saved as your weapons.
--   * With the pole equipped, 15 seconds after your last cast (out of combat,
--     not channelling, no loot window) your weapons are equipped again.
--   * In combat addons can't change gear; pressing Fish then swaps back.
local _, ns = ...
local M = ns.RegisterModule("Fishing", {
  description = "put your weapons back after fishing",
  charDefaults = { idleSeconds = 15 },
})

local lastCast = 0
local ticker

local function IsPole(id) return ns.MacroLibrary and ns.MacroLibrary.IsPole(id) end

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

local function RestoreIfIdle()
  if not IsPole(GetInventoryItemID("player", 16)) then
    if ticker then ticker:Cancel(); ticker = nil end
    return
  end
  if InCombatLockdown() or UnitChannelInfo("player") or (LootFrame and LootFrame:IsShown()) then return end
  if GetTime() - lastCast < (M.charDB.idleSeconds or 15) then return end
  local w = ns.charDB.weapons
  if not w then return end
  Equip(w.main, 16)
  if w.off then Equip(w.off, 17) end
end

local function Watch()
  lastCast = GetTime()
  if not ticker then ticker = C_Timer.NewTicker(3, RestoreIfIdle) end
end

M.events = {
  PLAYER_ENTERING_WORLD = function() RememberWeapons() end,
  PLAYER_EQUIPMENT_CHANGED = function(_, slot)
    if slot == 16 or slot == 17 then
      RememberWeapons()
      if IsPole(GetInventoryItemID("player", 16)) then Watch() end
    end
  end,
  UNIT_SPELLCAST_CHANNEL_START = function(_, unit, _, spellID)
    if unit == "player" and IsPole(GetInventoryItemID("player", 16)) then Watch() end
  end,
}
