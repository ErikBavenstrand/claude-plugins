-- Racial ability macros (Classic racials). Each shows only for its race.
-- Only racials a macro improves; the rest go on bars as plain spells.
-- Character macros: a racial belongs to one character. See Library.lua for the fields.
local _, ns = ...
local L = ns.MacroLibrary

L.Add({ name = "Stomp", category = "racial", race = "Tauren", order = 10, perCharacter = true, icon = "War Stomp",
  requires = { "War Stomp" }, tags = { "stun", "defensive" },
  desc = "Stops casting and stuns everything around you for 2 seconds.",
  body = "#showtooltip War Stomp\n/stopcasting\n/cast War Stomp" })

L.Add({ name = "Meld", category = "racial", race = "NightElf", order = 10, perCharacter = true, icon = "Shadowmeld",
  requires = { "Shadowmeld" }, tags = { "stealth" },
  desc = "Stops attacking, calls your pet back and melds into the shadows.",
  body = "#showtooltip Shadowmeld\n/stopattack\n/petfollow\n/cast Shadowmeld" })
