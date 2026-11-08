-- Template for a new module. Copy this file, rename it, and add it to
-- TinkerKit.toc (above UI\Window.lua). This file itself is never loaded.
local _, ns = ...
local UI = ns.UI
local M = ns.RegisterModule("Example", {
  description = "what this module does",
  enabled = false,                    -- off until ticked in Settings
  defaults = { greeting = "Hello" },  -- account-wide settings -> self.db
  charDefaults = { count = 0 },       -- per-character settings -> self.charDB
})

M.events = {
  PLAYER_ENTERING_WORLD = function(self)
    self.charDB.count = self.charDB.count + 1
  end,
}

function M:OnEnable() end
function M:OnDisable() end

-- Optional: a page in the /tk window (sidebar entry + footer buttons).
ns.RegisterPage({
  id = "example",
  title = "Example",
  icon = "Interface\\Icons\\INV_Misc_Gift_01",
  order = 100,
  Build = function(page, f)
    UI.Header(f, "Hello", 0, 0, 590)
    page.text = UI.Text(f, "", "GameFontHighlight")
    page.text:SetPoint("TOPLEFT", 0, -24)
  end,
  Refresh = function(page)
    page.text:SetText("Seen " .. M.charDB.count .. " times")
  end,
  Status = function() return "everything fine" end,
  actions = {
    { label = "Say hi", fn = function() ns.Print(M.db.greeting) end, tooltip = "Prints a greeting." },
  },
})

-- Optional: a slash command, /tk example
ns.RegisterCommand("example", "say hello", function(args)
  ns.Print(M.db.greeting .. " " .. args)
end)
