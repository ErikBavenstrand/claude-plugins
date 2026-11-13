-- Hunter macros. Sources: RankedBoost WoW Forever hunter macros (2026-11),
-- Warcraft Tavern Classic hunter pet macros. See Library.lua for the fields.
--
-- A macro earns its place only if it does something a plain spell button
-- can't. No mouseover or @cursor macros (a controller has no mouse), no
-- modifier variants (Shift and Ctrl are layers on both devices), and never
-- /petpassive (it sticks after the fight and your pet stops defending you).
-- No /petattack either: you send the pet yourself.
local _, ns = ...
local L = ns.MacroLibrary

-- Combat -----------------------------------------------------------------------

L.Add({ name = "Arcane", category = "combat", class = "HUNTER", order = 30, perCharacter = true, tags = { "rotation" },
  icon = "Arcane Shot", requires = { "Arcane Shot" },
  desc = "Arcane Shot that also starts Auto Shot (never toggles it off).",
  body = "#showtooltip Arcane Shot\n/cast !Auto Shot\n/cast [@target,harm,nodead] Arcane Shot" })

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
  icon = "Rapid Fire", requires = { "Rapid Fire" }, untested = true,
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

-- Autocast toggles, one per pet ability that can autocast (Classic hunter
-- pets). The controller's { petauto = true } buttons use the one for each of
-- your pet's abilities, but only once you've installed it here; Apply never
-- creates them. On a keyboard, right-click the pet bar instead.
-- petAbility = the pet spell the macro toggles (Controller matches on it).
L.Add({ name = "Auto Growl", category = "pet", class = "HUNTER", order = 101, perCharacter = true, icon = "Growl",
  petAbility = "Growl", tags = { "controller", "autocast" }, desc = "Turns autocast of your pet's Growl on or off.",
  body = "#showtooltip Growl\n/petautocasttoggle Growl" })
L.Add({ name = "Auto Claw", category = "pet", class = "HUNTER", order = 102, perCharacter = true, icon = "Claw",
  petAbility = "Claw", tags = { "controller", "autocast" }, desc = "Turns autocast of your pet's Claw on or off.",
  body = "#showtooltip Claw\n/petautocasttoggle Claw" })
L.Add({ name = "Auto Bite", category = "pet", class = "HUNTER", order = 103, perCharacter = true, icon = "Bite",
  petAbility = "Bite", tags = { "controller", "autocast" }, desc = "Turns autocast of your pet's Bite on or off.",
  body = "#showtooltip Bite\n/petautocasttoggle Bite" })
L.Add({ name = "Auto Dash", category = "pet", class = "HUNTER", order = 104, perCharacter = true, icon = "Dash",
  petAbility = "Dash", tags = { "controller", "autocast" }, desc = "Turns autocast of your pet's Dash on or off.",
  body = "#showtooltip Dash\n/petautocasttoggle Dash" })
L.Add({ name = "Auto Dive", category = "pet", class = "HUNTER", order = 105, perCharacter = true, icon = "Dive",
  petAbility = "Dive", tags = { "controller", "autocast" }, desc = "Turns autocast of your pet's Dive on or off.",
  body = "#showtooltip Dive\n/petautocasttoggle Dive" })
L.Add({ name = "Auto Charge", category = "pet", class = "HUNTER", order = 106, perCharacter = true, icon = "Charge",
  petAbility = "Charge", tags = { "controller", "autocast" }, desc = "Turns autocast of your pet's Charge on or off.",
  body = "#showtooltip Charge\n/petautocasttoggle Charge" })
L.Add({ name = "Auto Prowl", category = "pet", class = "HUNTER", order = 107, perCharacter = true, icon = "Prowl",
  petAbility = "Prowl", tags = { "controller", "autocast" }, desc = "Turns autocast of your pet's Prowl on or off.",
  body = "#showtooltip Prowl\n/petautocasttoggle Prowl" })
L.Add({ name = "Auto Cower", category = "pet", class = "HUNTER", order = 108, perCharacter = true, icon = "Cower",
  petAbility = "Cower", tags = { "controller", "autocast" }, desc = "Turns autocast of your pet's Cower on or off.",
  body = "#showtooltip Cower\n/petautocasttoggle Cower" })
L.Add({ name = "Auto Screech", category = "pet", class = "HUNTER", order = 109, perCharacter = true, icon = "Screech",
  petAbility = "Screech", tags = { "controller", "autocast" }, desc = "Turns autocast of your pet's Screech on or off.",
  body = "#showtooltip Screech\n/petautocasttoggle Screech" })
L.Add({ name = "Auto Howl", category = "pet", class = "HUNTER", order = 110, perCharacter = true, icon = "Furious Howl",
  petAbility = "Furious Howl", tags = { "controller", "autocast" }, desc = "Turns autocast of your pet's Furious Howl on or off.",
  body = "#showtooltip Furious Howl\n/petautocasttoggle Furious Howl" })
L.Add({ name = "Auto Lightning", category = "pet", class = "HUNTER", order = 111, perCharacter = true, icon = "Lightning Breath",
  petAbility = "Lightning Breath", tags = { "controller", "autocast" }, desc = "Turns autocast of your pet's Lightning Breath on or off.",
  body = "#showtooltip Lightning Breath\n/petautocasttoggle Lightning Breath" })
L.Add({ name = "Auto Poison", category = "pet", class = "HUNTER", order = 112, perCharacter = true, icon = "Scorpid Poison",
  petAbility = "Scorpid Poison", tags = { "controller", "autocast" }, desc = "Turns autocast of your pet's Scorpid Poison on or off.",
  body = "#showtooltip Scorpid Poison\n/petautocasttoggle Scorpid Poison" })
L.Add({ name = "Auto Thunder", category = "pet", class = "HUNTER", order = 113, perCharacter = true, icon = "Thunderstomp",
  petAbility = "Thunderstomp", tags = { "controller", "autocast" }, desc = "Turns autocast of your pet's Thunderstomp on or off.",
  body = "#showtooltip Thunderstomp\n/petautocasttoggle Thunderstomp" })
L.Add({ name = "Auto Shell", category = "pet", class = "HUNTER", order = 114, perCharacter = true, icon = "Shell Shield",
  petAbility = "Shell Shield", tags = { "controller", "autocast" }, desc = "Turns autocast of your pet's Shell Shield on or off.",
  body = "#showtooltip Shell Shield\n/petautocasttoggle Shell Shield" })

L.Add({ name = "Recall", category = "pet", class = "HUNTER", order = 40, perCharacter = true,
  iconFile = "Ability_Hunter_BeastCall",
  desc = "Calls your pet back to you.",
  body = "/petfollow" })
