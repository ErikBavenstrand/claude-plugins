-- Macros for every class: fishing and utility. Sources: Blizzard forums
-- fishing macro thread, warcraft.wiki.gg Useful macros. See Library.lua for
-- the fields.
--
-- A macro earns its place only if it does something a plain button or the
-- game's own menus can't: no one-line /cast or /use wrappers, no mouse-only
-- macros, nothing the vendor window, game menu or Steam already does.
local _, ns = ...
local L = ns.MacroLibrary

-- Fishing ----------------------------------------------------------------------

L.Add({ name = "Fish", category = "fishing", profession = "Fishing", order = 10, icon = "Fishing", live = true,
  tags = { "controller", "gear" },
  modifiers = { "In combat: swaps straight back to your weapons" },
  desc = "One button fishing: the first press equips your pole. While the pole has no lure and you carry one, the button shows the lure and puts it on; otherwise it fishes. Agentcraft puts your weapons back when you stop, and warns when the lure runs out.",
  body = "#showtooltip {FISHICON}\n/equip [combat] {MAINHAND?}\n/equip [combat] {OFFHAND?}\n/stopmacro [combat]\n/equip [noequipped:{POLETYPE}] {FISHINGPOLE}\n/use [equipped:{POLETYPE}] {LURE?}\n/use [equipped:{POLETYPE}] {LURESLOT?}\n/cast [equipped:{POLETYPE}] {FISHSPELL?}" })

-- Utility ----------------------------------------------------------------------

L.Add({ name = "Eat", category = "utility", tags = { "consumables" }, order = 10, iconFile = "INV_Misc_Food_15",
  live = true, fallback = "No food or drink in your bags",
  desc = "Eats the highest-level food in your bags and, in the same press, drinks your highest-level drink. The button shows that food and how many you have left, and updates by itself when you loot, buy or level up.",
  body = "#showtooltip {EATICON}\n/use {FOOD?}\n/use {DRINK?}" })

L.Add({ name = "Skull", category = "utility", tags = { "group" }, order = 40, iconFile = "INV_Misc_Bone_HumanSkull_01",
  desc = "Puts a skull on your target so the group knows what to kill first.",
  body = "/run SetRaidTarget(\"target\", 8)" })

L.Add({ name = "Focus", category = "utility", tags = { "group", "controller" }, order = 41, iconFile = "Ability_Hunter_SniperShot",
  desc = "Makes your target your focus. Focus a friend, then Assist attacks whatever they attack.",
  body = "/focus" })

L.Add({ name = "Assist", category = "utility", tags = { "group", "controller" }, order = 42, iconFile = "Ability_Hunter_MarkedForDeath",
  desc = "Targets what your focus (or your current friendly target) is attacking, then starts Auto Shot if you're a hunter.",
  body = "/assist [@focus,exists][]\n/cast [harm] !Auto Shot" })

L.Add({ name = "Follow", category = "utility", tags = { "group", "travel", "controller" }, order = 43, iconFile = "Ability_Tracking",
  desc = "Follows your target, for long runs with a friend.",
  body = "/follow" })

L.Add({ name = "Reload", category = "utility", tags = { "interface", "controller" }, order = 70, iconFile = "Spell_Holy_BorrowedTime",
  desc = "Reloads the interface. Saves Agentcraft's snapshot and loads addon changes; the game menu has no reload.",
  body = "/reload" })

-- Retired --------------------------------------------------------------------------
-- Removed from /macro on the next controller Apply, but only while their text
-- is still exactly what Agentcraft installed (yours are never touched).
L.retired = {
  -- Done by the game's menus, the vendor window or Steam.
  Map = "/run ToggleWorldMap()",
  Chat = "/run ChatFrame_OpenChat(\"\")",
  MaxZoom = "/console cameraDistanceMaxZoomFactor 2.6",
  SellGrays = "/run for b=0,4 do for s=1,C_Container.GetContainerNumSlots(b) do local i=C_Container.GetContainerItemInfo(b,s) if i and i.quality==0 and not i.hasNoValue then C_Container.UseContainerItem(b,s) end end end",
  Repair = "/run if CanMerchantRepair() then RepairAllItems() end",
  Screenshot = "/run Screenshot()",
  ReadyCheck = "/readycheck",
  Logout = "/camp",
  QuietErrors = "/run UIErrorsFrame:Clear()",
  -- The Hearthstone item itself goes on the bar.
  Hearth = "#showtooltip Hearthstone\n/use Hearthstone",
  -- Fish and the Fishing module do it now.
  Lure = "#showtooltip Shiny Bauble\n/use Shiny Bauble\n/use 16",
  -- One-line wrappers: the plain spell button is the same.
  Campfire = "#showtooltip\n/cast Basic Campfire",
  Smelt = "#showtooltip\n/cast Smelting",
  Forsaken = "#showtooltip Will of the Forsaken\n/cast Will of the Forsaken",
  Stoneform = "#showtooltip Stoneform\n/cast Stoneform",
  EscArtist = "#showtooltip Escape Artist\n/cast Escape Artist",
  Perception = "#showtooltip Perception\n/cast Perception",
  -- Shift/Ctrl variants: those are bar layers on keyboard and controller.
  Track = "#showtooltip\n/cast [mod:shift] Track Humanoids; [mod:ctrl] Track Beasts; Find Minerals",
  Trap = "#showtooltip\n/stopattack\n/petfollow\n/cast [mod:shift] Immolation Trap; Freezing Trap",
  Aspect = "#showtooltip\n/cast [mod:ctrl] Aspect of the Monkey; [combat] Aspect of the Hawk; Aspect of the Cheetah",
  PetCare = "#showtooltip\n/cast [mod:shift][@pet,dead] Revive Pet; [nopet] Call Pet; Mend Pet",
  -- Mouse-only (@mouseover / @cursor); Eagle Eye isn't even ground-targeted.
  MarkMO = "#showtooltip Hunter's Mark\n/cast [@mouseover,harm,nodead][] Hunter's Mark",
  ScareMO = "#showtooltip Scare Beast\n/cast [@mouseover,harm,nodead][] Scare Beast",
  EagleEye = "#showtooltip Eagle Eye\n/cast [@cursor] !Eagle Eye",
  Flare = "#showtooltip Flare\n/cast [@cursor] Flare",
  Volley = "#showtooltip Volley\n/cast [@cursor] Volley",
  Dynamite = "#showtooltip Rough Dynamite\n/use [@cursor] Rough Dynamite",
  -- Left the pet passive after the fight.
  Scatter = "#showtooltip Scatter Shot\n/targetenemy [noexists][dead][help]\n/petstay [@pettarget,harm]\n/petpassive [@pettarget,harm]\n/cast Scatter Shot",
  -- Covered by other buttons: separate Raptor/Mongoose/Disengage homes,
  -- Arcane starts Auto Shot, PetToggle sends the pet, autocast toggles.
  Melee = "#showtooltip Raptor Strike\n/cast Mongoose Bite\n/cast Raptor Strike",
  Escape = "#showtooltip Disengage\n/petattack [@target,harm,nodead]\n/cast Disengage",
  AutoShot = "#showtooltip Auto Shot\n/targetenemy [noexists][dead][help]\n/cast !Auto Shot",
  PetAttack = "/petattack [@target,harm,nodead]",
  Growl = "/petautocasttoggle Growl",
}
