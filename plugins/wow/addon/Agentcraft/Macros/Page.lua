-- Macro library page.
--   Top:   "For you" / "Everything" switch, count, search box
--   Chips: one per tag (class, race, profession, topic); click to filter,
--          several chips narrow it further (all must match)
--   Left:  macro cards grouped by category, each with its tag pills
--   Right: details for the selected macro
local _, ns = ...
local UI = ns.UI
local L = ns.MacroLibrary

local LIST_W, ROW_H, DETAIL_X, WIDTH = 320, 50, 356, 604
local GOLD = UI.GOLD

local STATE = {
  installed = { "Installed", "|cff4cff4c" },
  update = { "Update", "|cffffd100" },
  blocked = { "Locked", "|cffff5a4a" },
  ready = { "Not installed", "|cffaaaaaa" },
}
local CHECK_OK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t "
local CHECK_NO = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14|t "
local ALERT = "|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:14|t "

local function HasTemplate(name)
  return C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(name) ~= nil
end

local function Hex(c) return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255) end

local function DisplayIcon(m)
  if m.icon then
    local tex = UI.SpellIcon(m.icon)
    if tex then return tex end
    if C_Item and C_Item.GetItemInfoInstant then
      local itemTex = select(5, C_Item.GetItemInfoInstant(m.icon))
      if itemTex then return itemTex end
    end
  end
  return "Interface\\Icons\\" .. (m.iconFile or "INV_Misc_QuestionMark")
end

local function CategoryTitle(key)
  for _, c in ipairs(L.categories) do if c.key == key then return c.title end end
  return key
end

local function Matches(page, m)
  for key in pairs(page.filters) do
    if not L.HasTag(m, key) then return false end
  end
  local q = page.query
  if q and q ~= "" then
    local hay = m.name .. " " .. (m.desc or "") .. " " .. (m.icon or "")
    for _, t in ipairs(L.Tags(m)) do hay = hay .. " " .. t.label end
    if not hay:lower():find(q, 1, true) then return false end
  end
  return true
end

-- Pill: a small coloured tag label with a tinted background.
local function MakePill(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetHeight(14)
  p.bg = UI.Fill(p, 1, 1, 1, 0.12)
  p.text = UI.Text(p, "", "GameFontHighlightSmall")
  p.text:SetPoint("CENTER", 0, 0)
  return p
end

local function SetPill(p, tag)
  local c = tag.color or { 0.8, 0.8, 0.8 }
  p.text:SetText(tag.label)
  p.text:SetTextColor(c[1], c[2], c[3])
  p.bg:SetColorTexture(c[1], c[2], c[3], 0.16)
  p:SetWidth(p.text:GetStringWidth() + 10)
  p:Show()
end

local function Select(page, m)
  page.selected = m
  ns.UI.Refresh()
end

-- Cards ----------------------------------------------------------------------------

local function MakeCard(page, parent, m)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(LIST_W - 4, ROW_H - 4)
  UI.Fill(row, 0, 0, 0, 0.32)
  row.edge = UI.Border(row, 1, 1, 1, 0.08)
  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 0.82, 0, 0.06)

  row.slot = UI.Slot(row, 36)
  row.slot:SetPoint("LEFT", 5, 0)
  row.slot:SetTip({ title = m.name, text = m.body, color = { 0.85, 0.85, 0.85 } })
  row.slot:SetScript("OnClick", function() Select(page, m) end)

  row.name = UI.Text(row, m.name, "GameFontNormal")
  row.name:SetPoint("TOPLEFT", row.slot, "TOPRIGHT", 8, 0)

  -- Pills for the tags that say who it's for and what it's about; the
  -- category is already the group header.
  row.pills = {}
  local x = 0
  for _, tag in ipairs(L.Tags(m)) do
    if #row.pills < 3 and not (tag.type == "topic" and tag.key == "topic:" .. m.category) then
      local p = MakePill(row)
      SetPill(p, tag)
      p:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", x, -5)
      x = x + p:GetWidth() + 4
      row.pills[#row.pills + 1] = p
    end
  end

  row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  row.check:SetSize(24, 24)
  row.check:SetPoint("RIGHT", -4, 0)
  row.check:SetScript("OnClick", function(self)
    page.ticked[m.name] = self:GetChecked() and true or nil
    ns.UI.Refresh()
  end)

  row.state = UI.Text(row, "", "GameFontHighlightSmall")
  row.state:SetPoint("TOPRIGHT", -32, -6)
  row.state:SetJustifyH("RIGHT")

  row:SetScript("OnClick", function() Select(page, m) end)
  return row
end

-- Tag chips ------------------------------------------------------------------------

local function MakeChip(page, parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(20)
  b.bg = UI.Fill(b, 1, 1, 1, 0.1)
  b.edge = UI.Border(b, 1, 1, 1, 0.15)
  b.text = UI.Text(b, "", "GameFontHighlightSmall")
  b.text:SetPoint("CENTER", 0, 0)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  b:SetScript("OnClick", function(self)
    page.filters[self.key] = not page.filters[self.key] or nil
    page.selected = nil
    ns.UI.Refresh()
  end)
  return b
end

-- Lays chips out in rows across the page; returns the height used.
local function LayoutChips(page)
  local counts, tags, seen = {}, {}, {}
  for _, m in ipairs(page.entries) do
    for _, t in ipairs(L.Tags(m)) do
      counts[t.key] = (counts[t.key] or 0) + 1
      if not seen[t.key] then seen[t.key] = true; tags[#tags + 1] = t end
    end
  end
  table.sort(tags, function(a, b)
    local oa, ob = L.tagTypes[a.type].order, L.tagTypes[b.type].order
    if oa ~= ob then return oa < ob end
    return a.label < b.label
  end)
  -- A filter for a tag that no longer exists in this view is dropped.
  for key in pairs(page.filters) do if not seen[key] then page.filters[key] = nil end end

  local x, y, lastType = 0, 0, nil
  for i, t in ipairs(tags) do
    local chip = page.chips[i] or MakeChip(page, page.chipBar)
    page.chips[i] = chip
    chip.key = t.key
    local on = page.filters[t.key]
    local c = t.color or { 0.8, 0.8, 0.8 }
    chip.text:SetText(Hex(c) .. t.label .. "|r |cff888888" .. counts[t.key] .. "|r")
    chip.bg:SetColorTexture(c[1], c[2], c[3], on and 0.35 or 0.1)
    UI.SetBorder(chip.edge, on and GOLD or c, on and 1 or 0.25)
    local w = chip.text:GetStringWidth() + 16
    chip:SetWidth(w)
    if lastType and t.type ~= lastType then x = x + 8 end
    if x + w > WIDTH then x, y = 0, y - 24 end
    chip:ClearAllPoints()
    chip:SetPoint("TOPLEFT", x, y)
    chip:Show()
    x, lastType = x + w + 4, t.type
  end
  for i = #tags + 1, #page.chips do page.chips[i]:Hide() end
  local height = -y + 20
  page.chipBar:SetHeight(height)
  return height
end

-- Detail panel ---------------------------------------------------------------------

local function Section(parent, anchor, title)
  local head = UI.Text(parent, title, "GameFontNormalSmall")
  head:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
  local body = UI.Text(parent, "", "GameFontHighlightSmall")
  body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -3)
  body:SetWidth(226)
  body:SetJustifyH("LEFT")
  body:SetSpacing(2)
  return head, body
end

local function BuildDetail(page, f)
  local d = CreateFrame("Frame", nil, f)
  d:SetPoint("TOPLEFT", page.chipBar, "BOTTOMLEFT", DETAIL_X, -8)
  d:SetPoint("BOTTOMRIGHT", 0, 0)
  UI.Fill(d, 0, 0, 0, 0.35)
  UI.Border(d, 1, 0.82, 0, 0.25)
  page.detail = d

  d.slot = UI.Slot(d, 44)
  d.slot:SetPoint("TOPLEFT", 10, -10)
  d.title = UI.Text(d, "", "GameFontNormalLarge")
  d.title:SetPoint("TOPLEFT", d.slot, "TOPRIGHT", 10, -2)
  d.sub = UI.Text(d, "", "GameFontDisableSmall")
  d.sub:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -4)
  d.state = UI.Text(d, "", "GameFontHighlightSmall")
  d.state:SetPoint("TOPLEFT", d.sub, "BOTTOMLEFT", 0, -4)

  d.tags = UI.Text(d, "", "GameFontHighlightSmall")
  d.tags:SetPoint("TOPLEFT", d.slot, "BOTTOMLEFT", 0, -8)
  d.tags:SetWidth(226)
  d.tags:SetJustifyH("LEFT")
  d.desc = UI.Text(d, "", "GameFontHighlight")
  d.desc:SetPoint("TOPLEFT", d.tags, "BOTTOMLEFT", 0, -8)
  d.desc:SetWidth(226)
  d.desc:SetJustifyH("LEFT")

  d.modHead, d.mods = Section(d, d.desc, "Modifiers")
  d.reqHead, d.req = Section(d, d.mods, "Requires")
  d.warn = UI.Text(d, "", "GameFontNormalSmall")
  d.warn:SetPoint("TOPLEFT", d.req, "BOTTOMLEFT", 0, -8)
  d.warn:SetWidth(226)
  d.warn:SetJustifyH("LEFT")

  local codeHead = UI.Text(d, "Macro", "GameFontNormalSmall")
  codeHead:SetPoint("TOPLEFT", d.warn, "BOTTOMLEFT", 0, -8)
  local code = CreateFrame("Frame", nil, d)
  code:SetPoint("TOPLEFT", codeHead, "BOTTOMLEFT", 0, -4)
  code:SetPoint("BOTTOMRIGHT", -10, 40)
  UI.Fill(code, 0, 0, 0, 0.55)
  UI.Border(code, 1, 1, 1, 0.08)
  d.code = UI.Text(code, "", "GameFontHighlightSmall")
  d.code:SetPoint("TOPLEFT", 6, -6)
  d.code:SetPoint("TOPRIGHT", -6, -6)
  d.code:SetJustifyH("LEFT")
  d.code:SetJustifyV("TOP")
  d.code:SetSpacing(2)
  d.code:SetTextColor(0.75, 0.9, 1)

  local function Act(fn)
    return function() if page.selected then ns.UI.RunAction(function() fn(page.selected) end) end end
  end
  d.install = UI.Button(d, "Install", 74, Act(function(m) L.Install({ m }) end))
  d.install:SetPoint("BOTTOMLEFT", 10, 10)
  d.remove = UI.Button(d, "Remove", 70, Act(function(m) L.Remove({ m }) end))
  d.remove:SetPoint("LEFT", d.install, "RIGHT", 4, 0)
  d.pickup = UI.Button(d, "Pick up", 74, function()
    if page.selected then L.PickUp(page.selected) end
  end, "Put the macro on your cursor, then click an action bar slot to place it.")
  d.pickup:SetPoint("LEFT", d.remove, "RIGHT", 4, 0)
end

local function FillDetail(page)
  local d, m = page.detail, page.selected
  d:SetShown(m ~= nil)
  if not m then return end
  local st, _, why = L.State(m)
  d.slot:SetIcon(DisplayIcon(m), st == "blocked")
  d.slot:SetTip({ title = m.name, text = m.body, color = { 0.85, 0.85, 0.85 } })
  d.title:SetText(m.name)
  d.sub:SetText(CategoryTitle(m.category) .. "  ·  " .. (m.perCharacter and "Character macro" or "Account macro"))
  local label = STATE[st]
  d.state:SetText(label[2] .. label[1] .. "|r" .. (why and ("  |cffaaaaaa(" .. why .. ")|r") or ""))

  local parts = {}
  for _, t in ipairs(L.Tags(m)) do parts[#parts + 1] = Hex(t.color or { 0.8, 0.8, 0.8 }) .. t.label .. "|r" end
  d.tags:SetText(table.concat(parts, "  ·  "))
  d.desc:SetText(m.desc or "")

  local mods = m.modifiers or {}
  d.modHead:SetShown(#mods > 0)
  d.mods:SetText(table.concat(mods, "\n"))
  local lines = {}
  for _, r in ipairs(L.Requirements(m)) do lines[#lines + 1] = (r[2] and CHECK_OK or CHECK_NO) .. r[1] end
  d.reqHead:SetShown(#lines > 0)
  d.req:SetText(table.concat(lines, "\n"))
  d.warn:SetText(m.untested and (ALERT .. "Not yet confirmed on this game version.") or "")
  d.code:SetText(L.Resolve(m) or m.body)
  d.install:SetText(st == "update" and "Update" or "Install")
end

-- Top bar --------------------------------------------------------------------------

local function BuildTopBar(page, f)
  page.scope = UI.Button(f, "For you", 110, function()
    page.showAll = not page.showAll
    page.entries = L.Entries(page.showAll)
    page.selected = nil
    ns.UI.Refresh()
  end, "Switch between macros that suit your class, race and professions, and every macro in the library.")
  page.scope:SetPoint("TOPLEFT", 0, 0)
  page.count = UI.Text(f, "", "GameFontDisableSmall")
  page.count:SetPoint("LEFT", page.scope, "RIGHT", 10, 0)

  local template = HasTemplate("SearchBoxTemplate") and "SearchBoxTemplate" or "InputBoxTemplate"
  local search = CreateFrame("EditBox", nil, f, template)
  search:SetSize(170, 22)
  search:SetPoint("TOPRIGHT", -4, 0)
  search:SetAutoFocus(false)
  search:HookScript("OnTextChanged", function(self)
    page.query = (self:GetText() or ""):lower()
    page.selected = nil
    ns.UI.Refresh()
  end)
  search:SetScript("OnEscapePressed", search.ClearFocus)

  page.chipBar = CreateFrame("Frame", nil, f)
  page.chipBar:SetPoint("TOPLEFT", 0, -30)
  page.chipBar:SetWidth(WIDTH)
  page.chipBar:SetHeight(20)
  page.chips = {}
end

-- Page -----------------------------------------------------------------------------

local page = ns.RegisterPage({
  id = "macros",
  title = "Macros",
  icon = "Interface\\Icons\\INV_Misc_Note_01",
  order = 30,

  Build = function(page, f)
    page.ticked, page.filters, page.cards, page.headers = {}, {}, {}, {}
    page.query, page.showAll = "", false
    page.entries = L.Entries(false)
    BuildTopBar(page, f)

    local scroll = CreateFrame("ScrollFrame", "AgentcraftMacroScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", page.chipBar, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMLEFT", 0, 0)
    scroll:SetWidth(LIST_W)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(LIST_W)
    child:SetHeight(10)
    scroll:SetScrollChild(child)
    page.list = child

    -- Category headers move with the filter, so their rule follows the text.
    for _, c in ipairs(L.categories) do
      local h = UI.Text(child, c.title, "GameFontNormal")
      h.rule = child:CreateTexture(nil, "ARTWORK")
      h.rule:SetColorTexture(1, 0.82, 0, 0.2)
      h.rule:SetHeight(1)
      h.rule:SetPoint("LEFT", h, "RIGHT", 8, 0)
      h.rule:SetWidth(math.max(LIST_W - 16 - h:GetStringWidth(), 10))
      page.headers[c.key] = h
    end
    page.empty = UI.Text(child, "No macros match. Clear a tag or the search.", "GameFontDisable")
    page.empty:SetPoint("TOP", 0, -20)

    BuildDetail(page, f)
  end,

  Refresh = function(page)
    L.Invalidate()
    page.scope:SetText(page.showAll and "Everything" or "For you")
    LayoutChips(page)

    local y, shown, lastCat = 0, 0, nil
    if page.selected and not Matches(page, page.selected) then page.selected = nil end
    for _, h in pairs(page.headers) do h:Hide(); h.rule:Hide() end
    for _, card in pairs(page.cards) do card:Hide() end
    for _, m in ipairs(page.entries) do
      if Matches(page, m) then
        local card = page.cards[m] or MakeCard(page, page.list, m)
        page.cards[m] = card
        if m.category ~= lastCat then
          lastCat = m.category
          local h = page.headers[m.category]
          if y < 0 then y = y - 6 end
          h:ClearAllPoints()
          h:SetPoint("TOPLEFT", 0, y)
          h:Show()
          h.rule:Show()
          y = y - 20
        end
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", 0, y)
        card:Show()
        y = y - ROW_H
        shown = shown + 1
        page.selected = page.selected or m

        local st = L.State(m)
        local label = STATE[st]
        card.state:SetText(label[2] .. label[1] .. "|r")
        card.check:SetChecked(page.ticked[m.name] or false)
        UI.SetBorder(card.edge, page.selected == m and GOLD or { 1, 1, 1 }, page.selected == m and 0.9 or 0.08)
        card.slot:SetIcon(DisplayIcon(m), st == "blocked")
      end
    end
    page.list:SetHeight(-y + 10)
    page.empty:SetShown(shown == 0)
    local active = 0
    for _ in pairs(page.filters) do active = active + 1 end
    page.count:SetText(shown .. " of " .. #page.entries .. " macros"
      .. (active > 0 and ("  ·  " .. active .. " tag filter" .. (active > 1 and "s" or "")) or ""))
    FillDetail(page)
  end,

  Status = function(page)
    local installed, ticked = 0, 0
    for _, m in ipairs(page.entries or {}) do
      if L.State(m) == "installed" then installed = installed + 1 end
      if page.ticked[m.name] then ticked = ticked + 1 end
    end
    local acct, char = GetNumMacros()
    return string.format("%d installed  ·  %d ticked  ·  slots %d/%d account, %d/%d character",
      installed, ticked, acct or 0, MAX_ACCOUNT_MACROS or 120, char or 0, MAX_CHARACTER_MACROS or 18)
  end,
})

local function Ticked()
  local list = {}
  for _, m in ipairs(page.entries or {}) do
    if page.ticked[m.name] then list[#list + 1] = m end
  end
  return list
end

page.actions = {
  { label = "Clear tags", width = 84, tooltip = "Show every macro again.", fn = function()
    wipe(page.filters)
  end },
  { label = "Tick shown", width = 84, tooltip = "Tick every macro in this view that isn't installed or is out of date.", fn = function()
    for _, m in ipairs(page.entries or {}) do
      local st = L.State(m)
      if Matches(page, m) and (st == "ready" or st == "update") then page.ticked[m.name] = true end
    end
  end },
  { label = "Remove", width = 72, tooltip = "Delete the ticked macros from /macro.", fn = function()
    L.Remove(Ticked()); wipe(page.ticked)
  end },
  { label = "Install", width = 72, tooltip = "Create or update the ticked macros.", fn = function()
    L.Install(Ticked()); wipe(page.ticked)
  end },
}

ns.RegisterCommand("macros", "open the macro library", function() ns.OpenPage("macros") end)
