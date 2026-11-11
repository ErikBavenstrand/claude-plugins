-- Macros for every class: fishing, professions and utility. Sources:
-- Blizzard forums fishing macro thread, warcraft.wiki.gg Useful macros.
-- See Library.lua for the fields.
local _, ns = ...
local L = ns.MacroLibrary

-- Fishing ----------------------------------------------------------------------

L.Add({ name = "Fish", category = "fishing", profession = "Fishing", order = 10, icon = "Fishing",
  tags = { "controller", "gear" },
  modifiers = { "In combat: swaps straight back to your weapons" },
  desc = "One button fishing: the first press equips your pole. While the pole has no lure and you carry one, the button shows the lure and puts it on; otherwise it fishes. Agentcraft puts your weapons back when you stop, and warns when the lure runs out.",
  body = "#showtooltip {FISHICON}\n/equip [combat] {MAINHAND?}\n/equip [combat] {OFFHAND?}\n/stopmacro [combat]\n/equip [noequipped:{POLETYPE}] {FISHINGPOLE}\n/use [equipped:{POLETYPE}] {LURE?}\n/use [equipped:{POLETYPE}] {LURESLOT?}\n/cast [equipped:{POLETYPE}] {FISHSPELL?}" })

L.Add({ name = "Lure", category = "fishing", profession = "Fishing", order = 15, icon = "Shiny Bauble",
  iconFile = "INV_Misc_Orb_03", tags = { "consumables" },
  desc = "Puts a Shiny Bauble on your fishing pole (+25 Fishing for 10 minutes). Equip the pole first.",
  body = "#showtooltip Shiny Bauble\n/use Shiny Bauble\n/use 16" })

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
  modifiers = { "Shift (LT on a controller): drink instead, if you carry a drink" },
  desc = "Eats the best food you carry. Reinstall (or Apply) after you buy better food or drink.",
  body = "#showtooltip\n/use [mod:shift] {DRINK?}\n/use [nomod] {FOOD}" })

L.Add({ name = "Hearth", category = "utility", tags = { "travel" }, order = 20, icon = "Hearthstone",
  desc = "Uses your Hearthstone, with its cooldown on the button.",
  body = "#showtooltip Hearthstone\n/use Hearthstone" })

L.Add({ name = "SellGrays", category = "utility", tags = { "vendor" }, order = 30, iconFile = "INV_Misc_Coin_02",
  desc = "Sells every grey item in your bags. Press it with a vendor window open.",
  body = "/run for b=0,4 do for s=1,C_Container.GetContainerNumSlots(b) do local i=C_Container.GetContainerItemInfo(b,s) if i and i.quality==0 and not i.hasNoValue then C_Container.UseContainerItem(b,s) end end end" })

-- More utility macros. Sources: us.forums.blizzard.com/en/wow/t/hunter-macros-classic/306685,
-- warcraft.wiki.gg Useful_macros.

L.Add({ name = "Skull", category = "utility", tags = { "group" }, order = 40, iconFile = "INV_Misc_Bone_HumanSkull_01",
  desc = "Puts a skull on your target so the group knows what to kill first.",
  body = "/run SetRaidTarget(\"target\", 8)" })

L.Add({ name = "QuietErrors", category = "utility", tags = { "interface" }, order = 60, iconFile = "INV_Misc_Note_02",
  desc = "Clears the red error text in the middle of the screen. Add it to the end of spammy macros.",
  body = "/run UIErrorsFrame:Clear()" })

-- Everyday helpers, several aimed at controller / Steam Deck play (no mouse,
-- awkward typing). Standard slash commands and long-standing UI functions.

L.Add({ name = "Reload", category = "utility", tags = { "interface", "controller" }, order = 70, iconFile = "Spell_Holy_BorrowedTime",
  desc = "Reloads the interface. Saves Agentcraft's snapshot and loads addon changes; handy without a keyboard.",
  body = "/reload" })

L.Add({ name = "Repair", category = "utility", tags = { "vendor" }, order = 31, iconFile = "INV_Hammer_20",
  desc = "Repairs all your gear. Press it with a repair vendor's window open.",
  body = "/run if CanMerchantRepair() then RepairAllItems() end" })

-- Retired macros: removed from /macro on the next controller Apply, but only
-- while their text is still exactly what Agentcraft installed.
L.retired = {
  Map = "/run ToggleWorldMap()",
  Chat = "/run ChatFrame_OpenChat(\"\")",
  MaxZoom = "/console cameraDistanceMaxZoomFactor 2.6",
}

L.Add({ name = "Screenshot", category = "utility", tags = { "controller", "interface" }, order = 73, iconFile = "INV_Misc_Spyglass_02",
  desc = "Takes a screenshot (saved in the game's Screenshots folder).",
  body = "/run Screenshot()" })

L.Add({ name = "Focus", category = "utility", tags = { "group", "controller" }, order = 41, iconFile = "Ability_Hunter_SniperShot",
  desc = "Makes the enemy under your mouse (or your target) your focus, to keep an eye on it or mark it later.",
  body = "/focus [@mouseover,exists][]" })

L.Add({ name = "Assist", category = "utility", tags = { "group", "controller" }, order = 42, iconFile = "Ability_Hunter_MarkedForDeath",
  desc = "Targets what your focus (or your current friendly target) is attacking, then starts Auto Shot if you're a hunter.",
  body = "/assist [@focus,exists][]\n/cast [harm] !Auto Shot" })

L.Add({ name = "Follow", category = "utility", tags = { "group", "travel", "controller" }, order = 43, iconFile = "Ability_Tracking",
  desc = "Follows your target, for long runs with a friend.",
  body = "/follow" })

L.Add({ name = "ReadyCheck", category = "utility", tags = { "group" }, order = 44, iconFile = "INV_Misc_Note_04",
  desc = "Starts a ready check in your group.",
  body = "/readycheck" })

L.Add({ name = "Logout", category = "utility", tags = { "controller", "interface" }, order = 74, iconFile = "Spell_Nature_Sleep",
  desc = "Logs out (camps) without opening the menu. Saves Agentcraft's snapshot.",
  body = "/camp" })
