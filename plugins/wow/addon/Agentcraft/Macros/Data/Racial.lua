-- Racial ability macros (Classic racials). Each shows only for its race.
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

L.Add({ name = "Forsaken", category = "racial", race = "Scourge", order = 10, icon = "Will of the Forsaken",
  requires = { "Will of the Forsaken" }, tags = { "defensive" },
  desc = "Breaks fear, charm and sleep.",
  body = "#showtooltip Will of the Forsaken\n/cast Will of the Forsaken" })

L.Add({ name = "Stoneform", category = "racial", race = "Dwarf", order = 10, icon = "Stoneform",
  requires = { "Stoneform" }, tags = { "defensive" },
  desc = "Removes poison, disease and bleed and adds armor.",
  body = "#showtooltip Stoneform\n/cast Stoneform" })

L.Add({ name = "Meld", category = "racial", race = "NightElf", order = 10, icon = "Shadowmeld",
  requires = { "Shadowmeld" }, tags = { "stealth" },
  desc = "Stops attacking and melds into the shadows.",
  body = "#showtooltip Shadowmeld\n/stopattack\n/petpassive\n/cast Shadowmeld" })

L.Add({ name = "EscArtist", category = "racial", race = "Gnome", order = 10, icon = "Escape Artist",
  requires = { "Escape Artist" }, tags = { "defensive" },
  desc = "Breaks roots and snares.",
  body = "#showtooltip Escape Artist\n/cast Escape Artist" })

L.Add({ name = "Perception", category = "racial", race = "Human", order = 10, icon = "Perception",
  requires = { "Perception" }, tags = { "stealth" },
  desc = "Raises stealth detection for 20 seconds.",
  body = "#showtooltip Perception\n/cast Perception" })
