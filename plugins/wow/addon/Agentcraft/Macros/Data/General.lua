-- Macros for every class: fishing, professions and utility. Sources:
-- Blizzard forums fishing macro thread, warcraft.wiki.gg Useful macros.
-- See Library.lua for the fields.
local _, ns = ...
local L = ns.MacroLibrary

-- Fishing ----------------------------------------------------------------------

L.Add({ name = "Fish", category = "fishing", profession = "Fishing", order = 10, icon = "Fishing",
  modifiers = { "Shift: apply a Shiny Bauble lure to the pole" },
  desc = "Equips your fishing pole if needed, then fishes.",
  body = "#showtooltip Fishing\n/equip [noequipped:Fishing Poles] {FISHINGPOLE}\n/use [mod:shift] Shiny Bauble\n/use [mod:shift] 16\n/cast [nomod] Fishing" })

L.Add({ name = "Weapons", category = "fishing", profession = "Fishing", tags = { "gear" }, order = 20, iconFile = "INV_Sword_04",
  desc = "Swaps back to the weapons you wear now. Install it while they're equipped.",
  body = "/equip {MAINHAND}\n/equip {OFFHAND?}" })

-- Professions ------------------------------------------------------------------

L.Add({ name = "Track", category = "professions", profession = "Mining", tags = { "gathering" }, order = 10, icon = "Find Minerals", iconFile = "Spell_Nature_Earthquake",
  modifiers = { "Shift: Track Humanoids", "Ctrl: Track Beasts" },
  desc = "Tracks minerals on the minimap. Only one tracking can be active.",
  body = "#showtooltip\n/cast [mod:shift] Track Humanoids; [mod:ctrl] Track Beasts; Find Minerals" })

L.Add({ name = "Campfire", category = "professions", profession = "Cooking", order = 20, icon = "Basic Campfire",
  desc = "Lights a campfire for cooking.",
  body = "#showtooltip\n/cast Basic Campfire" })

L.Add({ name = "Smelt", category = "professions", profession = "Mining", order = 30, icon = "Smelting",
  desc = "Opens the smelting window (stand next to a forge).",
  body = "#showtooltip\n/cast Smelting" })

L.Add({ name = "Dynamite", category = "professions", profession = "Engineering", tags = { "explosives" }, order = 40, icon = "Rough Dynamite", untested = true,
  desc = "Throws Rough Dynamite where your mouse points, without the targeting circle.",
  body = "#showtooltip Rough Dynamite\n/use [@cursor] Rough Dynamite" })

-- Utility ----------------------------------------------------------------------

L.Add({ name = "Eat", category = "utility", tags = { "consumables" }, order = 10, iconFile = "INV_Misc_Food_15",
  modifiers = { "Shift: drink instead" },
  desc = "Eats the best food you carry. Reinstall after you buy better food.",
  body = "#showtooltip\n/use [mod:shift] {DRINK}; {FOOD}" })

L.Add({ name = "Hearth", category = "utility", tags = { "travel" }, order = 20, icon = "Hearthstone",
  desc = "Uses your Hearthstone, with its cooldown on the button.",
  body = "#showtooltip Hearthstone\n/use Hearthstone" })

L.Add({ name = "SellGrays", category = "utility", tags = { "vendor" }, order = 30, iconFile = "INV_Misc_Coin_02",
  desc = "Sells every grey item in your bags. Press it with a vendor window open.",
  body = "/run for b=0,4 do for s=1,C_Container.GetContainerNumSlots(b) do local i=C_Container.GetContainerItemInfo(b,s) if i and i.quality==0 and not i.hasNoValue then C_Container.UseContainerItem(b,s) end end end" })
