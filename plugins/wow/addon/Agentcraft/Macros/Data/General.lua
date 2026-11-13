-- Macros for every class: fishing and utility. Sources: warcraft.wiki.gg
-- Useful macros. See Library.lua for the fields and rules.
--
-- A macro earns its place only if it does something a plain button or the
-- game's own menus can't, and keeps working forever once installed: it names
-- spells and slash commands only, never an item. Food and drink are item
-- buttons placed by Apply. Fish's /equip of poles by name is the one
-- exception, which the owner chose.
local _, ns = ...
local L = ns.MacroLibrary

-- Fishing ----------------------------------------------------------------------
-- With a pole in your hands it fishes. Otherwise it tries every common pole
-- by name, worst first, so the best one you carry ends up equipped; poles
-- you don't have are skipped. [equipped:] takes the item subtype, so any
-- pole counts. The subtype name is "Fishing Poles" (plural, as in the
-- auction house), though tooltips say "Fishing Pole". The Fishing module
-- puts your weapons back 15 seconds after your last cast ends, or when you
-- mount, unless you turn it off with /ac off Fishing.

L.Add({ name = "Fish", category = "fishing", profession = "Fishing", order = 10, icon = "Fishing",
  tags = { "controller", "gear" }, untested = true,
  desc = "One button fishing: equips your best pole if you aren't holding one, otherwise fishes. The Fishing module puts your weapons back when you stop fishing or mount (/ac off Fishing to do it yourself).",
  body = "#showtooltip Fishing\n/cast [equipped:Fishing Poles] Fishing\n/stopmacro [equipped:Fishing Poles]\n/equip Fishing Pole\n/equip Strong Fishing Pole\n/equip Darkwood Fishing Pole\n/equip Big Iron Fishing Pole\n/equip Seth's Graphite Fishing Pole" })

-- Utility ----------------------------------------------------------------------

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
-- is still exactly what Agentcraft installed (yours are never touched); keys
-- bound to them are unbound. A name the library still offers (Melee, PetCare)
-- is kept: its old text here makes the Macros page show "Update".
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
  -- Put the lure on a bar as an item button; the Fishing module warns when it runs out.
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
  -- Arcane starts Auto Shot, the library's autocast toggles. No /petattack.
  Melee = "#showtooltip Raptor Strike\n/cast Mongoose Bite\n/cast Raptor Strike",
  Escape = "#showtooltip Disengage\n/petattack [@target,harm,nodead]\n/cast Disengage",
  AutoShot = "#showtooltip Auto Shot\n/targetenemy [noexists][dead][help]\n/cast !Auto Shot",
  PetAttack = "/petattack [@target,harm,nodead]",
  Growl = "/petautocasttoggle Growl",
}

-- Retired macros whose text Agentcraft filled in from your bags (so it
-- differs per person): deleted when every line still has the shape
-- Agentcraft wrote. A line you added yourself keeps the macro.
local function OnlyLines(body, allowed)
  for line in (body .. "\n"):gmatch("(.-)\n") do
    local ok = line == ""
    for _, prefix in ipairs(allowed) do
      if line:sub(1, #prefix) == prefix then ok = true end
    end
    if not ok then return false end
  end
  return true
end
L.retiredShapes = {
  Eat = function(b) return OnlyLines(b, { "#showtooltip", "/use " }) end,
  Feed = function(b) return b:find("/cast Feed Pet", 1, true) and OnlyLines(b, { "#showtooltip", "/cast Feed Pet", "/use " }) end,
}
