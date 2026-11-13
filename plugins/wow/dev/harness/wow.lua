-- Minimal WoW API mock for Agentcraft (Lua 5.1).
--
-- A "world" (W) holds the mocked game state and a log of every call that
-- changes it. An "env" (G) is the sandboxed _G the addon files run in:
--   1. globals the addon sets live in G itself (rawpairs(G) = what it wrote)
--   2. reads fall back to the API table built in M.api(W) below
--   3. then to the Lua 5.1 builtins
--   4. names in M.MISSING are nil, as on the modern client
--   5. anything else is an "auto stub": callable (returns nil), indexable,
--      and recorded in W.unknown, so the runner can list what to mock next.
--
-- Adding an API stub: add a function to the table returned by M.api(W).
-- Read state from W.fixture and W.*, and call Record(W, "Name", ...) when the
-- call changes something a test may want to assert on (W.calls.Name).
-- A C_ namespace that is only partly mocked still auto-stubs its other
-- functions (see Lenient below).
local M = {}

M.MISSING = {
  -- Gone from modern-based clients (WoW Forever): code must not rely on them.
  GetItemInfo = true, GetTalentInfo = true, UnitCharacterPoints = true,
  GetSpellBookItemName = true, GetNumSpellTabs = true, GetSpellTabInfo = true,
  GetContainerNumSlots = true, GetContainerItemID = true, GetContainerItemInfo = true,
}

local unpack = unpack or rawget(table, "unpack")  -- a global in Lua 5.1 / LuaJIT

local function Record(W, name, ...)
  local list = W.calls[name]
  if not list then list = {}; W.calls[name] = list end
  list[#list + 1] = { n = select("#", ...), ... }
end
M.Record = Record

local function noop() end

local function AutoStub(W, path)
  local s = {}
  W.unknown[path] = W.unknown[path] or 0
  return setmetatable(s, {
    __index = function(_, k)
      local child = AutoStub(W, path .. "." .. tostring(k))
      rawset(s, k, child)
      return child
    end,
    __call = function()
      W.unknown[path] = (W.unknown[path] or 0) + 1
      return nil
    end,
  })
end
M.AutoStub = AutoStub

-- A mocked namespace whose missing functions auto-stub instead of being nil.
local function Lenient(W, name, t)
  return setmetatable(t, {
    __index = function(tbl, k)
      local child = AutoStub(W, name .. "." .. tostring(k))
      rawset(tbl, k, child)
      return child
    end,
  })
end

-- World -----------------------------------------------------------------------

function M.NewWorld(fixture)
  return {
    fixture = fixture,
    calls = {},       -- calls.CreateMacro = { {n=4, name, icon, body, perChar}, ... }
    chat = {},        -- every print()
    errors = {},      -- errors raised from event handlers and timers
    macros = {},      -- { {name=, icon=, body=, perChar=}, ... }; index = position
    actions = {},     -- [slot] = { type = "spell"|"item"|"macro"|"flyout", id = n }
    bindings = {},    -- [key] = "SPELL Arcane Shot" / "MACRO Pull" / "ACTIONBUTTON1"
    cursor = nil,     -- { type =, id = } or nil
    inCombat = false,
    now = 1000,
    timers = {},      -- { at =, fn =, every = (tickers), left = }
    frames = {},
    unknown = {},     -- auto-stubbed names -> times called
    gamepad = fixture.gamepad ~= false,
    secret = false,   -- true: combat values are secret (see Secret values below)
  }
end

-- Secret values (12.x client): an addon may hold and pass them, and
-- issecretvalue() says true, but arithmetic, comparison and concatenation
-- raise. W.secret = true makes health, power, attack power, ranged damage,
-- crit, dodge and auras secret; primary stats and armor stay readable.
local SecretMT = {}
local function SecretError() error("attempt to use a secret value", 2) end
for _, ev in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__lt", "__le", "__concat", "__len" }) do
  SecretMT[ev] = SecretError
end
SecretMT.__tostring = function() return "<secret value>" end
local function NewSecret() return setmetatable({}, SecretMT) end
local function IsSecretValue(v) return type(v) == "table" and getmetatable(v) == SecretMT end
M.NewSecret, M.IsSecretValue = NewSecret, IsSecretValue

-- Frames ----------------------------------------------------------------------

local FrameMethods = {}
FrameMethods.__frame = true

function FrameMethods:SetScript(name, fn) self._scripts[name] = fn end
function FrameMethods:GetScript(name) return self._scripts[name] end
function FrameMethods:HookScript(name, fn)
  local old = self._scripts[name]
  self._scripts[name] = old and function(...) old(...); fn(...) end or fn
end
function FrameMethods:HasScript() return true end
function FrameMethods:RegisterEvent(ev) self._events[ev] = true end
function FrameMethods:RegisterUnitEvent(ev) self._events[ev] = true end
function FrameMethods:UnregisterEvent(ev) self._events[ev] = nil end
function FrameMethods:UnregisterAllEvents() self._events = {} end
function FrameMethods:IsEventRegistered(ev) return self._events[ev] == true end
function FrameMethods:Show()
  local was = self._shown
  self._shown = true
  if not was and self._scripts.OnShow then self._scripts.OnShow(self) end
end
function FrameMethods:Hide()
  local was = self._shown
  self._shown = false
  if was and self._scripts.OnHide then self._scripts.OnHide(self) end
end
function FrameMethods:SetShown(v) if v then self:Show() else self:Hide() end end
function FrameMethods:IsShown() return self._shown end
function FrameMethods:IsVisible() return self._shown end
function FrameMethods:GetName() return self._name end
function FrameMethods:GetParent() return self._parent end
function FrameMethods:SetParent(p) self._parent = p end
function FrameMethods:GetObjectType() return self._type end
function FrameMethods:SetText(t) self._text = t end
function FrameMethods:GetText() return self._text end
function FrameMethods:SetWidth(w) self._w = w end
function FrameMethods:SetHeight(h) self._h = h end
function FrameMethods:SetSize(w, h) self._w, self._h = w, h end
function FrameMethods:GetWidth() return self._w or 0 end
function FrameMethods:GetHeight() return self._h or 0 end
function FrameMethods:GetSize() return self._w or 0, self._h or 0 end
function FrameMethods:GetStringWidth() return #(self._text or "") * 6 end
function FrameMethods:GetStringHeight() return 12 end
function FrameMethods:SetAttribute(k, v) self._attr[k] = v end
function FrameMethods:GetAttribute(k) return self._attr[k] end
function FrameMethods:IsEnabled() return self._enabled ~= false end
function FrameMethods:SetEnabled(v) self._enabled = v and true or false end
function FrameMethods:Enable() self._enabled = true end
function FrameMethods:Disable() self._enabled = false end
function FrameMethods:GetChecked() return self._checked end
function FrameMethods:SetChecked(v) self._checked = v end
function FrameMethods:GetNumPoints() return 0 end
-- PortraitFrameTemplate: the portrait texture (a plain no-op widget here).
function FrameMethods:GetPortrait()
  if not self._portrait then self._portrait = M.NewFrame(self._world, "Texture", nil, self) end
  return self._portrait
end

local function NewFrame(W, ftype, name, parent)
  local f = { _type = ftype or "Frame", _name = name, _parent = parent, _scripts = {}, _events = {},
    _attr = {}, _shown = true, _world = W }
  setmetatable(f, {
    __index = function(_, k)
      local m = FrameMethods[k]
      if m ~= nil then return m end
      -- Unmocked widget methods (SetPoint, SetFontObject, ...) are no-ops.
      -- Lowercase keys are the addon's own fields, so they stay nil.
      if type(k) == "string" and k:match("^%u") then
        if k:match("^Create") then
          return function(self) return NewFrame(W, k:sub(7), nil, self) end
        end
        return noop
      end
      return nil
    end,
  })
  return f
end
M.NewFrame = NewFrame

-- Calls a frame script, keeping any error in W.errors (the game shows it and
-- carries on).
local function Safe(W, label, fn, ...)
  local args = { n = select("#", ...), ... }
  local ok, err = xpcall(function() return fn(unpack(args, 1, args.n)) end, debug.traceback)
  if not ok then W.errors[#W.errors + 1] = label .. ": " .. tostring(err) end
  return ok
end
M.Safe = Safe

function M.FireEvent(W, event, ...)
  for _, f in ipairs(W.frames) do
    if f._events[event] and f._scripts.OnEvent then
      Safe(W, "event " .. event, f._scripts.OnEvent, f, event, ...)
    end
  end
end

-- Runs timers and tickers due within the next `seconds` (default 30).
function M.RunTimers(W, seconds)
  local stop = W.now + (seconds or 30)
  for _ = 1, 10000 do
    table.sort(W.timers, function(a, b) return a.at < b.at end)
    local t = W.timers[1]
    if not t or t.at > stop then break end
    table.remove(W.timers, 1)
    W.now = math.max(W.now, t.at)
    if not t.cancelled then
      Safe(W, "timer", t.fn, t.handle)
      if t.every and not t.cancelled then
        t.left = t.left and (t.left - 1)
        if not t.left or t.left > 0 then t.at = W.now + t.every; W.timers[#W.timers + 1] = t end
      end
    end
  end
  W.now = stop
end

-- Fixture helpers -------------------------------------------------------------

local function Spells(W) return W.fixture.spells or {} end

local function SpellByName(W, name)
  for _, s in ipairs(Spells(W)) do if s.name == name then return s end end
end
local function SpellByID(W, id)
  for _, s in ipairs(Spells(W)) do if s.id == id then return s end end
  for _, f in ipairs(W.fixture.flyouts or {}) do
    for _, s in ipairs(f.spells or {}) do if s.id == id then return s end end
  end
end
-- Spells the player has not learned but the game knows about.
local function CatalogSpell(W, key)
  for _, s in ipairs(W.fixture.catalog or {}) do
    if s.name == key or s.id == key then return s end
  end
end

-- Spellbook items: spells, then flyouts.
local function BookItems(W)
  if W._book then return W._book end
  local book = {}
  for _, s in ipairs(Spells(W)) do
    if not s.flyoutOnly then
      book[#book + 1] = { name = s.name, spellID = s.id, actionID = s.id, isPassive = s.passive or false,
        itemType = 1, iconID = s.icon or 136243 }
    end
  end
  for _, f in ipairs(W.fixture.flyouts or {}) do
    book[#book + 1] = { name = f.name, actionID = f.id, itemType = 4, iconID = f.icon or 136243, isPassive = false }
  end
  W._book = book
  return book
end

local function Item(W, id) return (W.fixture.items or {})[id] end

local function ItemIDByName(W, name)
  for id, it in pairs(W.fixture.items or {}) do if it.name == name then return id end end
end

local function HasItem(W, id)
  for _, bag in pairs(W.fixture.bags or {}) do
    for slot, iid in pairs(bag) do if type(slot) == "number" and iid == id then return true end end
  end
  for _, iid in pairs(W.fixture.equipped or {}) do if iid == id then return true end end
  return false
end

local function MacroIndexByName(W, name)
  for i, m in ipairs(W.macros) do if m.name == name then return i end end
  return 0
end

local function Pet(W) return W.fixture.pet end

-- API -------------------------------------------------------------------------

function M.api(W, toc)
  local fx = W.fixture
  local A = {}

  local function Print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    local line = table.concat(parts, " ")
    W.chat[#W.chat + 1] = line
    if os.getenv("AC_VERBOSE") then io.write("    | ", line, "\n") end
  end
  A.print = Print

  -- Lua helpers WoW adds -------------------------------------------------------
  A.date, A.time = os.date, os.time
  A.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
  A.tinsert, A.tremove, A.sort = table.insert, table.remove, table.sort
  A.format, A.gsub, A.strfind, A.strmatch = string.format, string.gsub, string.find, string.match
  A.strlower, A.strupper, A.strlen, A.strsub, A.strrep, A.strbyte, A.strchar = string.lower, string.upper,
    string.len, string.sub, string.rep, string.byte, string.char
  A.floor, A.ceil, A.abs, A.max, A.min, A.sqrt, A.random = math.floor, math.ceil, math.abs, math.max,
    math.min, math.sqrt, math.random
  A.mod = math.fmod
  A.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
  -- WoW's strsplit: every character of sep is a delimiter.
  A.strsplit = function(sep, s, limit)
    local out, pos = {}, 1
    local set = "[" .. sep:gsub("[%^%]%%%-]", "%%%0") .. "]"
    while true do
      if limit and #out == limit - 1 then out[#out + 1] = s:sub(pos); break end
      local a, b = s:find(set, pos)
      if not a then out[#out + 1] = s:sub(pos); break end
      out[#out + 1] = s:sub(pos, a - 1)
      pos = b + 1
    end
    return unpack(out)
  end
  A.strjoin = function(sep, ...) return table.concat({ ... }, sep) end
  A.tContains = function(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
  A.CopyTable = function(t)
    local function copy(x) if type(x) ~= "table" then return x end local c = {} for k, v in pairs(x) do c[k] = copy(v) end return c end
    return copy(t)
  end
  A.Mixin = function(obj, ...) for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do obj[k] = v end end return obj end
  A.CreateFromMixins = function(...) return A.Mixin({}, ...) end
  A.debugstack = function() return debug.traceback() end
  A.geterrorhandler = function() return function(err) W.errors[#W.errors + 1] = "geterrorhandler: " .. tostring(err) end end
  A.seterrorhandler = noop
  A.securecall = function(fn, ...) if type(fn) == "string" then fn = A[fn] end return fn(...) end
  A.hooksecurefunc = function(a, b, c)
    local tbl, name, fn = a, b, c
    if type(a) == "string" then tbl, name, fn = W.G, a, b end
    local old = tbl[name]
    tbl[name] = function(...) local r = { old(...) } fn(...) return unpack(r) end
  end
  A.issecurevariable = function() return true end
  A.issecretvalue = IsSecretValue
  A.InCombatLockdown = function() return W.inCombat end
  A.GetTime = function() return W.now end
  A.GetServerTime = function() return os.time() end

  -- Constants -------------------------------------------------------------------
  A.NUM_BAG_SLOTS, A.NUM_BANKBAGSLOTS, A.NUM_PET_ACTION_SLOTS = 4, 6, 10
  A.MAX_ACCOUNT_MACROS, A.MAX_CHARACTER_MACROS = 120, 18
  A.BOOKTYPE_SPELL, A.BOOKTYPE_PET = "spell", "pet"
  A.LOCALIZED_CLASS_NAMES_MALE = { HUNTER = "Hunter", WARRIOR = "Warrior", MAGE = "Mage", ROGUE = "Rogue",
    PRIEST = "Priest", WARLOCK = "Warlock", PALADIN = "Paladin", DRUID = "Druid", SHAMAN = "Shaman" }
  A.RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1, colorStr = "ffffffff" } end })
  A.SOUNDKIT = { RAID_WARNING = 8959 }
  A.ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.3, b = 0 } }
  A.SlashCmdList = {}
  A.UISpecialFrames = {}
  A.Enum = setmetatable({
    SpellBookSpellBank = { Player = 0, Pet = 1 },
    SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 },
  }, { __index = function(t, k) local v = AutoStub(W, "Enum." .. k) rawset(t, k, v) return v end })

  -- Frames ----------------------------------------------------------------------
  A.CreateFrame = function(ftype, name, parent)
    local f = NewFrame(W, ftype, name, parent)
    W.frames[#W.frames + 1] = f
    if name then rawset(W.G, name, f) end
    return f
  end
  A.UIParent = NewFrame(W, "Frame", "UIParent")
  A.GameTooltip = NewFrame(W, "GameTooltip", "GameTooltip")
  A.RaidWarningFrame = NewFrame(W, "Frame", "RaidWarningFrame")
  A.LootFrame = NewFrame(W, "Frame", "LootFrame")
  A.LootFrame._shown = false
  A.GameTooltip_Hide = noop
  A.RaidNotice_AddMessage = noop
  A.PlaySound = noop

  -- Addon metadata --------------------------------------------------------------
  local function Metadata(addon, field) if addon == toc.name then return toc.meta[field] end end
  A.GetAddOnMetadata = Metadata
  A.C_AddOns = Lenient(W, "C_AddOns", { GetAddOnMetadata = Metadata, IsAddOnLoaded = function() return false end })

  -- Player ----------------------------------------------------------------------
  local class = fx.class or { "Hunter", "HUNTER", 3 }
  local race = fx.race or { "Orc", "Orc" }
  A.UnitClass = function(unit) if unit == "player" then return unpack(class) end end
  A.UnitRace = function(unit) if unit == "player" then return unpack(race) end end
  A.UnitLevel = function(unit) if unit == "player" then return fx.level or 60 end return 0 end
  A.UnitName = function(unit) if unit == "player" then return "Tester" end if unit == "pet" and Pet(W) then return Pet(W).name end end
  A.GetRealmName = function() return "Mockrealm" end
  A.UnitExists = function(unit) return unit == "player" or (unit == "pet" and Pet(W) ~= nil) end
  A.UnitXP = function() return 100 end
  A.UnitXPMax = function() return 1000 end
  A.GetMaxPlayerLevel = function() return 60 end
  A.UnitChannelInfo = noop
  A.GetZoneText = function() return fx.zone or "Durotar" end
  A.GetSubZoneText = function() return fx.subZone or "" end
  A.GetMoney = function() return fx.money or 123456 end
  A.IsMounted = function() return false end
  A.GetInventoryItemID = function(unit, slot) if unit == "player" then return (fx.equipped or {})[slot] end end
  A.GetWeaponEnchantInfo = function() return false end
  A.GetProfessions = function() return nil end

  -- Combat values: plain numbers, or secrets while W.secret is set.
  local function S(...)
    if not W.secret then return ... end
    local out = { n = select("#", ...) }
    for i = 1, out.n do out[i] = NewSecret() end
    return unpack(out, 1, out.n)
  end
  local function IsUnit(unit) return unit == "player" or (unit == "pet" and Pet(W) ~= nil) end
  A.UnitHealth = function(unit) if IsUnit(unit) then return S(unit == "pet" and 1200 or 3000) end end
  A.UnitHealthMax = function(unit) if IsUnit(unit) then return S(unit == "pet" and 1500 or 3500) end end
  A.UnitPower = function(unit) if IsUnit(unit) then return S(2000) end end
  A.UnitPowerMax = function(unit) if IsUnit(unit) then return S(2500) end end
  A.UnitStat = function(unit, i) if IsUnit(unit) then return 50 + i, 60 + i, 10, 0 end end
  A.UnitArmor = function(unit) if IsUnit(unit) then return 2000, 2100, 2100, 100, 0 end end
  A.UnitAttackPower = function(unit) if IsUnit(unit) then return S(300, 40, 0) end end
  A.UnitRangedAttackPower = function(unit) if IsUnit(unit) then return S(800, 60, 0) end end
  A.UnitRangedDamage = function(unit) if IsUnit(unit) then return S(2.9, 150, 210, 0, 0, 0) end end
  A.GetCritChance = function() return S(8.5) end
  A.GetRangedCritChance = function() return S(12.25) end
  A.GetDodgeChance = function() return S(6.1) end
  -- Aura reads raise while secret, so the snapshot has to keep the old list.
  A.C_UnitAuras = Lenient(W, "C_UnitAuras", {
    GetAuraDataByIndex = function(unit, i)
      if W.secret then error("aura data is secret") end
      local list = unit == "player" and (fx.buffs or { "Aspect of the Hawk", "Trueshot Aura" }) or {}
      local name = list[i]
      if name then return { name = name, auraInstanceID = i } end
    end,
  })

  -- Spells ----------------------------------------------------------------------
  local function SpellInfo(key)
    local s = (type(key) == "number" and SpellByID(W, key)) or (type(key) == "string" and SpellByName(W, key)) or CatalogSpell(W, key)
    if s then return { name = s.name, spellID = s.id, iconID = s.icon or 136243 } end
  end
  -- Spells inside a flyout are known (IsPlayerSpell) but not spellbook items.
  local function Known(id) return SpellByID(W, id) ~= nil end
  A.IsPlayerSpell = function(id) return Known(id) end
  A.IsSpellKnown = function(id) return Known(id) end
  A.IsPassiveSpell = function() return false end
  A.C_Spell = Lenient(W, "C_Spell", {
    GetSpellInfo = SpellInfo,
    GetSpellName = function(key) local i = SpellInfo(key) return i and i.name end,
    GetSpellTexture = function(key) local i = SpellInfo(key) return i and i.iconID end,
    PickupSpell = function(id)
      Record(W, "PickupSpell", id)
      if SpellByID(W, id) then W.cursor = { type = "spell", id = id } end
    end,
  })
  A.PickupSpell = A.C_Spell.PickupSpell
  A.GetFlyoutInfo = function(id)
    for _, f in ipairs(fx.flyouts or {}) do
      if f.id == id then return f.name, "", #(f.spells or {}), true end
    end
  end
  A.GetFlyoutSlotInfo = function(id, slot)
    for _, f in ipairs(fx.flyouts or {}) do
      if f.id == id then
        local s = f.spells[slot]
        if s then return s.id, nil, true, s.name end
      end
    end
  end
  A.C_SpellBook = Lenient(W, "C_SpellBook", {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function(tab)
      if tab == 1 then return { name = "General", itemIndexOffset = 0, numSpellBookItems = #BookItems(W) } end
    end,
    GetSpellBookItemInfo = function(i, bank)
      if bank == 1 then
        local s = Pet(W) and (Pet(W).spells or {})[i]
        if s then return { name = s.name, spellID = s.id, actionID = s.id, itemType = 3, isPassive = false, iconID = s.icon } end
        return nil
      end
      local it = BookItems(W)[i]
      if it then local c = {} for k, v in pairs(it) do c[k] = v end return c end
    end,
    GetSpellBookItemName = function(i, bank)
      local s
      if bank == 1 then s = Pet(W) and (Pet(W).spells or {})[i] else s = BookItems(W)[i] end
      if s then return s.name, "" end
    end,
    GetSpellBookItemAutoCast = function(i, bank)
      local s = bank == 1 and Pet(W) and (Pet(W).spells or {})[i]
      if s then return s.autocast and true or false, false end
      return false, false
    end,
    HasPetSpells = function()
      local p = Pet(W)
      if p and p.spells and #p.spells > 0 then return #p.spells, "PET" end
      return nil
    end,
    PickupSpellBookItem = function(i, bank)
      Record(W, "PickupSpellBookItem", i, bank)
      local it = BookItems(W)[i]
      if it and bank == 0 then W.cursor = { type = it.itemType == 4 and "flyout" or "spell", id = it.actionID } end
    end,
  })

  -- Pet -------------------------------------------------------------------------
  A.GetPetActionInfo = function(i)
    local p = Pet(W)
    local a = p and (p.actions or {})[i]
    if not a then return nil end
    -- name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled
    return a.name, a.texture or 132140, a.token or false, false, a.autocast or false, false
  end

  -- Items and bags --------------------------------------------------------------
  local function ItemInfo(id)
    if type(id) == "string" then id = ItemIDByName(W, id) end
    local it = id and Item(W, id)
    if not it then return nil end
    return it.name, "|Hitem:" .. id .. "|h[" .. it.name .. "]|h", it.quality or 1, it.ilvl or 1, it.minLevel or 0,
      it.type or "Miscellaneous", it.subType or "Other", 20, it.equipLoc or "", it.icon or 134400, 0,
      it.classID or 15, it.subClassID or 0
  end
  A.C_Item = Lenient(W, "C_Item", {
    GetItemInfo = ItemInfo,
    GetItemNameByID = function(id) local it = Item(W, id) return it and it.name end,
    GetItemIconByID = function(id) local it = Item(W, id) return it and (it.icon or 134400) end,
    GetItemInfoInstant = function(id)
      if type(id) == "string" then id = ItemIDByName(W, id) end
      local it = id and Item(W, id)
      if not it then return nil end
      return id, it.type or "Miscellaneous", it.subType or "Other", it.equipLoc or "", it.icon or 134400,
        it.classID or 15, it.subClassID or 0
    end,
    GetItemSpell = function(id) local it = Item(W, id) if it and it.spell then return it.spell, it.spellID or 1 end end,
    PickupItem = function(id)
      Record(W, "PickupItem", id)
      if type(id) == "string" then id = ItemIDByName(W, id) end
      if id and HasItem(W, id) then W.cursor = { type = "item", id = id } end
    end,
    EquipItemByName = function(id, slot) Record(W, "EquipItemByName", id, slot) end,
  })
  A.PickupItem = A.C_Item.PickupItem
  A.EquipItemByName = A.C_Item.EquipItemByName
  A.C_Container = Lenient(W, "C_Container", {
    GetContainerNumSlots = function(bag)
      local b = (fx.bags or {})[bag]
      if not b then return 0 end
      return b.size or 16
    end,
    GetContainerItemID = function(bag, slot) local b = (fx.bags or {})[bag] return b and b[slot] end,
    -- Modern client: bags 1-4 are inventory slots 31-34 (CONTAINER_BAG_OFFSET 30).
    ContainerIDToInventoryID = function(bag) if bag >= 1 and bag <= 4 then return 30 + bag end end,
    GetContainerItemInfo = function(bag, slot)
      local b = (fx.bags or {})[bag]
      local id = b and b[slot]
      local it = id and Item(W, id)
      if not it then return nil end
      return { itemID = id, stackCount = it.count or 1, itemName = it.name, quality = it.quality or 1,
        hyperlink = "|Hitem:" .. id .. "|h[" .. it.name .. "]|h", hasNoValue = false }
    end,
  })
  local function ItemTooltip(id)
    local it = id and Item(W, id)
    if not it then return nil end
    local lines = { { leftText = it.name } }
    if it.tooltip then lines[2] = { leftText = it.tooltip } end
    return { lines = lines }
  end
  A.C_TooltipInfo = Lenient(W, "C_TooltipInfo", {
    GetItemByID = ItemTooltip,
    GetBagItem = function(bag, slot) local b = (fx.bags or {})[bag] return ItemTooltip(b and b[slot]) end,
  })

  -- Macros ----------------------------------------------------------------------
  A.GetNumMacros = function()
    local acct, char = 0, 0
    for _, m in ipairs(W.macros) do if m.perChar then char = char + 1 else acct = acct + 1 end end
    return acct, char
  end
  A.GetMacroIndexByName = function(name) return MacroIndexByName(W, name) end
  A.GetMacroInfo = function(i) local m = W.macros[i] if m then return m.name, m.icon, m.body end end
  A.GetMacroBody = function(i) local m = W.macros[i] return m and m.body end
  A.CreateMacro = function(name, icon, body, perChar)
    Record(W, "CreateMacro", name, icon, body, perChar)
    if W.inCombat then error("CreateMacro: can't create macros in combat") end
    W.macros[#W.macros + 1] = { name = name, icon = icon, body = body, perChar = perChar and true or false }
    return #W.macros
  end
  A.EditMacro = function(i, name, icon, body)
    Record(W, "EditMacro", i, name, icon, body)
    if W.inCombat then error("EditMacro: can't edit macros in combat") end
    local m = W.macros[i]
    if m then m.name, m.icon, m.body = name or m.name, icon or m.icon, body or m.body end
    return i
  end
  A.DeleteMacro = function(i)
    if type(i) == "string" then i = MacroIndexByName(W, i) end
    Record(W, "DeleteMacro", i, W.macros[i] and W.macros[i].name)
    -- Guarded: table.remove(t, 0) in Lua 5.1 shifts the whole list down.
    if W.inCombat or not W.macros[i] then return end
    table.remove(W.macros, i)
  end
  A.PickupMacro = function(i)
    if type(i) == "string" then i = MacroIndexByName(W, i) end
    Record(W, "PickupMacro", i)
    if W.macros[i] then W.cursor = { type = "macro", id = i } end
  end

  -- Action slots and cursor -----------------------------------------------------
  A.GetActionInfo = function(slot)
    local a = W.actions[slot]
    if a then return a.type, a.id, a.subType end
  end
  A.HasAction = function(slot) return W.actions[slot] ~= nil end
  A.GetActionText = function(slot)
    local a = W.actions[slot]
    if a and a.type == "macro" then local m = W.macros[a.id] return m and m.name end
  end
  A.GetActionTexture = function(slot) return W.actions[slot] and 134400 or nil end
  A.PickupAction = function(slot)
    Record(W, "PickupAction", slot)
    W.cursor = W.actions[slot]
    W.actions[slot] = nil
  end
  A.PlaceAction = function(slot)
    Record(W, "PlaceAction", slot, W.cursor and W.cursor.type, W.cursor and W.cursor.id)
    if W.inCombat then return end
    if W.cursor then
      local old = W.actions[slot]
      W.actions[slot] = W.cursor
      W.cursor = old
    end
  end
  A.ClearCursor = function() W.cursor = nil end
  A.GetCursorInfo = function() if W.cursor then return W.cursor.type, W.cursor.id end end

  -- Bindings --------------------------------------------------------------------
  A.SetBinding = function(key, action)
    Record(W, "SetBinding", key, action)
    if W.inCombat then return false end
    W.bindings[key] = action
    return true
  end
  A.SetBindingSpell = function(key, spell)
    Record(W, "SetBindingSpell", key, spell)
    if W.inCombat then return false end
    W.bindings[key] = "SPELL " .. spell
    return true
  end
  A.SetBindingMacro = function(key, macro)
    Record(W, "SetBindingMacro", key, macro)
    if W.inCombat then return false end
    if type(macro) == "number" then macro = W.macros[macro] and W.macros[macro].name end
    W.bindings[key] = "MACRO " .. tostring(macro)
    return true
  end
  A.GetBindingAction = function(key) return W.bindings[key] or "" end
  A.GetBindingKey = function(command)
    local keys = {}
    for k, v in pairs(W.bindings) do if v == command then keys[#keys + 1] = k end end
    table.sort(keys)
    return unpack(keys)
  end
  A.GetNumBindings = function() return 0 end
  A.GetCurrentBindingSet = function() return 1 end
  A.SaveBindings = function(set) Record(W, "SaveBindings", set) end

  -- Gamepad UI ------------------------------------------------------------------
  -- NewEnv hides it (nil, not an auto stub) while W.gamepad is false, so a
  -- test can turn the Gamepad UI off in setup(W).
  A.GamepadActionBarBindingUtil = {
    GetGamepadStorageSlotIndexFromPageAndPageUnitSlotID = function(page, slotID)
      return 180 + (page - 1) * 32 + slotID
    end,
  }
  A.C_GamepadUI = Lenient(W, "C_GamepadUI", { GetFirstGamepadActionStorageSlotIndex = function() return 181 end })
  A.C_GamePad = Lenient(W, "C_GamePad", { IsEnabled = function() return W.gamepad end })
  A.Constants = setmetatable({
    GamepadActionBarConstants = { NUM_STANDARD_PAGES_PER_GAMEPAD_ACTION_BAR_PAGE_UNIT = 3 },
  }, { __index = function(t, k) local v = AutoStub(W, "Constants." .. k) rawset(t, k, v) return v end })

  -- Lists the snapshot walks: empty unless a fixture fills them -------------------
  A.C_SkillInfo = Lenient(W, "C_SkillInfo", { GetNumSkillLines = function() return 0 end })
  A.GetNumSkillLines = function() return 0 end
  A.C_Reputation = Lenient(W, "C_Reputation", { GetNumFactions = function() return 0 end })
  A.C_QuestLog = Lenient(W, "C_QuestLog", {
    GetNumQuestLogEntries = function() return 0 end,
    GetAllCompletedQuestIDs = function() return {} end,
  })
  A.C_CurrencyInfo = Lenient(W, "C_CurrencyInfo", { GetCurrencyListSize = function() return 0 end })
  rawset(A.C_AddOns, "GetNumAddOns", function() return 0 end)
  -- Pet bar tokens (GetPetActionInfo returns these names with isToken).
  A.PET_ACTION_ATTACK, A.PET_ACTION_FOLLOW, A.PET_ACTION_WAIT = "Attack", "Follow", "Stay"
  A.PET_MODE_ASSIST, A.PET_MODE_DEFENSIVE, A.PET_MODE_PASSIVE = "Assist", "Defensive", "Passive"

  -- Timers ----------------------------------------------------------------------
  local function Add(seconds, fn, every, iterations)
    local t = { at = W.now + (seconds or 0), fn = fn, every = every, left = iterations }
    t.handle = { Cancel = function() t.cancelled = true end, IsCancelled = function() return t.cancelled == true end }
    W.timers[#W.timers + 1] = t
    return t.handle
  end
  A.C_Timer = Lenient(W, "C_Timer", {
    After = function(seconds, fn) Add(seconds, fn) end,
    NewTimer = function(seconds, fn) return Add(seconds, fn) end,
    NewTicker = function(seconds, fn, iterations) return Add(seconds, fn, seconds, iterations) end,
  })

  return A
end

-- Environment -----------------------------------------------------------------

local BUILTINS = {
  "assert", "collectgarbage", "error", "getmetatable", "ipairs", "next", "pairs", "pcall", "rawequal",
  "rawget", "rawset", "select", "setmetatable", "tonumber", "tostring", "type", "unpack", "xpcall",
  "string", "table", "math", "coroutine", "bit", "getfenv", "setfenv", "loadstring",
}

function M.NewEnv(W, toc)
  local G = {}
  W.G = G
  local api = M.api(W, toc)
  W.api = api
  local builtins = {}
  for _, name in ipairs(BUILTINS) do builtins[name] = _G[name] end
  builtins.unpack = unpack
  -- The game's xpcall passes extra arguments on to the function (Core.lua
  -- relies on it); plain Lua 5.1 drops them, LuaJIT doesn't.
  builtins.xpcall = function(fn, handler, ...)
    local n = select("#", ...)
    if n == 0 then return xpcall(fn, handler) end
    local args = { ... }
    return xpcall(function() return fn(unpack(args, 1, n)) end, handler)
  end
  -- The addon's own globals and SavedVariables start as nil, never as stubs
  -- (Core.lua does "AgentcraftDB = AgentcraftDB or {}").
  local own = { [toc.name] = true }
  for _, field in ipairs({ "SavedVariables", "SavedVariablesPerCharacter" }) do
    for name in (toc.meta[field] or ""):gmatch("[%w_]+") do own[name] = true end
  end
  W.ownGlobals = own
  local stubs = {}
  W.stubGlobals = stubs
  setmetatable(G, {
    __index = function(_, k)
      if k == "GamepadActionBarBindingUtil" and not W.gamepad then return nil end
      local v = api[k]
      if v ~= nil then return v end
      v = builtins[k]
      if v ~= nil then return v end
      if M.MISSING[k] or own[k] or (type(k) == "string" and k:match("^SLASH_")) then return nil end
      -- Cached outside G, so rawpairs(G) stays exactly what the addon wrote,
      -- even a name it read first (as a stub) and then assigned.
      v = stubs[k]
      if v == nil then v = AutoStub(W, tostring(k)); stubs[k] = v end
      return v
    end,
  })
  rawset(G, "_G", G)
  return G
end

-- TOC and loading -------------------------------------------------------------

function M.ReadToc(dir, name)
  local path = dir .. "/" .. name .. ".toc"
  local f = assert(io.open(path, "r"), "can't open " .. path)
  local toc = { name = name, dir = dir, meta = {}, files = {} }
  for line in f:lines() do
    line = line:gsub("\r$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    local key, value = line:match("^##%s*([^:]+):%s*(.-)$")
    if key then toc.meta[key] = value
    elseif line ~= "" and not line:match("^#") then toc.files[#toc.files + 1] = line:gsub("\\", "/") end
  end
  f:close()
  return toc
end

-- Loads every TOC file into G with the (addonName, ns) varargs. Errors here
-- are fatal: the game would stop loading the file at that point.
function M.LoadAddon(_W, G, toc)
  local ns = {}
  for _, file in ipairs(toc.files) do
    local path = toc.dir .. "/" .. file
    local chunk, err = loadfile(path)
    if not chunk then error("syntax error in " .. file .. ": " .. tostring(err), 0) end
    setfenv(chunk, G)
    local ok, runErr = xpcall(function() chunk(toc.name, ns) end, debug.traceback)
    if not ok then error("error loading " .. file .. ": " .. tostring(runErr), 0) end
  end
  return ns
end

return M
