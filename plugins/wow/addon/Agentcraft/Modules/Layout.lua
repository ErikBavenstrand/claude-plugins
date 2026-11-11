-- Layout: per-class layouts, designed separately for each device.
--
--   Keyboard: plain keybinds, no flyouts. Bar 1 = Q E R T F G C V 1 2 3 4,
--   bar 2 = Shift + the same keys. The Alt bar (consumables) and the
--   click-only side bars (everything else you know) are filled by ActionBars.
--
--   Controller: built for the Gamepad UI and the Steam Deck: trigger layers,
--   radials (spell flyouts) and back buttons. Page 3 holds Deck helpers and a
--   catch-all, so every spell you know is reachable without a keyboard.
--
-- Rules for both, so a layout never feels weird:
--   * Every spell has one permanent home. It never moves when you learn more.
--   * A home lists alternatives only when they're either-or: talents from
--     different builds (Bestial Wrath / Deterrence / Trueshot Aura), or an
--     upgrade in the same role (Explosive Trap replaces Immolation Trap).
--   * No spell appears in two homes on the same device.
--   * Homes for spells you haven't learned stay empty until you do.
-- Entry forms (resolved in Controller.lua):
--   { "Spell", "Alternative" }        first one you know
--   { macro = "Pull", "Serpent Sting" } the macro, once you know the spell
--   { flyout = 253, "Aspect of the Hawk" } a spellbook flyout (radial on a controller)
--   { utility = 2 }                   best item for ActionBars.utility[2]
--   { item = "Hearthstone" }          that item, wherever it is in your bags
--   { racial = true }                 your race's active racial
--   { macro = "Feed", covers = { ... } } spells the macro already casts, so
--                                     the controller catch-all skips them
--   { petauto = true }                controller only: an autocast toggle for
--                                     your pet's next autocastable ability
--   { overflow = true }               controller only: a spell you know that
--                                     has no other controller home
local _, ns = ...
local L = {}
ns.Layout = L

-- Keyboard ------------------------------------------------------------------------
-- index 1-12 = Q E R T F G C V 1 2 3 4

L.keyboard = {
  HUNTER = {
    -- Each row of four keys is one family, so you learn rows, not single keys.
    -- Bar 1: Q E R T rotation, F G C V melee, 1 2 3 4 pull and shots.
    [1] = {
      { macro = "Arcane", "Arcane Shot" },          -- Q  (also Auto Shot + pet attack)
      { macro = "Pull", "Serpent Sting" },          -- E  (also pet attack)
      { "Aimed Shot" },                             -- R
      { "Summon Hawk", "Sniper Shot" },             -- T  build signature: BM / MM
      { "Raptor Strike" },                          -- F
      { "Mongoose Bite" },                          -- G
      { "Disengage" },                              -- C
      { "Wing Clip" },                              -- V
      { macro = "Mark", "Hunter's Mark" },          -- 1  opener (also pet attack)
      { "Multi-Shot" },                             -- 2
      { "Concussive Shot" },                        -- 3
      { "Explosive Trap", "Immolation Trap" },      -- 4  damage trap
    },
    -- Bar 2 (Shift): Q E R T cooldowns and pet, F G C V crowd control and
    -- escape, 1 2 3 4 aspects. Situational spells go to the side bars.
    [2] = {
      { "Mend Pet" },                               -- Shift+Q
      { "Bestial Wrath", "Deterrence", "Trueshot Aura" },   -- Shift+E  build cooldown
      { "Rapid Fire" },                             -- Shift+R
      { "Intimidation", "Counterattack", "Scatter Shot" },  -- Shift+T  build control
      { "Freezing Trap" },                          -- Shift+F
      { "Frost Trap" },                             -- Shift+G
      { racial = true },                            -- Shift+C
      { "Feign Death" },                            -- Shift+V
      { "Aspect of the Hawk" },                     -- Shift+1
      { "Aspect of the Monkey" },                   -- Shift+2
      { "Aspect of the Cheetah" },                  -- Shift+3
      { "Aspect of the Pack" },                     -- Shift+4
    },
  },
}

-- Controller ----------------------------------------------------------------------
-- Keys: "<layer> <button>", layer none / LT / RT / LT+RT, button A X B Y or
-- Up Down Left Right (D-pad). The Top bar's face buttons are fixed.

L.controller = {
  HUNTER = {
    pages = {
      -- Page 1: everything you press in a normal session.
      --   Face buttons (with a trigger) leave your left thumb on the stick, so
      --   they hold what you press while moving: RT = ranged, LT = melee.
      --   The D-pad takes your left thumb off the stick, so you stop moving:
      --   it holds stand-still casts (Mark, Aimed Shot, traps) and
      --   out-of-combat basics. LT+RT is the hardest chord: rare spells.
      {
        title = "Combat",
        ["RT A"] = { macro = "Arcane", "Arcane Shot" },
        ["RT X"] = { macro = "Pull", "Serpent Sting" },
        ["RT B"] = { "Concussive Shot" },
        ["RT Y"] = { "Multi-Shot" },
        ["RT Up"] = { macro = "Mark", "Hunter's Mark" },
        ["RT Right"] = { "Aimed Shot" },
        ["RT Left"] = { "Summon Hawk", "Sniper Shot" },
        ["RT Down"] = { "Explosive Trap", "Immolation Trap" },
        ["LT A"] = { "Raptor Strike" },
        ["LT X"] = { "Mongoose Bite" },
        ["LT B"] = { "Wing Clip" },
        ["LT Y"] = { "Disengage" },
        ["LT Up"] = { "Mend Pet" },
        ["LT Down"] = { "Freezing Trap" },
        ["LT Left"] = { "Intimidation", "Counterattack", "Scatter Shot" },
        ["LT Right"] = { "Bestial Wrath", "Deterrence", "Trueshot Aura" },
        -- No trigger: radials (right stick picks) and out-of-combat basics.
        ["none Up"] = { flyout = 253, "Aspect of the Hawk" },        -- aspects
        ["none Left"] = { flyout = "Tracking", "Track Beasts" },      -- tracking
        ["none Right"] = { macro = "Feed", covers = { "Feed Pet" } },
        ["none Down"] = { macro = "Eat" },
        ["LT+RT A"] = { "Feign Death" },
        ["LT+RT X"] = { "Frost Trap" },
        ["LT+RT B"] = { racial = true },   -- War Stomp etc.; also on back button LT+R5
        ["LT+RT Y"] = { "Rapid Fire" },
        ["LT+RT Up"] = { "Viper Sting" },
        ["LT+RT Down"] = { "Volley" },
        ["LT+RT Left"] = { "Flare" },
        ["LT+RT Right"] = { "Wyvern Sting", "Tranquilizing Shot" },
      },
      -- Page 2: hobbies, pet care, consumables, travel and professions.
      {
        title = "Utility",
        ["RT A"] = { "Revive Pet" },
        ["RT X"] = { "Call Pet" },
        ["RT B"] = { "Dismiss Pet" },
        ["RT Y"] = { "Beast Lore" },
        ["RT Up"] = { item = "Hearthstone" },
        ["RT Down"] = { "Beast Training" },
        ["RT Left"] = { "Eyes of the Beast" },
        ["RT Right"] = { "Tame Beast" },
        ["LT A"] = { utility = 2 },    -- healing potion
        ["LT X"] = { utility = 3 },    -- bandage
        ["LT B"] = { utility = 11 },   -- utility potion
        ["LT Y"] = { utility = 4 },    -- mana potion
        ["LT Up"] = { utility = 1 },   -- bomb
        ["LT Down"] = { utility = 7 }, -- on-use trinket
        ["LT Left"] = { utility = 5 }, -- dynamite
        ["LT Right"] = { utility = 6 }, -- gadget
        -- No trigger, the first thing on this page: fishing and gathering.
        ["none Up"] = { macro = "Fish" },
        ["none Left"] = { overflow = true },
        ["none Right"] = { "Find Minerals", "Find Herbs" },
        ["none Down"] = { "Basic Campfire" },
        ["LT+RT A"] = { "Smelting" },
        ["LT+RT X"] = { "Cooking" },
        ["LT+RT B"] = { "First Aid" },
        ["LT+RT Y"] = { "Engineering" },
        ["LT+RT Up"] = { "Alchemy", "Blacksmithing", "Leatherworking", "Tailoring", "Enchanting" },
        ["LT+RT Down"] = { overflow = true },
        ["LT+RT Left"] = { "Disenchant" },
        ["LT+RT Right"] = { "Skinning" },
      },
      -- Page 3: pet autocast, Steam Deck helpers and the catch-all.
      {
        title = "Pet & Deck",
        -- RT: every ability your pet knows that can autocast, one on/off
        -- toggle each, in pet bar order (spinning border = autocast on).
        ["RT A"] = { petauto = true }, ["RT X"] = { petauto = true },
        ["RT B"] = { petauto = true }, ["RT Y"] = { petauto = true },
        ["RT Up"] = { petauto = true }, ["RT Down"] = { petauto = true },
        ["RT Left"] = { petauto = true }, ["RT Right"] = { petauto = true },
        -- Only what the game menu, vendor window and Steam don't already do.
        ["none Up"] = { macro = "Reload" },
        ["none Down"] = { macro = "Follow" },
        ["none Left"] = { macro = "Focus" },
        ["none Right"] = { macro = "Assist" },
        ["LT+RT A"] = { macro = "Skull" },
        -- Everything else you know, alphabetically: extra shots, tracking...
        ["LT A"] = { overflow = true }, ["LT X"] = { overflow = true },
        ["LT B"] = { overflow = true }, ["LT Y"] = { overflow = true },
        ["LT Up"] = { overflow = true }, ["LT Down"] = { overflow = true },
        ["LT Left"] = { overflow = true }, ["LT Right"] = { overflow = true },
        ["LT+RT X"] = { overflow = true }, ["LT+RT B"] = { overflow = true },
        ["LT+RT Y"] = { overflow = true }, ["LT+RT Up"] = { overflow = true },
        ["LT+RT Down"] = { overflow = true }, ["LT+RT Left"] = { overflow = true },
        ["LT+RT Right"] = { overflow = true },
      },
    },
    -- Steam Deck back buttons (F13-F16), plain and with LT held.
    paddles = {
      ["L4"] = { macro = "PetToggle" },
      ["L5"] = { macro = "Recall" },
      ["R4"] = { "Feign Death", "Disengage" },
      ["R5"] = { "Concussive Shot" },
      ["LT+L4"] = { "Intimidation", "Counterattack", "Scatter Shot" },
      ["LT+L5"] = { "Bestial Wrath", "Deterrence", "Trueshot Aura" },
      ["LT+R4"] = { "Freezing Trap" },
      ["LT+R5"] = { racial = true },
    },
  },
}

function L.ControllerPages(class)
  local c = L.controller[class]
  if not c then return nil end
  return c.pages, c.paddles
end

-- { [1] = 12 entries, [2] = 12 entries } for keyboard bars 1-2.
function L.KeyboardBars(class)
  local k = L.keyboard[class]
  if not k then return nil end
  return { k[1], k[2] }
end
