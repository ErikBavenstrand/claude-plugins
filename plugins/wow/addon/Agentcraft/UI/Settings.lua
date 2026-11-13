-- Settings page: module on/off, small tool buttons (ns.RegisterAction) and
-- the log of everything Agentcraft printed (selectable, Ctrl+C to copy).
local _, ns = ...
local UI = ns.UI
local WIDTH = 600

ns.RegisterPage({
  id = "settings",
  title = "Settings",
  icon = "Interface\\Icons\\Trade_Engineering",
  order = 1000,

  Build = function(page, f)
    UI.Header(f, "Modules", 0, 0, WIDTH)
    local y = -20
    page.checks = {}
    for _, mod in ipairs(ns.order) do
      local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
      cb:SetSize(24, 24)
      cb:SetPoint("TOPLEFT", -3, y)
      local name = UI.Text(cb, mod.name, "GameFontHighlight")
      name:SetPoint("LEFT", cb, "RIGHT", 4, 0)
      name:SetWidth(100)
      name:SetJustifyH("LEFT")
      local desc = UI.Text(cb, mod.description or "", "GameFontDisableSmall")
      desc:SetPoint("LEFT", name, "RIGHT", 8, 0)
      cb:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        -- RunAction logs the result, catches errors and refreshes the header
        -- count and the checkbox (back to off if the module failed to start).
        UI.RunAction(function()
          if ns.SetModuleEnabled(mod, on) then ns.Print(mod.name .. (on and " enabled" or " disabled")) end
        end)
      end)
      cb.mod = mod
      table.insert(page.checks, cb)
      y = y - 24
    end

    if #ns.actions > 0 then
      y = y - 12
      UI.Header(f, "Tools", 0, y, WIDTH)
      y = y - 22
      local x = 0
      for _, a in ipairs(ns.actions) do
        local label = a.section .. ": " .. a.label
        local b = UI.Button(f, label, 150, function() UI.RunAction(a.fn) end, a.tooltip)
        b:SetPoint("TOPLEFT", x, y)
        x = x + 156
      end
      y = y - 32
    end

    y = y - 8
    UI.Header(f, "Log  |cff999999newest first, select and Ctrl+C to copy|r", 0, y, WIDTH)
    y = y - 22
    local bg = CreateFrame("Frame", nil, f)
    bg:SetPoint("TOPLEFT", 0, y)
    bg:SetPoint("BOTTOMRIGHT", 0, 0)
    UI.Fill(bg, 0, 0, 0, 0.35)
    UI.Border(bg, 1, 1, 1, 0.08)

    local scroll = CreateFrame("ScrollFrame", "AgentcraftLogScroll", bg, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    local log = CreateFrame("EditBox", nil, scroll)
    log:SetMultiLine(true)
    log:SetAutoFocus(false)
    log:SetFontObject(ChatFontNormal)
    log:SetWidth(WIDTH - 40)
    log:SetScript("OnEscapePressed", log.ClearFocus)
    -- Read-only: undo typing, but allow selecting and copying.
    log:SetScript("OnTextChanged", function(self, userInput)
      if userInput then self:SetText(self.stored or "") end
    end)
    scroll:SetScrollChild(log)
    page.log = log
  end,

  Refresh = function(page)
    for _, cb in ipairs(page.checks) do cb:SetChecked(cb.mod.active) end
    local lines = {}
    for i = #ns.log, 1, -1 do lines[#lines + 1] = ns.log[i] end
    page.log.stored = #lines > 0 and table.concat(lines, "\n\n") or "Nothing yet. Results from Apply and Undo show up here."
    page.log:SetText(page.log.stored)
    page.log:SetCursorPosition(0)
  end,

  Status = function()
    local on = 0
    for _, mod in ipairs(ns.order) do if mod.active then on = on + 1 end end
    return on .. " of " .. #ns.order .. " modules on"
  end,

  actions = {
    { label = "Clear log", fn = function() wipe(ns.log) end, tooltip = "Empty the log below." },
  },
})
