-- The Agentcraft window (/ac): sidebar with one entry per registered page,
-- a header with the page title and summary, the page itself, and a footer
-- with the last result plus the page's buttons. Pages come from
-- ns.RegisterPage (see Core.lua); nothing here knows about specific modules.
local ADDON, ns = ...
local UI = ns.UI

local W, H, NAV_W, TOP = 800, 520, 160, -62
local frame, nav, body, footer, title, summary, status
local current
local navButtons = {}

local function HasTemplate(name)
  return C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(name) ~= nil
end

local function Refresh()
  if not current or not current.frame then return end -- not built (Build failed)
  if current.Refresh then
    local ok, err = pcall(current.Refresh, current)
    if not ok then status:SetText("|cffff4444error:|r " .. tostring(err)) end
  end
  local text = ""
  if current.Status then
    local ok, s = pcall(current.Status, current)
    if ok then text = s or "" else status:SetText("|cffff4444error:|r " .. tostring(s)) end
  end
  summary:SetText(text)
end

-- Footer shows everything the action printed, on one line (full text is in
-- Settings > Log).
local function ShowResult(out)
  local lines = {}
  for line in out:gmatch("[^\n]+") do
    lines[#lines + 1] = (line:gsub("^|cff33ff99Agentcraft|r:%s*", ""))
  end
  status:SetText(#lines > 0 and table.concat(lines, "   ") or "Done.")
end

local function RunAction(fn)
  ShowResult(ns.Run(fn))
  Refresh()
end

local function FooterFor(page)
  if page.footerFrame then return page.footerFrame end
  local f = CreateFrame("Frame", nil, footer)
  f:SetPoint("TOPRIGHT")
  f:SetPoint("BOTTOMRIGHT")
  local anchor, width = nil, 0
  local actions = page.actions or {}
  for i = #actions, 1, -1 do
    local a = actions[i]
    local b = UI.Button(f, a.label, a.width or 96, function() RunAction(a.fn) end, a.tooltip)
    if anchor then b:SetPoint("RIGHT", anchor, "LEFT", -6, 0) else b:SetPoint("RIGHT", 0, 0) end
    anchor, width = b, width + (a.width or 96) + 6
  end
  f:SetWidth(math.max(width, 1))
  page.footerFrame = f
  return f
end

local function Select(page)
  if current and current.frame then current.frame:Hide() end
  if current and current.footerFrame then current.footerFrame:Hide() end
  current = page
  local buildErr
  if not page.frame then
    page.frame = CreateFrame("Frame", nil, body)
    page.frame:SetAllPoints()
    if page.Build then
      local ok, err = pcall(page.Build, page, page.frame)
      if not ok then
        -- Drop the half-built frame so the next visit builds it again.
        page.frame:Hide()
        page.frame, buildErr = nil, err
      end
    end
  end
  if page.frame then page.frame:Show() end
  local f = FooterFor(page)
  f:Show()
  status:SetPoint("RIGHT", f, "LEFT", -12, 0)
  title:SetText(page.title)
  for p, b in pairs(navButtons) do
    b.sel:SetShown(p == page)
    b.bar:SetShown(p == page)
    b.label:SetFontObject(p == page and "GameFontHighlight" or "GameFontNormal")
  end
  if buildErr then
    status:SetText("|cffff4444error:|r " .. tostring(buildErr))
    summary:SetText("")
    return
  end
  status:SetText("")
  Refresh()
end

local function NavButton(page, i)
  local b = CreateFrame("Button", nil, nav)
  b:SetSize(NAV_W - 8, 32)
  b:SetPoint("TOPLEFT", 4, -6 - (i - 1) * 34)
  b.sel = UI.Fill(b, 1, 0.82, 0, 0.12)
  b.bar = b:CreateTexture(nil, "ARTWORK")
  b.bar:SetColorTexture(1, 0.82, 0, 0.9)
  b.bar:SetPoint("TOPLEFT")
  b.bar:SetPoint("BOTTOMLEFT")
  b.bar:SetWidth(2)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.06)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(22, 22)
  b.icon:SetPoint("LEFT", 8, 0)
  b.icon:SetTexture(page.icon or UI.QUESTION)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.label = UI.Text(b, page.title, "GameFontNormal")
  b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
  b:SetScript("OnClick", function() Select(page) end)
  navButtons[page] = b
end

local function Build()
  local portrait = HasTemplate("PortraitFrameTemplate")
  frame = CreateFrame("Frame", "AgentcraftFrame", UIParent,
    portrait and "PortraitFrameTemplate" or "BasicFrameTemplateWithInset")
  frame:SetSize(W, H)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  tinsert(UISpecialFrames, "AgentcraftFrame") -- Escape closes it

  if frame.SetTitle then
    frame:SetTitle("Agentcraft")
  else
    local t = UI.Text(frame, "Agentcraft", "GameFontHighlight")
    t:SetPoint("TOP", 0, -6)
  end

  -- Class emblem in the portrait circle.
  local p = (frame.GetPortrait and frame:GetPortrait())
    or (frame.PortraitContainer and frame.PortraitContainer.portrait) or frame.portrait
  local _, class = UnitClass("player")
  if p and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class] then
    p:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    p:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]))
  end

  -- Header: page title + one-line summary, beside the portrait.
  title = UI.Text(frame, "", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", portrait and 72 or 18, -34)
  summary = UI.Text(frame, "", "GameFontHighlightSmall")
  summary:SetPoint("LEFT", title, "RIGHT", 14, 0)
  local who = UI.Text(frame, "", "GameFontDisableSmall")
  who:SetPoint("TOPRIGHT", -16, -36)
  who:SetText(string.format("%s  ·  %s %d", UnitName("player") or "",
    UnitClass("player") or "", UnitLevel("player") or 0))
  frame:HookScript("OnShow", function()
    who:SetText(string.format("%s  ·  %s %d", UnitName("player") or "",
      UnitClass("player") or "", UnitLevel("player") or 0))
  end)

  -- Sidebar.
  nav = CreateFrame("Frame", nil, frame)
  nav:SetPoint("TOPLEFT", 10, TOP)
  nav:SetPoint("BOTTOMLEFT", 10, 10)
  nav:SetWidth(NAV_W)
  UI.Fill(nav, 0, 0, 0, 0.35)
  UI.Border(nav, 1, 1, 1, 0.08)
  local version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version")
  local ver = UI.Text(nav, "Agentcraft " .. (version or ""), "GameFontDisableSmall")
  ver:SetPoint("BOTTOM", 0, 8)

  -- Page area and footer.
  body = CreateFrame("Frame", nil, frame)
  body:SetPoint("TOPLEFT", nav, "TOPRIGHT", 14, -6)
  body:SetPoint("BOTTOMRIGHT", -16, 48)

  footer = CreateFrame("Frame", nil, frame)
  footer:SetPoint("BOTTOMLEFT", nav, "BOTTOMRIGHT", 12, 0)
  footer:SetPoint("BOTTOMRIGHT", -14, 10)
  footer:SetHeight(30)
  local rule = footer:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(1, 0.82, 0, 0.2)
  rule:SetHeight(1)
  rule:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 4)
  rule:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 4)
  status = UI.Text(footer, "", "GameFontHighlightSmall")
  status:SetPoint("LEFT", 2, 0)
  status:SetJustifyH("LEFT")
  status:SetWordWrap(false)

  table.sort(ns.pages, function(a, b) return (a.order or 500) < (b.order or 500) end)
  for i, page in ipairs(ns.pages) do NavButton(page, i) end

  -- Keep the open page current while you play.
  local pending
  for _, ev in ipairs({ "ACTIONBAR_SLOT_CHANGED", "UPDATE_BINDINGS", "BAG_UPDATE_DELAYED",
                        "SPELLS_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PET_BAR_UPDATE" }) do
    pcall(frame.RegisterEvent, frame, ev)
  end
  frame:SetScript("OnEvent", function()
    if pending or not frame:IsShown() then return end
    pending = true
    C_Timer.After(0.2, function()
      pending = false
      if frame:IsShown() then Refresh() end
    end)
  end)
  frame:HookScript("OnShow", Refresh)

  if ns.pages[1] then Select(ns.pages[1]) end
end

ns.UI.Refresh = function() if frame and frame:IsShown() then Refresh() end end
ns.UI.RunAction = RunAction

function ns.ToggleUI()
  if not frame then Build(); frame:Show(); return end
  frame:SetShown(not frame:IsShown())
end

function ns.OpenPage(id)
  if not frame then Build() end
  frame:Show()
  for _, page in ipairs(ns.pages) do
    if page.id == id then return Select(page) end
  end
end

ns.RegisterCommand("help", "list slash commands", function()
  ns.Print("commands (/ac alone opens the window):")
  local names = {}
  for name in pairs(ns.commands) do table.insert(names, name) end
  table.sort(names)
  for _, name in ipairs(names) do
    ns.Out("  /ac " .. name .. " - " .. ns.commands[name].help)
  end
end)
