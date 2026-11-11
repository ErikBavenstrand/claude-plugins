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

-- Pet --------------------------------------------------------------------------
-- Autocast toggles for every pet ability are generated on the controller
-- (Controller.lua, { petauto = true }); on a keyboard, right-click the pet bar.

L.Add({ name = "PetToggle", category = "pet", class = "HUNTER", order = 6, perCharacter = true,
  iconFile = "Ability_Hunter_BeastCall", tags = { "controller" },
  desc = "One button for your pet: attacks your target if it's idle, comes back if it's already fighting.",
  body = "/petfollow [@pettarget,exists]\n/petattack [@pettarget,noexists]" })

L.Add({ name = "Feed", category = "pet", class = "HUNTER", order = 20, perCharacter = true,
  icon = "Feed Pet", requires = { "Feed Pet" }, live = true,
  desc = "Feeds your pet the first food in your bags it will eat.",
  body = "#showtooltip Feed Pet\n/cast Feed Pet\n/use {PETFOOD}" })

L.Add({ name = "Recall", category = "pet", class = "HUNTER", order = 40, perCharacter = true,
  iconFile = "Ability_Hunter_BeastCall",
  desc = "Calls your pet back to you.",
  body = "/petfollow" })
