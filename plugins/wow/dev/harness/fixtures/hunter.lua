-- A level 60 Orc hunter, roughly what the owner plays. Edit freely; tests
-- depend only on what they assert. Spell IDs are Classic ranks; exact IDs
-- don't matter to the addon, only that names and IDs are consistent.
--
-- To build one from a real snapshot: `wowdata.ps1 character -Path spellbook`
-- lists the spellbook, `-Path bags` the bags, `-Path pet` the pet.
return {
  class = { "Hunter", "HUNTER", 3 },
  race = { "Orc", "Orc" },
  level = 60,

  -- Known spells (player spellbook). passive = true are skipped by the addon.
  spells = {
    { name = "Auto Shot", id = 75 },
    { name = "Arcane Shot", id = 14287 },
    { name = "Serpent Sting", id = 13555 },
    { name = "Aimed Shot", id = 20904 },
    { name = "Multi-Shot", id = 14290 },
    { name = "Concussive Shot", id = 5116 },
    { name = "Hunter's Mark", id = 14325 },
    { name = "Raptor Strike", id = 14266 },
    { name = "Mongoose Bite", id = 14271 },
    { name = "Wing Clip", id = 14268 },
    { name = "Disengage", id = 14273 },
    { name = "Counterattack", id = 20910 },
    { name = "Feign Death", id = 5384 },
    { name = "Freezing Trap", id = 14311 },
    { name = "Frost Trap", id = 13809 },
    { name = "Explosive Trap", id = 14317 },
    { name = "Immolation Trap", id = 14305 },
    { name = "Rapid Fire", id = 3045 },
    { name = "Scatter Shot", id = 19503 },
    { name = "Aspect of the Hawk", id = 25296, flyoutOnly = true },
    { name = "Aspect of the Monkey", id = 13163, flyoutOnly = true },
    { name = "Aspect of the Cheetah", id = 5118, flyoutOnly = true },
    { name = "Aspect of the Pack", id = 13159, flyoutOnly = true },
    { name = "Track Beasts", id = 1494 },
    { name = "Track Humanoids", id = 19883 },
    { name = "Mend Pet", id = 13544 },
    { name = "Revive Pet", id = 982 },
    { name = "Call Pet", id = 883 },
    { name = "Dismiss Pet", id = 2641 },
    { name = "Feed Pet", id = 6991 },
    { name = "Tame Beast", id = 1515 },
    { name = "Beast Training", id = 5149 },
    { name = "Beast Lore", id = 1462 },
    { name = "Eyes of the Beast", id = 1002 },
    { name = "Scare Beast", id = 14327 },
    { name = "Volley", id = 14295 },
    { name = "Flare", id = 1543 },
    { name = "Viper Sting", id = 14280 },
    { name = "Tranquilizing Shot", id = 19801 },
    { name = "Eagle Eye", id = 6197 },
    { name = "Blood Fury", id = 20572 },
    { name = "Fishing", id = 18248 },
    { name = "Cooking", id = 18260 },
    { name = "First Aid", id = 18629 },
    { name = "Basic Campfire", id = 818 },
  },

  -- Spellbook flyouts. Aspects are a flyout on the modern client.
  flyouts = {
    { id = 253, name = "Aspects", spells = {
      { name = "Aspect of the Hawk", id = 25296 },
      { name = "Aspect of the Monkey", id = 13163 },
      { name = "Aspect of the Cheetah", id = 5118 },
      { name = "Aspect of the Pack", id = 13159 },
    } },
  },

  -- Spells the game knows but the player hasn't learned (C_Spell.GetSpellInfo works).
  catalog = {
    { name = "Bestial Wrath", id = 19574 },
    { name = "Intimidation", id = 19577 },
    { name = "Trueshot Aura", id = 20906 },
    { name = "Wyvern Sting", id = 24133 },
  },

  items = {
    [6948] = { name = "Hearthstone", spell = "Hearthstone" },
    [8952] = { name = "Roasted Quail", minLevel = 45, spell = "Food", tooltip = "Restores 2148 health over 30 sec. Must remain seated while eating." },
    [8766] = { name = "Morning Glory Dew", minLevel = 45, spell = "Drink", tooltip = "Restores 2934 mana over 30 sec. Must remain seated while drinking." },
    [13446] = { name = "Major Healing Potion", minLevel = 45, spell = "Healing Potion" },
    [14530] = { name = "Heavy Runecloth Bandage", minLevel = 0, spell = "First Aid" },
    [6256] = { name = "Fishing Pole", classID = 2, subClassID = 20, equipLoc = "INVTYPE_2HWEAPON" },
    [18738] = { name = "Carapace Spine Crossbow", classID = 2, subClassID = 18, equipLoc = "INVTYPE_RANGED" },
    [12784] = { name = "Arcanite Reaper", classID = 2, subClassID = 1, equipLoc = "INVTYPE_2HWEAPON" },
  },

  -- bags[bag][slot] = itemID; size defaults to 16 for a listed bag.
  bags = {
    [0] = { 6948, 8952, 8766, 13446, 14530, 6256 },
  },

  -- equipped[inventorySlot] = itemID (16 main hand, 17 off hand, 18 ranged)
  equipped = { [16] = 12784, [18] = 18738 },

  -- Used when boot({ pet = true }).
  petData = {
    name = "Wolf",
    actions = {
      { name = "PET_ACTION_ATTACK", token = true },
      { name = "PET_ACTION_FOLLOW", token = true },
      { name = "PET_ACTION_WAIT", token = true },
      { name = "Bite", texture = 132278, autocast = true },
      { name = "Growl", texture = 132270, autocast = true },
    },
    spells = {
      { name = "Bite", id = 17261, autocast = true },
      { name = "Growl", id = 14921, autocast = true },
      { name = "Furious Howl", id = 24597, autocast = true },
    },
  },
}
