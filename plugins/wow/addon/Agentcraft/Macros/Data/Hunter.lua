-- Hunter macros. Sources: RankedBoost WoW Forever hunter macros (2026-11),
-- Warcraft Tavern Classic hunter pet macros. See Library.lua for the fields.
--
-- A macro earns its place only if it does something a plain spell button
-- can't. No mouseover or @cursor macros (a controller has no mouse), no
-- modifier variants (Shift and Ctrl are layers on both devices), and never
-- /petpassive (it sticks after the fight and your pet stops defending you).
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

L.Add({ name = "FDTrap", category = "combat", class = "HUNTER", order = 61, perCharacter = true,
  icon = "Feign Death", requires = { "Feign Death", "Freezing Trap" }, tags = { "crowd control", "defensive" },
  desc = "Traps can't be laid in combat. Press in combat to Feign Death (drops combat), press again to lay Freezing Trap. Your pet comes back to you.",
  body = "#showtooltip Freezing Trap\n/stopattack\n/petfollow\n/cast Freezing Trap\n/cast [combat] Feign Death" })

L.Add({ name = "Opener", category = "combat", class = "HUNTER", order = 15, perCharacter = true, tags = { "opener", "controller" },
  icon = "Hunter's Mark", requires = { "Hunter's Mark" },
  desc = "Drops a dead or friendly target, picks the nearest enemy if you have none, then Hunter's Mark and Auto Shot. Your pet stays where it is.",
  body = "#showtooltip Hunter's Mark\n/cleartarget [dead][help]\n/targetenemy [noexists]\n/cast Hunter's Mark\n/cast !Auto Shot" })

L.Add({ name = "Melee", category = "combat", class = "HUNTER", order = 40, perCharacter = true, tags = { "melee", "controller" },
  icon = "Raptor Strike", requires = { "Raptor Strike" }, untested = true,
  desc = "Starts melee and uses whichever is ready: Counterattack (after a parry), Mongoose Bite (after a dodge), else Raptor Strike. Spells you don't know are skipped.",
  body = "#showtooltip Raptor Strike\n/startattack\n/cast Counterattack\n/cast Mongoose Bite\n/cast Raptor Strike" })

L.Add({ name = "Burst", category = "combat", class = "HUNTER", order = 50, perCharacter = true, tags = { "cooldown", "controller" },
  icon = "Rapid Fire", untested = true,
  desc = "Every damage cooldown at once: Bestial Wrath, both trinkets, Berserking or Blood Fury, then Rapid Fire. Anything you don't have is skipped.",
  body = "#showtooltip Rapid Fire\n/cast Bestial Wrath\n/use 13\n/use 14\n/cast Berserking\n/cast Blood Fury\n/cast Rapid Fire" })

L.Add({ name = "FD", category = "combat", class = "HUNTER", order = 60, perCharacter = true, tags = { "defensive", "controller" },
  icon = "Feign Death", requires = { "Feign Death" },
  desc = "A clean Feign Death: stops your cast and attacks, calls your pet back, then feigns.",
  body = "#showtooltip Feign Death\n/stopcasting\n/stopattack\n/petfollow\n/cast Feign Death" })

-- Pet --------------------------------------------------------------------------

L.Add({ name = "PetCare", category = "pet", class = "HUNTER", order = 5, perCharacter = true, tags = { "controller" },
  icon = "Mend Pet", requires = { "Mend Pet" }, untested = true,
  desc = "Revives your pet if it's dead, calls it if it's missing, otherwise heals it with Mend Pet.",
  body = "#showtooltip\n/cast [@pet,dead] Revive Pet; [nopet] Call Pet; Mend Pet" })
-- Autocast toggles for every pet ability are generated on the controller
-- (Controller.lua, { petauto = true }); on a keyboard, right-click the pet bar.

L.Add({ name = "PetToggle", category = "pet", class = "HUNTER", order = 6, perCharacter = true,
  iconFile = "Ability_Hunter_BeastCall", tags = { "controller" },
  desc = "One button for your pet: attacks your target if it's idle, comes back if it's already fighting.",
  body = "/petfollow [@pettarget,exists]\n/petattack [@pettarget,noexists]" })

L.Add({ name = "Recall", category = "pet", class = "HUNTER", order = 40, perCharacter = true,
  iconFile = "Ability_Hunter_BeastCall",
  desc = "Calls your pet back to you.",
  body = "/petfollow" })
