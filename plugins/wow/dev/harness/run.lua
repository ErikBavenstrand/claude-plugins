-- Test runner (Lua 5.1 / LuaJIT).
--   lua5.1 dev/harness/run.lua <addonDir> <testsDir> [filter]
-- Loads every *.lua in testsDir (sorted). A test file calls the global
-- test(name, fn); fn fails by raising an error (use the helpers below).
-- Exit code 0 when every test passes, 1 otherwise.
local addonDir, testsDir, filter = arg[1], arg[2], arg[3]
assert(addonDir and testsDir, "usage: run.lua <addonDir> <testsDir> [filter]")

local here = (arg[0]:gsub("\\", "/"):match("^(.*)/[^/]*$")) or "."
package.path = here .. "/?.lua;" .. package.path
addonDir = addonDir:gsub("\\", "/"):gsub("/$", "")
testsDir = testsDir:gsub("\\", "/"):gsub("/$", "")

local H = require("harness")
H.addonDir = addonDir
H.harnessDir = here

-- Assertions ------------------------------------------------------------------

local function Show(v)
  if type(v) == "string" then return string.format("%q", v) end
  return tostring(v)
end

function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg and (msg .. ": ") or "") .. "expected " .. Show(expected) .. ", got " .. Show(actual), 2)
  end
end

function ok(value, msg)
  if not value then error(msg or "expected a true value", 2) end
  return value
end

function fail(msg) error(msg, 2) end

-- Lists every call recorded under `name` as text, for failure messages.
function describeCalls(env, name)
  local lines = {}
  for _, c in ipairs(env:calls(name)) do
    local parts = {}
    for i = 1, c.n do parts[i] = Show(c[i]) end
    lines[#lines + 1] = "    " .. name .. "(" .. table.concat(parts, ", ") .. ")"
  end
  return table.concat(lines, "\n")
end

-- Fails if the env collected Lua errors from event handlers or timers.
function noErrors(env)
  if #env.W.errors > 0 then error("Lua errors during the run:\n" .. table.concat(env.W.errors, "\n"), 2) end
end

-- Registry ------------------------------------------------------------------

local tests = {}
local currentFile
function test(name, fn) tests[#tests + 1] = { name = name, fn = fn, file = currentFile } end

-- Prints a note under the current test (warnings the owner should see).
local notes = {}
function note(text) notes[#notes + 1] = text end

local function ListTests(dir)
  local cmd
  if package.config:sub(1, 1) == "\\" then cmd = 'dir /b /on "' .. dir:gsub("/", "\\") .. '\\*.lua" 2>nul'
  else cmd = 'ls -1 "' .. dir .. '"/*.lua 2>/dev/null' end
  local files = {}
  local p = io.popen(cmd)
  if p then
    for line in p:lines() do
      local name = line:match("([^/\\]+%.lua)$")
      if name then files[#files + 1] = name end
    end
    p:close()
  end
  table.sort(files)
  return files
end

for _, file in ipairs(ListTests(testsDir)) do
  currentFile = file
  local chunk, err = loadfile(testsDir .. "/" .. file)
  if not chunk then
    tests[#tests + 1] = { name = "load " .. file, file = file, fn = function() error(err, 0) end }
  else
    local okLoad, loadErr = pcall(chunk)
    if not okLoad then tests[#tests + 1] = { name = "load " .. file, file = file, fn = function() error(loadErr, 0) end } end
  end
end

-- Run -------------------------------------------------------------------------

local passed, failed = 0, 0
local lastFile
for _, t in ipairs(tests) do
  if not filter or t.name:find(filter, 1, true) or t.file:find(filter, 1, true) then
    if t.file ~= lastFile then print(t.file); lastFile = t.file end
    notes = {}
    local okRun, err = xpcall(t.fn, debug.traceback)
    if okRun then
      passed = passed + 1
      print("  PASS  " .. t.name)
    else
      failed = failed + 1
      print("  FAIL  " .. t.name)
      print("        " .. tostring(err):gsub("\n", "\n        "))
    end
    for _, n in ipairs(notes) do print("        note: " .. n) end
  end
end

-- APIs the addon touched that the mock doesn't know: candidates for wow.lua.
local counts = H.Unknown()
local unknown = {}
for name in pairs(counts) do unknown[#unknown + 1] = name end
table.sort(unknown)
if #unknown > 0 then
  print("")
  print("Auto-stubbed APIs (not mocked: calls returned nil, reads got a stub). Add the ones a test needs to harness/wow.lua:")
  for _, name in ipairs(unknown) do
    print("  " .. name .. (counts[name] > 0 and ("  (called " .. counts[name] .. "x)") or "  (read only)"))
  end
end

print("")
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed > 0 and 1 or 0)
