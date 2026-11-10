-- Layout: one role-based layout per class, shared by the keyboard bars
-- (ActionBars) and the controller bars (Controller), so a spell has the same
-- "home" on every device: rotation button 1 is Q on the keyboard and RT+A on
-- the controller.
--
-- Rules for a layout that never feels weird:
--   * Every spell has one permanent home. It never moves when you learn more.
--   * A home lists alternatives only when they're either-or: talents from
--     different builds (Bestial Wrath / Deterrence / Trueshot Aura), or an
--     upgrade in the same role (Explosive Trap replaces Immolation Trap).
--   * No spell appears in two homes.
--   * Homes for spells you haven't learned stay empty until you do.
-- Entry forms: see Controller.lua (spell names best-first, flyout, macro,
-- utility item, racial).
local _, ns = ...
local L = {}
ns.Layout = L

-- Where each role's buttons sit on each device, in the same order.
-- Keyboard: { bar, index } with bar 1 = plain keys, bar 2 = Shift, and
-- index 1-12 = Q E R T F G C V 1 2 3 4.
L.keyboard = {
  rotation = { { 1, 1 }, { 1, 2 }, { 1, 3 }, { 1, 4 }, { 1, 9 }, { 1, 10 }, { 1, 11 }, { 1, 12 } },
  melee = { { 1, 5 }, { 1, 6 }, { 1, 7 }, { 1, 8 }, { 2, 1 }, { 2, 2 }, { 2, 3 }, { 2, 4 } },
  stationary = { { 2, 5 }, { 2, 6 }, { 2, 7 }, { 2, 8 } },
  situational = { { 2, 9 }, { 2, 10 }, { 2, 11 }, { 2, 12 } }, -- 5-8 go to the side bars
}
L.controller = {
  rotation = { "RT A", "RT X", "RT B", "RT Y", "RT Up", "RT Down", "RT Left", "RT Right" },
  melee = { "LT A", "LT X", "LT B", "LT Y", "LT Up", "LT Down", "LT Left", "LT Right" },
  stationary = { "none Up", "none Left", "none Right", "none Down" },
  situational = { "LT+RT A", "LT+RT X", "LT+RT B", "LT+RT Y", "LT+RT Up", "LT+RT Down", "LT+RT Left", "LT+RT Right" },
}

L.roles = {
  HUNTER = {
    -- Most pressed. Keyboard Q E R T 1 2 3 4, controller RT face then RT D-pad.
    rotation = {
      { "Arcane Shot" },
      { "Serpent Sting" },
      { "Aimed Shot" },
      { "Summon Hawk", "Sniper Shot" },            -- build signature: BM / MM
      { "Multi-Shot" },
      { "Explosive Trap", "Immolation Trap" },     -- damage trap, usable in combat in Forever
      { "Concussive Shot" },
      { "Hunter's Mark" },                         -- once per target, before moving
    },
    -- Keyboard F G C V + Shift Q E R T, controller LT face then LT D-pad.
    melee = {
      { "Raptor Strike" },
      { "Mongoose Bite" },
      { "Disengage" },
      { "Wing Clip" },
      { "Mend Pet" },
      { "Rapid Fire" },
      { "Intimidation", "Counterattack", "Scatter Shot" },   -- build control: BM / SV / MM
      { "Bestial Wrath", "Deterrence", "Trueshot Aura" },   -- build cooldown: BM / SV / MM
    },
    -- Things used standing still. Keyboard Shift F G C V, controller D-pad.
    stationary = {
      { flyout = 253, "Aspect of the Hawk" },      -- aspects (a radial on the controller)
      { "Freezing Trap" },
      { racial = true },
      { macro = "Eat" },
    },
    -- Situational. Keyboard Shift 1 2 3 4 (rest on side bars), controller LT+RT.
    situational = {
      { "Feign Death" },
      { "Frost Trap" },
      { "Scare Beast" },
      { "Distracting Shot" },
      { "Viper Sting" },
      { "Volley" },
      { "Flare" },
      { "Wyvern Sting", "Tranquilizing Shot" },
    },
    -- Steam Deck back buttons (F13-F16) and with LT held.
    paddles = {
      ["L4"] = { macro = "PetAttack" },
      ["L5"] = { macro = "Recall" },
      ["R4"] = { "Feign Death", "Disengage" },
      ["R5"] = { "Concussive Shot" },
      ["LT+L4"] = { "Intimidation", "Counterattack", "Scatter Shot" },
      ["LT+L5"] = { "Bestial Wrath", "Deterrence", "Trueshot Aura" },
      ["LT+R4"] = { "Freezing Trap" },
      ["LT+R5"] = { racial = true },
    },
    -- Controller page 2: pet care, consumables, travel and professions.
    -- (On the keyboard these live on the Alt utility bar and the side bars.)
    controllerPage2 = {
      title = "Utility",
      ["RT A"] = { "Revive Pet" },
      ["RT X"] = { "Call Pet" },
      ["RT B"] = { macro = "Feed" },
      ["RT Y"] = { "Dismiss Pet" },
      ["RT Up"] = { "Beast Lore" },
      ["RT Down"] = { "Beast Training" },
      ["RT Left"] = { "Eyes of the Beast" },
      ["RT Right"] = { "Tame Beast" },
      ["LT A"] = { utility = 2 },   -- healing potion
      ["LT X"] = { utility = 3 },   -- bandage
      ["LT B"] = { utility = 11 },  -- utility potion
      ["LT Y"] = { utility = 4 },   -- mana potion
      ["LT Up"] = { utility = 1 },  -- bomb
      ["LT Down"] = { utility = 7 }, -- trinket
      ["LT Left"] = { utility = 5 }, -- dynamite
      ["LT Right"] = { utility = 6 }, -- gadget
      ["none Up"] = { macro = "Hearth" },
      ["none Left"] = { macro = "Fish" },
      ["none Right"] = { macro = "Track" },
      ["none Down"] = { macro = "Campfire" },
      ["LT+RT A"] = { "Smelting" },
      ["LT+RT X"] = { "Cooking" },
      ["LT+RT B"] = { "First Aid" },
      ["LT+RT Y"] = { "Engineering" },
      ["LT+RT Up"] = { "Alchemy", "Blacksmithing", "Leatherworking", "Tailoring", "Enchanting" },
      ["LT+RT Down"] = { macro = "SellGrays" },
      ["LT+RT Left"] = { "Disenchant", "Skinning" },
      ["LT+RT Right"] = { macro = "Lure" },
    },
  },
}

local ROLE_ORDER = { "rotation", "melee", "stationary", "situational" }

-- Controller pages: page 1 from the roles, page 2 from controllerPage2.
function L.ControllerPages(class)
  local r = L.roles[class]
  if not r then return nil end
  local page1 = { title = "Combat" }
  for _, role in ipairs(ROLE_ORDER) do
    for i, entry in ipairs(r[role] or {}) do
      local key = L.controller[role][i]
      if key then page1[key] = entry end
    end
  end
  return { page1, r.controllerPage2 }, r.paddles
end

-- Keyboard bars: { [1] = { 12 entries }, [2] = { 12 entries } }.
function L.KeyboardBars(class)
  local r = L.roles[class]
  if not r then return nil end
  local bars = { {}, {} }
  for _, role in ipairs(ROLE_ORDER) do
    for i, entry in ipairs(r[role] or {}) do
      local pos = L.keyboard[role][i]
      if pos then bars[pos[1]][pos[2]] = entry end
    end
  end
  return bars
end
