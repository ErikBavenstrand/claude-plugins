-- Racial ability macros (Classic racials). Each shows only for its race.
-- Only racials a macro improves; the rest go on bars as plain spells.
-- See Library.lua for the fields.
local _, ns = ...
local L = ns.MacroLibrary

L.Add({ name = "Stomp", category = "racial", race = "Tauren", order = 10, icon = "War Stomp",
  requires = { "War Stomp" }, tags = { "stun", "defensive" },
  desc = "Stops casting and stuns everything around you for 2 seconds.",
  body = "#showtooltip War Stomp\n/stopcasting\n/cast War Stomp" })

L.Add({ name = "Berserk", category = "racial", race = "Troll", order = 10, icon = "Berserking",
  requires = { "Berserking" }, tags = { "cooldown" },
  desc = "Berserking together with your pet attacking, for burst.",
  body = "#showtooltip Berserking\n/petattack [@target,harm,nodead]\n/cast Berserking" })

L.Add({ name = "BloodFury", category = "racial", race = "Orc", order = 10, icon = "Blood Fury",
  requires = { "Blood Fury" }, tags = { "cooldown" },
  desc = "Blood Fury together with your pet attacking, for burst.",
  body = "#showtooltip Blood Fury\n/petattack [@target,harm,nodead]\n/cast Blood Fury" })

L.Add({ name = "Meld", category = "racial", race = "NightElf", order = 10, icon = "Shadowmeld",
  requires = { "Shadowmeld" }, tags = { "stealth" },
  desc = "Stops attacking, calls your pet back and melds into the shadows.",
  body = "#showtooltip Shadowmeld\n/stopattack\n/petfollow\n/cast Shadowmeld" })
