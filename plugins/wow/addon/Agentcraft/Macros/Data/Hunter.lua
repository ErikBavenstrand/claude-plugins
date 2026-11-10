-- Hunter macros. Sources: RankedBoost WoW Forever hunter macros (2026-11),
-- Warcraft Tavern Classic hunter pet macros. See Library.lua for the fields.
local _, ns = ...
local L = ns.MacroLibrary

-- Combat -----------------------------------------------------------------------

L.Add({ name = "Pull", category = "combat", class = "HUNTER", order = 10, perCharacter = true, tags = { "opener", "solo" },
  icon = "Serpent Sting", requires = { "Serpent Sting" },
  desc = "Sends your pet in and opens with Serpent Sting.",
  body = "#showtooltip Serpent Sting\n/petattack [@target,harm,nodead]\n/cast [@target,harm,nodead] Serpent Sting" })

L.Add({ name = "Mark", category = "combat", class = "HUNTER", order = 20, perCharacter = true, tags = { "opener" },
  icon = "Hunter's Mark", requires = { "Hunter's Mark" },
  desc = "Sends your pet in and marks the target.",
  body = "#showtooltip Hunter's Mark\n/petattack [@target,harm,nodead]\n/cast [@target,harm,nodead] Hunter's Mark" })

L.Add({ name = "Arcane", category = "combat", class = "HUNTER", order = 30, perCharacter = true, tags = { "rotation" },
  icon = "Arcane Shot", requires = { "Arcane Shot" },
  desc = "Arcane Shot that also starts Auto Shot (never toggles it off) and sends your pet in.",
  body = "#showtooltip Arcane Shot\n/petattack [@target,harm,nodead]\n/cast !Auto Shot\n/cast [@target,harm,nodead] Arcane Shot" })

L.Add({ name = "Melee", category = "combat", class = "HUNTER", order = 40, perCharacter = true, tags = { "melee" },
  icon = "Raptor Strike", requires = { "Raptor Strike" },
  desc = "Mongoose Bite when it lights up after a dodge, otherwise Raptor Strike.",
  body = "#showtooltip Raptor Strike\n/cast Mongoose Bite\n/cast Raptor Strike" })

L.Add({ name = "Escape", category = "combat", class = "HUNTER", order = 50, perCharacter = true, tags = { "defensive" },
  icon = "Disengage", requires = { "Disengage" },
  desc = "Disengage and keep your pet on the target, so threat goes to the pet.",
  body = "#showtooltip Disengage\n/petattack [@target,harm,nodead]\n/cast Disengage" })

L.Add({ name = "Trap", category = "combat", class = "HUNTER", order = 60, perCharacter = true, tags = { "crowd control", "group" },
  icon = "Freezing Trap", requires = { "Freezing Trap" },
  modifiers = { "Shift: Immolation Trap instead" },
  desc = "Stops attacking, calls your pet back and lays Freezing Trap.",
  body = "#showtooltip\n/stopattack\n/petfollow\n/cast [mod:shift] Immolation Trap; Freezing Trap" })

L.Add({ name = "Aspect", category = "combat", class = "HUNTER", order = 70, perCharacter = true, tags = { "travel" },
  icon = "Aspect of the Hawk", requires = { "Aspect of the Hawk", "Aspect of the Cheetah" },
  modifiers = { "Ctrl: Aspect of the Monkey" },
  desc = "Hawk in combat, Cheetah out of combat.",
  body = "#showtooltip\n/cast [mod:ctrl] Aspect of the Monkey; [combat] Aspect of the Hawk; Aspect of the Cheetah" })

-- Pet --------------------------------------------------------------------------

L.Add({ name = "PetCare", category = "pet", class = "HUNTER", order = 10, perCharacter = true,
  icon = "Mend Pet", requires = { "Mend Pet", "Revive Pet" },
  modifiers = { "Shift: Revive Pet" },
  desc = "Calls your pet, revives it if dead, otherwise heals it with Mend Pet.",
  body = "#showtooltip\n/cast [mod:shift][@pet,dead] Revive Pet; [nopet] Call Pet; Mend Pet" })

L.Add({ name = "Feed", category = "pet", class = "HUNTER", order = 20, perCharacter = true,
  icon = "Feed Pet", requires = { "Feed Pet" },
  desc = "Feeds your pet the first food in your bags it will eat.",
  body = "#showtooltip Feed Pet\n/cast Feed Pet\n/use {PETFOOD}" })

L.Add({ name = "Growl", category = "pet", class = "HUNTER", order = 30, perCharacter = true, tags = { "group" },
  icon = "Growl", iconFile = "Ability_Physical_Taunt", untested = true,
  desc = "Turns your pet's Growl autocast on or off. Off in groups, so it doesn't pull threat from the tank.",
  body = "/petautocasttoggle Growl" })

L.Add({ name = "Recall", category = "pet", class = "HUNTER", order = 40, perCharacter = true,
  iconFile = "Ability_Hunter_BeastCall",
  desc = "Calls your pet back to you.",
  body = "/petfollow" })

L.Add({ name = "PetAttack", category = "pet", class = "HUNTER", order = 5, perCharacter = true,
  iconFile = "Ability_GhoulFrenzy", tags = { "controller" },
  desc = "Sends your pet at your target. Made for a controller back button.",
  body = "/petattack [@target,harm,nodead]" })

-- More hunter macros. Sources: warcrafttavern.com/forever/guides/hunter/ (Forever),
-- warcrafttavern.com/wow-classic/guides/hunter-macros-tips (Classic),
-- us.forums.blizzard.com/en/wow/t/hunter-macros-classic/306685, warcraft.wiki.gg Useful_macros/Hunter.

L.Add({ name = "AutoShot", category = "combat", class = "HUNTER", order = 5, perCharacter = true,
  icon = "Auto Shot", tags = { "rotation" },
  desc = "Targets the nearest enemy if you have none (or a dead/friendly one) and starts Auto Shot without ever toggling it off.",
  body = "#showtooltip Auto Shot\n/targetenemy [noexists][dead][help]\n/cast !Auto Shot" })

L.Add({ name = "MarkMO", category = "combat", class = "HUNTER", order = 21, perCharacter = true,
  icon = "Hunter's Mark", requires = { "Hunter's Mark" }, tags = { "opener", "group" },
  desc = "Hunter's Mark on the enemy under your mouse, otherwise on your target.",
  body = "#showtooltip Hunter's Mark\n/cast [@mouseover,harm,nodead][] Hunter's Mark" })

L.Add({ name = "FDTrap", category = "combat", class = "HUNTER", order = 61, perCharacter = true,
  icon = "Feign Death", requires = { "Feign Death", "Freezing Trap" }, tags = { "crowd control", "defensive" },
  desc = "Press twice in combat: Feign Death to drop combat, then Freezing Trap. Your pet stops and comes back.",
  body = "#showtooltip Freezing Trap\n/stopattack\n/petpassive\n/petfollow\n/cast Freezing Trap\n/cast [combat] Feign Death" })

L.Add({ name = "Scatter", category = "combat", class = "HUNTER", order = 62, perCharacter = true,
  icon = "Scatter Shot", requires = { "Scatter Shot" }, tags = { "crowd control" },
  desc = "Scatter Shot on your target and pull your pet off it so the disorient isn't broken. Send the pet back in afterwards.",
  body = "#showtooltip Scatter Shot\n/targetenemy [noexists][dead][help]\n/petstay [@pettarget,harm]\n/petpassive [@pettarget,harm]\n/cast Scatter Shot" })

L.Add({ name = "EagleEye", category = "combat", class = "HUNTER", order = 80, perCharacter = true,
  icon = "Eagle Eye", requires = { "Eagle Eye" }, tags = { "scouting" }, untested = true,
  desc = "Eagle Eye where your mouse points; pressing again doesn't snap the view back.",
  body = "#showtooltip Eagle Eye\n/cast [@cursor] !Eagle Eye" })

L.Add({ name = "Flare", category = "combat", class = "HUNTER", order = 81, perCharacter = true,
  icon = "Flare", requires = { "Flare" }, tags = { "group", "stealth" }, untested = true,
  desc = "Flare where your mouse points, without the targeting circle. Reveals stealthed enemies.",
  body = "#showtooltip Flare\n/cast [@cursor] Flare" })

L.Add({ name = "Volley", category = "combat", class = "HUNTER", order = 82, perCharacter = true,
  icon = "Volley", requires = { "Volley" }, tags = { "aoe" }, untested = true,
  desc = "Volley where your mouse points, without the targeting circle.",
  body = "#showtooltip Volley\n/cast [@cursor] Volley" })

L.Add({ name = "ScareMO", category = "combat", class = "HUNTER", order = 83, perCharacter = true,
  icon = "Scare Beast", requires = { "Scare Beast" }, tags = { "crowd control" },
  desc = "Scare Beast on the beast under your mouse, otherwise on your target, so you keep your current target.",
  body = "#showtooltip Scare Beast\n/cast [@mouseover,harm,nodead][] Scare Beast" })

L.Add({ name = "PetToggle", category = "pet", class = "HUNTER", order = 6, perCharacter = true,
  iconFile = "Ability_Hunter_BeastCall", tags = { "controller" },
  desc = "One button for your pet: attacks your target if it's idle, comes back if it's already fighting.",
  body = "/petfollow [@pettarget,exists]\n/petattack [@pettarget,noexists]" })

L.Add({ name = "FeedMend", category = "pet", class = "HUNTER", order = 25, perCharacter = true,
  icon = "Mend Pet", requires = { "Feed Pet", "Mend Pet" }, tags = { "controller" },
  desc = "Out of combat feeds your pet, in combat heals it. One button for pet upkeep.",
  body = "#showtooltip\n/cast [nocombat] Feed Pet; [combat] Mend Pet\n/use [nocombat] {PETFOOD}" })
