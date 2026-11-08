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
  desc = "Calls your pet back and stops it attacking.",
  body = "/petfollow\n/petpassive\n/petdefensive" })
