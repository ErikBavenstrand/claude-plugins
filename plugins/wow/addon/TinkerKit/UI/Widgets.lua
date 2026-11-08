-- Shared building blocks for TinkerKit pages, so every page looks the same:
-- text, section headers, panel fills/borders, buttons and action-slot icons.
local _, ns = ...
local UI = {}
ns.UI = UI

UI.QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
UI.GOLD   = { 1, 0.82, 0 }
UI.GREEN  = { 0.3, 1, 0.3 }
UI.RED    = { 1, 0.3, 0.25 }
UI.ORANGE = { 1, 0.6, 0.1 }
UI.BLUE   = { 0.35, 0.7, 1 }

-- Lookups that work on both modern and classic APIs ---------------------------

function UI.SpellIcon(spell) -- spell ID or name
  if not spell then return end
  if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spell) end
  if GetSpellTexture then return GetSpellTexture(spell) end
end

function UI.SpellName(id)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  if GetSpellInfo then return (GetSpellInfo(id)) end
end

function UI.ItemIcon(id)
  if not id then return end
  if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
  if GetItemIcon then return GetItemIcon(id) end
end

function UI.ItemName(id)
  if C_Item and C_Item.GetItemNameByID then return C_Item.GetItemNameByID(id) end
  if C_Item and C_Item.GetItemInfo then return (C_Item.GetItemInfo(id)) end
end

-- "SHIFT-Q" -> "s-Q", "BUTTON4" -> "M4" (same short style as the default bars)
function UI.KeyText(key)
  if not key then return "" end
  key = key:gsub("SHIFT%-", "s-"):gsub("ALT%-", "a-"):gsub("CTRL%-", "c-")
           :gsub("MOUSEWHEELUP", "WU"):gsub("MOUSEWHEELDOWN", "WD"):gsub("BUTTON", "M")
  return key
end

-- What a binding command does: { icon, name, tip } or nil when unbound.
local BAR_COMMANDS = {
  { "^ACTIONBUTTON(%d+)$", 0 },
  { "^MULTIACTIONBAR1BUTTON(%d+)$", 60 },
  { "^MULTIACTIONBAR2BUTTON(%d+)$", 48 },
  { "^MULTIACTIONBAR3BUTTON(%d+)$", 24 },
  { "^MULTIACTIONBAR4BUTTON(%d+)$", 36 },
}

function UI.DescribeSlot(slot)
  local kind, id = GetActionInfo(slot)
  local d = { icon = GetActionTexture(slot), kind = "bar" }
  if kind == "spell" then d.name = UI.SpellName(id)
  elseif kind == "item" then d.name = UI.ItemName(id)
  elseif kind == "macro" then d.name = GetActionText(slot) or "Macro"
  elseif not kind then d.name = "Empty slot"
  else d.name = GetActionText(slot) or kind end
  d.tip = kind and { action = slot } or { title = "Empty slot" }
  return d
end

function UI.DescribeCommand(command)
  if not command or command == "" then return nil end
  for _, c in ipairs(BAR_COMMANDS) do
    local n = command:match(c[1])
    if n then return UI.DescribeSlot(c[2] + tonumber(n)) end
  end
  local pet = command:match("^BONUSACTIONBUTTON(%d+)$")
  if pet then
    pet = tonumber(pet)
    local name, tex, isToken = GetPetActionInfo(pet)
    if isToken then name, tex = _G[name], _G[tex] end
    return { icon = tex, name = name or ("Pet slot " .. pet), kind = "pet",
             tip = name and { pet = pet } or { title = "Pet slot " .. pet } }
  end
  local name = _G["BINDING_NAME_" .. command] or command
  return { name = name, kind = "other", tip = { title = name } }
end

-- Basic pieces ------------------------------------------------------------------

function UI.Text(parent, text, font)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
  if text then fs:SetText(text) end
  return fs
end

function UI.Fill(frame, r, g, b, a, layer)
  local t = frame:CreateTexture(nil, layer or "BACKGROUND")
  t:SetAllPoints()
  t:SetColorTexture(r, g, b, a)
  return t
end

-- 1px border; returns the 4 textures (recolour with UI.SetBorder).
function UI.Border(frame, r, g, b, a, layer)
  local edges = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = frame:CreateTexture(nil, layer or "BORDER", nil, 7)
    t:SetColorTexture(r, g, b, a)
    if side == "TOP" or side == "BOTTOM" then
      t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT"); t:SetHeight(1)
    else
      t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side); t:SetWidth(1)
    end
    edges[#edges + 1] = t
  end
  return edges
end

function UI.SetBorder(edges, color, a)
  for _, t in ipairs(edges) do
    if color then t:SetColorTexture(color[1], color[2], color[3], a or 1); t:Show() else t:Hide() end
  end
end

-- Gold section title with a faint rule running to the right, width px long.
function UI.Header(parent, text, x, y, width)
  local fs = UI.Text(parent, text, "GameFontNormal")
  fs:SetPoint("TOPLEFT", x or 0, y or 0)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 0.82, 0, 0.2)
  line:SetHeight(1)
  line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
  line:SetPoint("RIGHT", parent, "TOPLEFT", (x or 0) + (width or 590), (y or 0) - 6)
  return fs
end

function UI.Tooltip(widget, title, text)
  widget:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 0.82, 0)
    if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  widget:HookScript("OnLeave", GameTooltip_Hide)
end

function UI.Button(parent, text, width, onClick, tooltip)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 90, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  if tooltip then UI.Tooltip(b, text, tooltip) end
  return b
end

-- Small coloured square + label, for legends.
function UI.Swatch(parent, color, text)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(10, 10)
  UI.Fill(f, color[1], color[2], color[3], 0.9, "ARTWORK")
  local fs = UI.Text(f, text, "GameFontHighlightSmall")
  fs:SetPoint("LEFT", f, "RIGHT", 5, 0)
  f.label = fs
  return f
end

-- Action-slot style icon button ----------------------------------------------
--   slot:SetIcon(texture, faded)   slot:SetKey("s-Q")
--   slot:SetMark(color or nil)     glow around the slot (green/red/orange)
--   slot:SetEdge(color or nil)     thin coloured outline
--   slot:SetTip({ action= | pet= | spellID= | itemID= | title=, text=, color= })
local Slot = {}

function Slot:SetIcon(tex, faded)
  self.icon:SetTexture(tex)
  self.icon:SetShown(tex ~= nil)
  self.icon:SetDesaturated(faded and true or false)
  self.icon:SetAlpha(faded and 0.45 or 1)
end

function Slot:SetKey(text) self.key:SetText(text or "") end

function Slot:SetMark(color)
  if color then
    self.mark:SetVertexColor(color[1], color[2], color[3])
    self.mark:Show()
  else
    self.mark:Hide()
  end
end

function Slot:SetEdge(color) UI.SetBorder(self.edge, color, 0.9) end

function Slot:SetTip(tip) self.tip = tip end

local function SlotEnter(self)
  local t = self.tip
  if not t then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if t.action then GameTooltip:SetAction(t.action)
  elseif t.pet then GameTooltip:SetPetAction(t.pet)
  elseif t.spellID then GameTooltip:SetSpellByID(t.spellID)
  elseif t.itemID then GameTooltip:SetItemByID(t.itemID)
  else GameTooltip:SetText(t.title or "", 1, 0.82, 0) end
  if t.text then
    local c = t.color or UI.GREEN
    GameTooltip:AddLine(t.text, c[1], c[2], c[3], true)
  end
  GameTooltip:Show()
end

function UI.Slot(parent, size)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  Mixin(b, Slot)

  UI.Fill(b, 0, 0, 0, 0.55)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  local frameArt = b:CreateTexture(nil, "ARTWORK", nil, 2)
  frameArt:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  frameArt:SetSize(size * 66 / 36, size * 66 / 36)
  frameArt:SetPoint("CENTER", 0, -1)

  b.mark = b:CreateTexture(nil, "OVERLAY")
  b.mark:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  b.mark:SetBlendMode("ADD")
  b.mark:SetSize(size * 1.75, size * 1.75)
  b.mark:SetPoint("CENTER")
  b.mark:Hide()

  b.edge = UI.Border(b, 1, 1, 1, 0, "OVERLAY")
  UI.SetBorder(b.edge, nil)

  b.key = UI.Text(b, "", "NumberFontNormalSmallGray")
  b.key:SetPoint("TOPRIGHT", -2, -3)
  b.center = UI.Text(b, "", "GameFontDisableSmall")
  b.center:SetPoint("CENTER")

  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetScript("OnEnter", SlotEnter)
  b:SetScript("OnLeave", GameTooltip_Hide)
  return b
end
