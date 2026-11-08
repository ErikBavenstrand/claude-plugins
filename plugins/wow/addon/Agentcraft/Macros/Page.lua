-- Macro library page: category tabs and search on top, a list of macro
-- cards on the left, details for the selected macro on the right.
-- Tick cards and use the footer to install or remove several at once.
local _, ns = ...
local UI = ns.UI
local L = ns.MacroLibrary

local LIST_W, ROW_H, DETAIL_X, TOP = 320, 46, 356, -44
local GOLD, FAINT = UI.GOLD, { 1, 1, 1 }

local STATE = {
  installed = { "Installed", "|cff4cff4c" },
  update = { "Update", "|cffffd100" },
  blocked = { "Locked", "|cffff5a4a" },
  ready = { "Not installed", "|cffaaaaaa" },
}

local CHECK_OK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t "
local CHECK_NO = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14|t "

local function HasTemplate(name)
  return C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(name) ~= nil
end

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
  if page.category ~= "all" and m.category ~= page.category then return false end
  local q = page.query
  if q and q ~= "" then
    local hay = (m.name .. " " .. (m.desc or "") .. " " .. (m.icon or "")):lower()
    if not hay:find(q, 1, true) then return false end
  end
  return true
end

-- Cards ----------------------------------------------------------------------------

local function Select(page, m)
  page.selected = m
  ns.UI.Refresh()
end

local function MakeCard(page, parent, m)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(LIST_W - 4, ROW_H - 4)
  UI.Fill(row, 0, 0, 0, 0.32)
  row.edge = UI.Border(row, 1, 1, 1, 0.08)
  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 0.82, 0, 0.06)

  row.slot = UI.Slot(row, 34)
  row.slot:SetPoint("LEFT", 5, 0)
  row.slot:SetIcon(DisplayIcon(m))
  row.slot:SetTip({ title = m.name, text = m.body, color = { 0.85, 0.85, 0.85 } })
  row.slot:SetScript("OnClick", function() Select(page, m) end)

  row.name = UI.Text(row, m.name, "GameFontNormal")
  row.name:SetPoint("TOPLEFT", row.slot, "TOPRIGHT", 8, -1)
  if m.untested then
    local warn = row:CreateTexture(nil, "OVERLAY")
    warn:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    warn:SetSize(14, 14)
    warn:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
  end
  row.desc = UI.Text(row, m.desc or "", "GameFontDisableSmall")
  row.desc:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
  row.desc:SetWidth(LIST_W - 110)
  row.desc:SetJustifyH("LEFT")
  row.desc:SetWordWrap(false)

  row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  row.check:SetSize(24, 24)
  row.check:SetPoint("RIGHT", -4, 0)
  row.check:SetScript("OnClick", function(self)
    page.ticked[m.name] = self:GetChecked() and true or nil
    ns.UI.Refresh()
  end)
  UI.Tooltip(row.check, "Tick", "Tick to install or remove with the buttons at the bottom.")

  row.state = UI.Text(row, "", "GameFontHighlightSmall")
  row.state:SetPoint("TOPRIGHT", -32, -6)
  row.state:SetJustifyH("RIGHT")

  row:SetScript("OnClick", function() Select(page, m) end)
  row.macro = m
  return row
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
  d:SetPoint("TOPLEFT", DETAIL_X, TOP)
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

  d.desc = UI.Text(d, "", "GameFontHighlight")
  d.desc:SetPoint("TOPLEFT", d.slot, "BOTTOMLEFT", 0, -12)
  d.desc:SetWidth(226)
  d.desc:SetJustifyH("LEFT")

  d.modHead, d.mods = Section(d, d.desc, "Modifiers")
  d.reqHead, d.req = Section(d, d.mods, "Requires")
  d.warn = UI.Text(d, "", "GameFontNormalSmall")
  d.warn:SetPoint("TOPLEFT", d.req, "BOTTOMLEFT", 0, -8)
  d.warn:SetWidth(226)
  d.warn:SetJustifyH("LEFT")

  local codeHead = UI.Text(d, "Macro", "GameFontNormalSmall")
  codeHead:SetPoint("TOPLEFT", d.warn, "BOTTOMLEFT", 0, -10)
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

  local function Act(fn) return function() if page.selected then ns.UI.RunAction(function() fn(page.selected) end) end end end
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
  d.slot:SetIcon(DisplayIcon(m))
  d.slot:SetTip({ title = m.name, text = m.body, color = { 0.85, 0.85, 0.85 } })
  d.title:SetText(m.name)
  d.sub:SetText(CategoryTitle(m.category) .. "  ·  " .. (m.perCharacter and "Character macro" or "Account macro"))
  local label = STATE[st]
  d.state:SetText(label[2] .. label[1] .. "|r" .. (why and ("  |cffaaaaaa(" .. why .. ")|r") or ""))
  d.desc:SetText(m.desc or "")

  local mods = m.modifiers or {}
  d.modHead:SetShown(#mods > 0)
  d.mods:SetText(#mods > 0 and table.concat(mods, "\n") or "")
  local reqs = L.Requirements(m)
  local lines = {}
  for _, r in ipairs(reqs) do lines[#lines + 1] = (r[2] and CHECK_OK or CHECK_NO) .. r[1] end
  d.reqHead:SetShown(#lines > 0)
  d.req:SetText(table.concat(lines, "\n"))
  d.warn:SetText(m.untested and "|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:14|t Not yet confirmed on this game version." or "")

  local body = L.Resolve(m) or m.body
  d.code:SetText(body)
  d.install:SetText(st == "update" and "Update" or "Install")
end

-- Top bar --------------------------------------------------------------------------

local function BuildTopBar(page, f)
  local tabs = { { key = "all", title = "All macros", icon = "Interface\\Icons\\INV_Misc_Book_09" } }
  for _, c in ipairs(L.categories) do tabs[#tabs + 1] = c end
  page.tabs = {}
  for i, t in ipairs(tabs) do
    local s = UI.Slot(f, 32)
    s:SetPoint("TOPLEFT", (i - 1) * 38, 0)
    s:SetIcon(t.icon)
    s:SetTip({ title = t.title })
    s:SetScript("OnClick", function() page.category = t.key; page.selected = nil; ns.UI.Refresh() end)
    s.key = t.key
    page.tabs[#page.tabs + 1] = s
  end
  page.heading = UI.Text(f, "", "GameFontNormalLarge")
  page.heading:SetPoint("TOPLEFT", #tabs * 38 + 8, -2)
  page.count = UI.Text(f, "", "GameFontDisableSmall")
  page.count:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -2)

  local template = HasTemplate("SearchBoxTemplate") and "SearchBoxTemplate" or "InputBoxTemplate"
  local search = CreateFrame("EditBox", nil, f, template)
  search:SetSize(150, 22)
  search:SetPoint("TOPRIGHT", -4, -4)
  search:SetAutoFocus(false)
  search:HookScript("OnTextChanged", function(self)
    page.query = (self:GetText() or ""):lower()
    page.selected = nil
    ns.UI.Refresh()
  end)
  search:SetScript("OnEscapePressed", search.ClearFocus)
end

-- Page -----------------------------------------------------------------------------

local page = ns.RegisterPage({
  id = "macros",
  title = "Macros",
  icon = "Interface\\Icons\\INV_Misc_Note_01",
  order = 30,

  Build = function(page, f)
    page.ticked, page.cards, page.headers = {}, {}, {}
    page.category, page.query = "all", ""
    BuildTopBar(page, f)

    local scroll = CreateFrame("ScrollFrame", "AgentcraftMacroScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, TOP)
    scroll:SetPoint("BOTTOMLEFT", 0, 0)
    scroll:SetWidth(LIST_W)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(LIST_W)
    child:SetHeight(10)
    scroll:SetScrollChild(child)
    page.list = child

    page.entries = L.Entries()
    for _, m in ipairs(page.entries) do page.cards[m] = MakeCard(page, child, m) end
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
    page.empty = UI.Text(child, "No macros match.", "GameFontDisable")
    page.empty:SetPoint("TOP", 0, -20)

    BuildDetail(page, f)
  end,

  Refresh = function(page)
    L.Invalidate()
    -- Tabs
    for _, s in ipairs(page.tabs) do s:SetEdge(s.key == page.category and GOLD or nil) end
    page.heading:SetText(page.category == "all" and "All macros" or CategoryTitle(page.category))

    -- Cards, grouped under category headers.
    local y, shown, lastCat = 0, 0, nil
    if page.selected and not Matches(page, page.selected) then page.selected = nil end
    for _, h in pairs(page.headers) do h:Hide(); h.rule:Hide() end
    for _, m in ipairs(page.entries) do
      local card = page.cards[m]
      if Matches(page, m) then
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
        UI.SetBorder(card.edge, page.selected == m and GOLD or FAINT, page.selected == m and 0.9 or 0.08)
        card.slot:SetIcon(DisplayIcon(m), st == "blocked")
      else
        card:Hide()
      end
    end
    page.list:SetHeight(-y + 10)
    page.empty:SetShown(shown == 0)
    page.count:SetText(shown .. (shown == 1 and " macro" or " macros"))
    FillDetail(page)
  end,

  Status = function(page)
    local installed, ticked = 0, 0
    for _, m in ipairs(page.entries or {}) do
      local st = L.State(m)
      if st == "installed" then installed = installed + 1 end
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
  { label = "Tick shown", width = 90, tooltip = "Tick every macro in this view that isn't installed or is out of date.", fn = function()
    for _, m in ipairs(page.entries or {}) do
      local st = L.State(m)
      if Matches(page, m) and (st == "ready" or st == "update") then page.ticked[m.name] = true end
    end
  end },
  { label = "Remove", width = 80, tooltip = "Delete the ticked macros from /macro.", fn = function()
    L.Remove(Ticked()); wipe(page.ticked)
  end },
  { label = "Install", width = 80, tooltip = "Create or update the ticked macros.", fn = function()
    L.Install(Ticked()); wipe(page.ticked)
  end },
}

ns.RegisterCommand("macros", "open the macro library", function() ns.OpenPage("macros") end)
