<#
.SYNOPSIS
  Offline dev kit for the Agentcraft addon: check changes before you /reload.
.DESCRIPTION
  Commands:
    check     run everything below that can run; tools that are missing are skipped
    toc       Agentcraft.toc: files exist, every .lua is listed, Version and load order
    rules     the owner's macro and layout rules, statically (PowerShell only), plus a
              read-only look at the live game's keybinds and macros when the game is found
    lint      luacheck with ../.luacheckrc (needs luacheck)
    test      Lua 5.1 harness: loads the addon against a WoW API mock and runs dev/tests/*.lua
              (needs lua5.1, lua51 or luajit)
    types     lua-language-server --check with ../.luarc.json (needs LuaLS)
    globals   list the globals the addon reads and writes (to maintain .luacheckrc)
  Exit codes: 0 pass, 1 findings or failures, 2 a needed tool is missing (skipped).
  Needs only Windows PowerShell 5.1 for toc, rules and globals.
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File dev.ps1 check
#>
param(
  [Parameter(Position = 0)][string]$Command = 'check',
  [string]$Addon,
  [string]$WowPath,
  [switch]$NoGame,   # rules: skip the live game section
  [switch]$Strict    # rules: warnings fail too
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
try { [Console]::OutputEncoding = $utf8 } catch {}

$DevDir = $PSScriptRoot
$WowDir = Split-Path $DevDir
if (-not $Addon) { $Addon = Join-Path $WowDir 'addon\Agentcraft' }
$Addon = (Resolve-Path -LiteralPath $Addon).Path

function Say([string]$text) { [Console]::Out.WriteLine($text) }
function ReadText([string]$file) { return [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8) }
function Rel([string]$full) {
  if ($full.StartsWith($Addon, [StringComparison]::OrdinalIgnoreCase)) { return $full.Substring($Addon.Length).TrimStart('\', '/') }
  return $full
}

# ---------------------------------------------------------------------------
# Lua literal reader. Reads table constructors (Layout.lua, L.Add({...})) from
# Lua source. Comments and string contents are blanked in a "code" copy of the
# text (same length), so structure is found there and strings are read from
# the original. Anything that isn't a literal comes back as a [LuaExpr].

class LuaExpr {
  [string]$Text
  LuaExpr([string]$t) { $this.Text = $t }
  [string] ToString() { return "<expr $($this.Text)>" }
}

class LuaTable {
  [System.Collections.ArrayList]$Arr
  [System.Collections.Specialized.OrderedDictionary]$Hash
  [int]$Line
  LuaTable([int]$line) {
    $this.Arr = New-Object System.Collections.ArrayList
    $this.Hash = New-Object System.Collections.Specialized.OrderedDictionary
    $this.Line = $line
  }
  [object] Get([string]$k) { if ($this.Hash.Contains($k)) { return $this.Hash[$k] } return $null }
  [bool] Has([string]$k) { return $this.Hash.Contains($k) }
  # Array part as strings only (spell names in a layout entry).
  [string[]] Strings() {
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($v in $this.Arr) { if ($v -is [string]) { $out.Add($v) } }
    return $out.ToArray()
  }
}

class LuaLit {
  [string]$s
  [string]$code
  [int]$i
  [int]$n
  [int[]]$lineStarts

  static [regex]$Strip = [regex]'--\[(=*)\[[\s\S]*?\]\1\]|--[^\n]*|"(?:[^"\\\n]|\\[\s\S])*"|''(?:[^''\\\n]|\\[\s\S])*''|\[(=*)\[[\s\S]*?\]\2\]'
  static [regex]$Num = [regex]'\G-?(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)'
  static [regex]$Name = [regex]'\G[A-Za-z_][A-Za-z0-9_]*(?:[.:][A-Za-z_][A-Za-z0-9_]*)*'
  static [regex]$Assign = [regex]'\G([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)'

  LuaLit([string]$text) {
    $this.s = $text -replace "`r`n", "`n"
    $this.n = $this.s.Length
    $this.i = 0
    $this.code = [LuaLit]::StripText($this.s)
    $starts = New-Object System.Collections.Generic.List[int]
    $starts.Add(0)
    for ($k = $this.s.IndexOf("`n"); $k -ge 0; $k = $this.s.IndexOf("`n", $k + 1)) { $starts.Add($k + 1) }
    $this.lineStarts = $starts.ToArray()
  }

  # Comments become spaces; every string becomes "   " of the same length.
  static [string] StripText([string]$t) {
    $ev = [System.Text.RegularExpressions.MatchEvaluator] {
      param($m)
      $v = $m.Value
      $blank = [regex]::Replace($v, '[^\n]', ' ')
      if ($v.StartsWith('--')) { return $blank }
      $chars = $blank.ToCharArray()
      $chars[0] = '"'
      $chars[$chars.Length - 1] = '"'
      return -join $chars
    }
    return [LuaLit]::Strip.Replace($t, $ev)
  }

  [int] LineAt([int]$offset) {
    $lo = 0; $hi = $this.lineStarts.Length - 1
    while ($lo -lt $hi) {
      $mid = [int][Math]::Floor(($lo + $hi + 1) / 2)
      if ($this.lineStarts[$mid] -le $offset) { $lo = $mid } else { $hi = $mid - 1 }
    }
    return $lo + 1
  }

  [void] Skip() {
    while ($this.i -lt $this.n -and [char]::IsWhiteSpace($this.code[$this.i])) { $this.i++ }
  }

  [void] Expect([char]$ch) {
    $this.Skip()
    if ($this.i -ge $this.n -or $this.code[$this.i] -ne $ch) { throw "expected '$ch' at line $($this.LineAt($this.i))" }
    $this.i++
  }

  # Skips to the next , ; } ) ] at depth 0 and returns what was skipped.
  [LuaExpr] SkipExpr() {
    $start = $this.i
    $depth = 0
    while ($this.i -lt $this.n) {
      $c = $this.code[$this.i]
      if ($c -eq '(' -or $c -eq '{' -or $c -eq '[') { $depth++ }
      elseif ($c -eq ')' -or $c -eq '}' -or $c -eq ']') {
        if ($depth -eq 0) { break }
        $depth--
      }
      elseif (($c -eq ',' -or $c -eq ';') -and $depth -eq 0) { break }
      $this.i++
    }
    return [LuaExpr]::new($this.s.Substring($start, $this.i - $start).Trim())
  }

  static [string] Unescape([string]$raw) {
    $ev = [System.Text.RegularExpressions.MatchEvaluator] {
      param($m)
      $d = $m.Groups[1].Value
      switch -CaseSensitive ($d) {
        'n' { return "`n" }
        't' { return "`t" }
        'r' { return "`r" }
        'a' { return [string][char]7 }
        "`n" { return "`n" }
      }
      if ($d -match '^\d+$') { return [string][char][int]$d }
      return $d
    }
    return [regex]::Replace($raw, '\\(\d{1,3}|[\s\S])', $ev)
  }

  [string] Str() {
    $start = $this.i
    $end = $this.code.IndexOf('"', $start + 1)
    if ($end -lt 0) { throw "unterminated string at line $($this.LineAt($start))" }
    $this.i = $end + 1
    $q = $this.s[$start]
    if ($q -eq '"' -or $q -eq "'") { return [LuaLit]::Unescape($this.s.Substring($start + 1, $end - $start - 1)) }
    # Long string [[...]] / [==[...]==]
    $open = [regex]::Match($this.s.Substring($start), '^\[=*\[')
    $len = $open.Length
    $body = $this.s.Substring($start + $len, ($end + 1 - $len) - ($start + $len))
    if ($body.StartsWith("`n")) { $body = $body.Substring(1) }
    return $body
  }

  [object] Value() {
    $this.Skip()
    if ($this.i -ge $this.n) { throw 'unexpected end of file' }
    $start = $this.i
    $c = $this.code[$this.i]
    $v = $null
    if ($c -eq '{') { $v = $this.Table() }
    elseif ($c -eq '"') {
      $v = $this.Str()
      $this.Skip()
      while ($this.i + 1 -lt $this.n -and $this.code.Substring($this.i, 2) -eq '..' -and $this.code[$this.i + 2] -ne '.') {
        $this.i += 2
        $more = $this.Value()
        if ($more -is [string]) { $v = $v + $more } else { $v = [LuaExpr]::new($this.s.Substring($start, $this.i - $start)); break }
        $this.Skip()
      }
    }
    else {
      $m = [LuaLit]::Num.Match($this.code, $this.i)
      if ($m.Success) {
        $this.i += $m.Length
        $v = [double]::Parse(($m.Value -replace '^-?0[xX].*$', '0'), [Globalization.CultureInfo]::InvariantCulture)
        if ($m.Value -match '^-?0[xX]') { $v = [double][Convert]::ToInt64(($m.Value -replace '^-?0[xX]', ''), 16) }
      } else {
        $m = [LuaLit]::Name.Match($this.code, $this.i)
        if ($m.Success) {
          $this.i += $m.Length
          if ($m.Value -eq 'true') { $v = $true }
          elseif ($m.Value -eq 'false') { $v = $false }
          elseif ($m.Value -eq 'nil') { $v = $null }
          else { $v = [LuaExpr]::new($m.Value) }
        } else {
          return $this.SkipExpr()
        }
      }
    }
    # Anything else before the separator makes it an expression.
    $this.Skip()
    if ($this.i -lt $this.n -and ',;})]'.IndexOf($this.code[$this.i]) -lt 0) {
      $this.i = $start
      return $this.SkipExpr()
    }
    return $v
  }

  [LuaTable] Table() {
    $t = [LuaTable]::new($this.LineAt($this.i))
    $this.i++
    while ($true) {
      $this.Skip()
      if ($this.i -ge $this.n) { throw "unterminated table from line $($t.Line)" }
      $c = $this.code[$this.i]
      if ($c -eq '}') { $this.i++; break }
      if ($c -eq '[') {
        $this.i++
        $k = $this.Value()
        $this.Expect([char]']')
        $this.Expect([char]'=')
        $key = [string]$k
        $t.Hash[$key] = $this.Value()
      } else {
        $m = [LuaLit]::Assign.Match($this.code, $this.i)
        if ($m.Success) {
          $this.i += $m.Length
          $t.Hash[$m.Groups[1].Value] = $this.Value()
        } else {
          [void]$t.Arr.Add($this.Value())
        }
      }
      $this.Skip()
      if ($this.i -lt $this.n -and ($this.code[$this.i] -eq ',' -or $this.code[$this.i] -eq ';')) { $this.i++ }
    }
    return $t
  }

  # Every table constructor that follows a match of $pattern (which must end
  # right before the "{"), as a list of LuaTable.
  [System.Collections.ArrayList] Tables([string]$pattern) {
    $out = New-Object System.Collections.ArrayList
    foreach ($m in [regex]::Matches($this.code, $pattern)) {
      $this.i = $m.Index + $m.Length
      $this.Skip()
      if ($this.i -lt $this.n -and $this.code[$this.i] -eq '{') { [void]$out.Add($this.Table()) }
    }
    return $out
  }
}

# ---------------------------------------------------------------------------
# Findings

$script:Findings = New-Object System.Collections.ArrayList

function Add-Finding([string]$Severity, [string]$Rule, [string]$Where, [string]$Message) {
  [void]$script:Findings.Add([pscustomobject]@{ Severity = $Severity; Rule = $Rule; Where = $Where; Message = $Message })
}

function Write-Findings([string]$title) {
  $order = @{ ERROR = 0; WARN = 1; INFO = 2 }
  # "File.lua:48" sorts before "File.lua:164": file name, then line number.
  $list = @($script:Findings | Sort-Object @{ e = { $order[$_.Severity] } },
    @{ e = { $_.Where -replace ':\d+$', '' } },
    @{ e = { if ($_.Where -match ':(\d+)$') { [int]$Matches[1] } else { 0 } } })
  Say ""
  Say "== $title =="
  if ($list.Count -eq 0) { Say "  no findings" }
  foreach ($f in $list) {
    Say ("{0,-5} [{1}] {2}" -f $f.Severity, $f.Rule, $f.Where)
    Say ("      {0}" -f $f.Message)
  }
  $e = @($list | Where-Object Severity -eq 'ERROR').Count
  $w = @($list | Where-Object Severity -eq 'WARN').Count
  $n = @($list | Where-Object Severity -eq 'INFO').Count
  Say ""
  Say "$title`: $e error(s), $w warning(s), $n info"
  $failed = $e -gt 0 -or ($Strict -and $w -gt 0)
  $script:Findings.Clear()
  if ($failed) { return 1 }
  return 0
}

# ---------------------------------------------------------------------------
# toc

function Read-Toc {
  $tocFile = Get-ChildItem -LiteralPath $Addon -Filter '*.toc' | Select-Object -First 1
  if (-not $tocFile) { throw "no .toc in $Addon" }
  $meta = [ordered]@{}
  $files = New-Object System.Collections.Generic.List[object]
  $lineNo = 0
  foreach ($line in [IO.File]::ReadAllLines($tocFile.FullName, [Text.Encoding]::UTF8)) {
    $lineNo++
    $t = $line.Trim()
    if ($t -eq '') { continue }
    if ($t -match '^##\s*([^:]+?)\s*:\s*(.*)$') { $meta[$Matches[1]] = @{ Value = $Matches[2].Trim(); Line = $lineNo }; continue }
    if ($t.StartsWith('#')) { continue }
    $files.Add([pscustomobject]@{ Path = $t; Line = $lineNo })
  }
  return [pscustomobject]@{ File = $tocFile; Meta = $meta; Files = $files }
}

function Cmd-Toc {
  $toc = Read-Toc
  $tocName = $toc.File.Name
  $listed = @{}
  $index = @{}
  $pos = 0
  foreach ($f in $toc.Files) {
    $where = "${tocName}:$($f.Line)"
    $norm = $f.Path -replace '/', '\'
    $key = $norm.ToLowerInvariant()
    if ($listed.ContainsKey($key)) { Add-Finding ERROR toc-duplicate $where "$($f.Path) is listed twice" }
    $listed[$key] = $f
    $index[$key] = $pos++
    if ($norm.IndexOfAny([IO.Path]::GetInvalidPathChars()) -ge 0 -or $norm -match '[\x00-\x1f]') {
      Add-Finding ERROR toc-path $where "line has characters that can't be in a file name: '$($f.Path)'"
      continue
    }
    $full = Join-Path $Addon $norm
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
      Add-Finding ERROR toc-missing $where "$($f.Path) is listed but does not exist"
      continue
    }
    # Exact case: the game is case-insensitive on Windows but not on every OS.
    $dir = Split-Path $full
    $leaf = Split-Path $full -Leaf
    $actual = (Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Name -ieq $leaf } | Select-Object -First 1).Name
    if ($actual -cne $leaf) { Add-Finding WARN toc-case $where "$($f.Path) is '$actual' on disk" }
    # Every file reads the addon varargs.
    $head = (ReadText $full) -split "`n" | Where-Object { $_ -notmatch '^\s*(--.*)?\s*$' } | Select-Object -First 1
    if ($full -like '*.lua' -and $head -notmatch '^local\s+[A-Za-z_]+\s*,\s*ns\s*=\s*\.\.\.') {
      Add-Finding WARN toc-header $where "$($f.Path): first code line is not 'local ADDON, ns = ...' (got: $head)"
    }
  }

  foreach ($lua in Get-ChildItem -LiteralPath $Addon -Recurse -File -Filter '*.lua') {
    $rel = Rel $lua.FullName
    if (-not $listed.ContainsKey($rel.ToLowerInvariant())) {
      if ($lua.Name.StartsWith('_')) { Add-Finding INFO toc-unlisted $rel "not in the TOC (an underscore file: a template, never loaded; fine if intended)" }
      else { Add-Finding ERROR toc-unlisted $rel "not in the TOC, so the game never loads it" }
    }
  }

  # Metadata.
  $ver = $toc.Meta['Version']
  if (-not $ver) { Add-Finding ERROR toc-version $tocName "no '## Version:' line" }
  elseif ($ver.Value -notmatch '^\d+\.\d+\.\d+$') { Add-Finding ERROR toc-version "${tocName}:$($ver.Line)" "Version '$($ver.Value)' is not MAJOR.MINOR.PATCH" }
  else { Add-Finding INFO toc-version "${tocName}:$($ver.Line)" "Version $($ver.Value)" }
  $iface = $toc.Meta['Interface']
  if (-not $iface) { Add-Finding ERROR toc-interface $tocName "no '## Interface:' line" }
  else {
    foreach ($v in ($iface.Value -split ',')) {
      if ($v.Trim() -notmatch '^\d{5,6}$') { Add-Finding ERROR toc-interface "${tocName}:$($iface.Line)" "Interface value '$($v.Trim())' is not a 5-6 digit build number" }
    }
    if ($iface.Value -notmatch '\b12\d{4}\b') { Add-Finding WARN toc-interface "${tocName}:$($iface.Line)" "no 12xxxx Interface value; the WoW Forever client is 12.x and may list the addon as out of date" }
  }
  foreach ($sv in 'SavedVariables', 'SavedVariablesPerCharacter') {
    if (-not $toc.Meta[$sv]) { Add-Finding WARN toc-savedvars $tocName "no '## ${sv}:' line" }
  }
  if ($toc.Meta['SavedVariables'] -and $toc.Meta['SavedVariables'].Value -ne 'AgentcraftDB') { Add-Finding ERROR toc-savedvars $tocName "SavedVariables is '$($toc.Meta['SavedVariables'].Value)'; Core.lua uses AgentcraftDB" }
  if ($toc.Meta['SavedVariablesPerCharacter'] -and $toc.Meta['SavedVariablesPerCharacter'].Value -ne 'AgentcraftCharDB') { Add-Finding ERROR toc-savedvars $tocName "SavedVariablesPerCharacter is '$($toc.Meta['SavedVariablesPerCharacter'].Value)'; Core.lua uses AgentcraftCharDB" }

  # Load order the code depends on.
  function Pos([string]$p) { $k = $p.ToLowerInvariant(); if ($index.ContainsKey($k)) { return $index[$k] } return $null }
  $order = @(
    @('Core.lua', '*', 'Core.lua must load first: it creates ns.RegisterModule and the event frame'),
    @('UI\Widgets.lua', 'Modules\Controller.lua', 'Controller reads ns.UI at load time'),
    @('Modules\Snapshot.lua', 'Modules\SnapshotMore.lua', 'SnapshotMore reads ns.modules.snapshot at load time'),
    @('Modules\Snapshot.lua', 'Modules\SnapshotCached.lua', 'SnapshotCached reads ns.modules.snapshot at load time'),
    @('Macros\Library.lua', 'Macros\Page.lua', 'Page uses ns.MacroLibrary')
  )
  foreach ($o in $order) {
    $a = Pos $o[0]
    if ($null -eq $a) { continue }
    if ($o[1] -eq '*') { if ($a -ne 0) { Add-Finding ERROR toc-order $tocName $o[2] }; continue }
    $b = Pos $o[1]
    if ($null -ne $b -and $a -gt $b) { Add-Finding ERROR toc-order $tocName "$($o[0]) loads after $($o[1]): $($o[2])" }
  }
  $lib = Pos 'Macros\Library.lua'; $page = Pos 'Macros\Page.lua'; $window = Pos 'UI\Window.lua'
  foreach ($f in $toc.Files) {
    $p = $f.Path -replace '/', '\'
    $k = Pos $p
    if ($p -like 'Macros\Data\*') {
      if ($null -ne $lib -and $k -lt $lib) { Add-Finding ERROR toc-order "${tocName}:$($f.Line)" "$p loads before Macros\Library.lua (L.Add would be nil)" }
      if ($null -ne $page -and $k -gt $page) { Add-Finding WARN toc-order "${tocName}:$($f.Line)" "$p loads after Macros\Page.lua; data files go above it" }
    }
    if ($null -ne $window -and $k -gt $window -and $p -notlike 'UI\*') { Add-Finding WARN toc-order "${tocName}:$($f.Line)" "$p loads after UI\Window.lua; new files go above it" }
  }
  # Every macro data file on disk is listed (caught above too, but say why it matters).
  return Write-Findings 'toc'
}

# ---------------------------------------------------------------------------
# rules: macro library

$ItemCommands = @('/use', '/equip', '/equipslot', '/userandom')
$MenuCommands = @{
  '/camp' = 'logout is in the game menu'; '/logout' = 'logout is in the game menu'; '/quit' = 'quit is in the game menu'
  '/exit' = 'quit is in the game menu'; '/readycheck' = 'ready check is in the group menu'; '/screenshot' = 'Steam and the game take screenshots'
  '/map' = 'the map has its own key and menu'; '/repair' = 'the vendor window repairs'
}
$MenuRun = 'ToggleWorldMap|RepairAllItems|Screenshot\s*\(|Logout\s*\(|Quit\s*\(|DoReadyCheck|UseContainerItem|SellAllJunk|ChatFrame_OpenChat|cameraDistanceMax'

# "[cond] a; [cond] b" -> @('a', 'b'), conditions removed.
function Get-Targets([string]$argText) {
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($part in ($argText -split ';')) {
    $t = ([regex]::Replace($part, '\[[^\]]*\]', '')).Trim()
    if ($t.StartsWith('!')) { $t = $t.Substring(1).Trim() }
    if ($t -ne '') { $out.Add($t) }
  }
  return $out.ToArray()
}

# "/castsequence [cond] reset=5 A, B" arguments -> "A; B" (conditions dropped first,
# since they contain commas too).
function Split-List([string]$argText) {
  $t = [regex]::Replace($argText, '\[[^\]]*\]', '')
  $t = [regex]::Replace($t, 'reset=\S+', '')
  return ($t -replace ',', ';')
}

function Read-Macros {
  $macros = New-Object System.Collections.Generic.List[object]
  $retired = @{}
  $dataDir = Join-Path $Addon 'Macros\Data'
  foreach ($file in Get-ChildItem -LiteralPath $dataDir -Filter '*.lua' | Sort-Object Name) {
    $rel = Rel $file.FullName
    $lit = [LuaLit]::new((ReadText $file.FullName))
    foreach ($t in $lit.Tables('\bL\.Add\s*\(\s*(?=\{)')) {
      $name = $t.Get('name'); $body = $t.Get('body')
      if ($body -isnot [string]) { Add-Finding ERROR macro-parse "${rel}:$($t.Line)" "macro '$name' has no plain string body; the checker can't read it"; continue }
      $macros.Add([pscustomobject]@{ Name = [string]$name; Body = $body; File = $rel; Line = $t.Line; T = $t
        Class = $t.Get('class'); Race = $t.Get('race'); Untested = ($t.Get('untested') -eq $true) })
    }
    foreach ($t in $lit.Tables('\bL\.retired\s*=\s*(?=\{)')) {
      foreach ($k in $t.Hash.Keys) { $retired[[string]$k] = @{ Body = $t.Hash[$k]; Where = "${rel}:$($t.Line)" } }
    }
  }
  return [pscustomobject]@{ Macros = $macros; Retired = $retired }
}

# Item names the addon itself knows (ActionBars utility lists, Layout items):
# a /cast of one of these is an item in disguise.
function Read-ItemNames {
  $names = @{}
  $ab = Join-Path $Addon 'Modules\ActionBars.lua'
  if (Test-Path -LiteralPath $ab) {
    $lit = [LuaLit]::new((ReadText $ab))
    foreach ($t in $lit.Tables('\bM\.utility\s*=\s*(?=\{)')) {
      foreach ($e in $t.Arr) { if ($e -is [LuaTable]) { foreach ($s in $e.Strings()) { $names[$s] = $true } } }
    }
  }
  foreach ($n in 'Hearthstone', 'Shiny Bauble', 'Nightcrawlers', 'Bright Baubles', 'Aquadynamic Fish Attractor') { $names[$n] = $true }
  return $names
}

function Test-Macro($m, $items) {
  $where = "$($m.File):$($m.Line)"
  $label = "'$($m.Name)'"
  $fishItems = New-Object System.Collections.Generic.List[string]
  if ($m.Name.Length -gt 16) { Add-Finding ERROR macro-name $where "$label is longer than 16 characters (L.Add asserts)" }
  $bytes = [Text.Encoding]::UTF8.GetByteCount($m.Body)
  if ($bytes -gt 255) { Add-Finding ERROR macro-length $where "$label body is $bytes characters; the game limit is 255" }
  $lines = $m.Body -split "`n"
  if (-not $lines[0].StartsWith('#showtooltip')) { Add-Finding INFO macro-showtooltip $where "$label doesn't start with #showtooltip (Library.lua convention; fine for pure slash-command macros)" }
  foreach ($line in $lines) {
    $t = $line.Trim()
    if ($t -eq '') { continue }
    if ($t -match '^#show(tooltip)?\s+(.+)$') {
      if ($items.ContainsKey($Matches[2].Trim())) { Add-Finding ERROR macro-item $where "$label shows item '$($Matches[2].Trim())' in #showtooltip" }
      continue
    }
    if ($t.StartsWith('#')) { continue }
    if ($t -notmatch '^(/\S+)\s*(.*)$') { Add-Finding WARN macro-syntax $where "$label line is not a slash command: $t"; continue }
    $cmd = $Matches[1].ToLowerInvariant(); $rest = $Matches[2]

    foreach ($cm in [regex]::Matches($rest, '\[([^\]]*)\]')) {
      foreach ($cond in ($cm.Groups[1].Value -split ',')) {
        $c = $cond.Trim().ToLowerInvariant()
        if ($c -match '^(no)?mod(ifier)?(:|$)') {
          if ($c -match 'alt' -and $c -notmatch 'shift|ctrl') { Add-Finding WARN macro-modifier $where "$label uses [$c] (Alt modifier; Shift/Ctrl are banned, Alt is the utility bar layer)" }
          else { Add-Finding ERROR macro-modifier $where "$label uses [$c]: no Shift/Ctrl modifier variants (they are bar layers)" }
        }
        elseif ($c -match '^@(mouseover|cursor)' -or $c -match '^target\s*=\s*(mouseover|cursor)') { Add-Finding ERROR macro-mouse $where "$label uses [$c]: no @mouseover/@cursor (a controller has no mouse)" }
        elseif ($c -match '^(no)?(btn|button)(:|$)') { Add-Finding WARN macro-mouse $where "$label uses [$c]: mouse-button conditions don't work from a controller" }
      }
    }

    if ($cmd -eq '/petpassive') { Add-Finding ERROR macro-petpassive $where "$label uses /petpassive (sticks after the fight; the pet stops defending you)" }
    elseif ($cmd -eq '/petattack') { Add-Finding ERROR macro-petattack $where "$label uses /petattack: the owner wants no /petattack in any macro" }
    elseif ($ItemCommands -contains $cmd) {
      foreach ($target in (Get-Targets $rest)) {
        $tg = $target
        if ($cmd -eq '/equipslot') { $tg = ($target -replace '^\d+\s*', '') }
        if ($tg -match '^\d+(\s+\d+)?$') { Add-Finding INFO macro-slot $where "$label $cmd $tg uses an inventory slot, not an item name (allowed)" }
        elseif ($m.Name -eq 'Fish' -and $cmd -eq '/equip') { $fishItems.Add($tg) }
        else { Add-Finding ERROR macro-item $where "$label $cmd $tg names an item; items go on bars as item buttons" }
      }
    }
    elseif ($cmd -eq '/equipset') { Add-Finding WARN macro-equipset $where "$label uses /equipset (latest rule: no equipment sets)" }
    elseif ($cmd -in '/cast', '/castsequence', '/castrandom') {
      $argText = $rest
      if ($cmd -eq '/castsequence' -or $cmd -eq '/castrandom') { $argText = Split-List $rest }
      foreach ($target in (Get-Targets $argText)) {
        if ($items.ContainsKey($target)) { Add-Finding ERROR macro-item $where "$label $cmd $target casts an item by name" }
      }
    }
    elseif ($MenuCommands.ContainsKey($cmd)) { Add-Finding ERROR macro-menu $where "$label uses $cmd ($($MenuCommands[$cmd]))" }
    elseif ($cmd -in '/run', '/script', '/dump', '/console') {
      if ($rest -match $MenuRun) { Add-Finding ERROR macro-menu $where "$label /run does what a game menu already does ($($Matches[0]))" }
    }
  }
  if ($fishItems.Count -gt 0) { Add-Finding INFO macro-item $where "$label /equip names $($fishItems.Count) items: $($fishItems -join ', ') (Fish exception approved by the owner)" }
  if ($m.Untested) { Add-Finding INFO macro-untested $where "$label is marked untested (needs an in-game confirmation)" }
}

# ---------------------------------------------------------------------------
# rules: layouts

$KbKeys = @('Q', 'E', 'R', 'T', 'F', 'G', 'C', 'V', '1', '2', '3', '4')
$PadKey = @{ L4 = 'F13'; L5 = 'F14'; R4 = 'F15'; R5 = 'F16' }

function Get-Bar($tbl, [int]$n) {
  $v = $tbl.Get([string]$n)
  if (-not $v) { $v = $tbl.Get("$n.0") }
  if (-not $v -and $tbl.Arr.Count -ge $n) { $v = $tbl.Arr[$n - 1] }
  return $v
}

# What an entry occupies, for the one-home check: its spells, plus your racial,
# an item or a utility slot (those can be placed twice too).
function Get-HomeNames($e) {
  $out = New-Object System.Collections.Generic.List[string]
  if ($e -isnot [LuaTable]) { return $out.ToArray() }
  foreach ($s in $e.Strings()) { $out.Add($s) }
  if ($e.Get('racial') -eq $true) { $out.Add('<racial>') }
  if ($e.Has('item')) { $out.Add("<item $($e.Get('item'))>") }
  if ($e.Has('utility')) { $out.Add("<utility $($e.Get('utility'))>") }
  return $out.ToArray()
}

# Spells a macro body casts (for the "also casts" note).
function Get-CastSpells([string]$body) {
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($line in ($body -split "`n")) {
    if ($line.Trim() -match '^/(cast|castsequence|castrandom)\s+(.*)$') {
      $argText = $Matches[2]
      if ($Matches[1] -ne 'cast') { $argText = Split-List $argText }
      foreach ($t in (Get-Targets $argText)) { $out.Add($t) }
    }
  }
  return $out.ToArray()
}

function Test-Entry($entry, [string]$class, [string]$device, [string]$where, [string]$label, $lib, $retired) {
  if ($entry -isnot [LuaTable]) { Add-Finding ERROR layout-entry $where "$label is not a table entry"; return }
  if ($device -eq 'keyboard') {
    foreach ($k in 'flyout', 'petauto', 'overflow') {
      if ($entry.Has($k)) { Add-Finding ERROR layout-keyboard $where "$label uses { $k = ... }: the keyboard layout is plain keybinds, no flyouts/controller-only entries" }
    }
  }
  $macro = $entry.Get('macro')
  if ($macro) {
    if (-not $lib.ContainsKey($macro)) {
      if ($retired.ContainsKey($macro)) { Add-Finding ERROR layout-macro $where "$label uses macro '$macro', which is retired (Apply deletes it)" }
      else { Add-Finding ERROR layout-macro $where "$label uses macro '$macro', which is not in the macro library" }
    } else {
      $m = $lib[$macro]
      if ($m.Class -and $m.Class -ne $class) { Add-Finding ERROR layout-macro $where "$label uses macro '$macro', a $($m.Class) macro, in the $class layout" }
      if ($m.Race) { Add-Finding WARN layout-macro $where "$label uses macro '$macro', which only fits race $($m.Race)" }
    }
    if ($entry.Strings().Count -eq 0 -and -not $entry.Get('covers')) {
      Add-Finding INFO layout-macro-only $where "$label is macro '$macro' only: empty (unbound) until the owner installs it"
    }
  }
}

function Test-Layout($lib, $retired) {
  $file = Join-Path $Addon 'Modules\Layout.lua'
  $rel = Rel $file
  $lit = [LuaLit]::new((ReadText $file))
  $kb = @($lit.Tables('\bL\.keyboard\s*=\s*(?=\{)'))
  $ct = @($lit.Tables('\bL\.controller\s*=\s*(?=\{)'))
  if ($kb.Count -eq 0) { Add-Finding ERROR layout-parse $rel "L.keyboard = { ... } not found" }
  if ($ct.Count -eq 0) { Add-Finding ERROR layout-parse $rel "L.controller = { ... } not found" }

  # Keyboard ---------------------------------------------------------------
  foreach ($kbt in $kb) {
    foreach ($class in $kbt.Hash.Keys) {
      $layout = $kbt.Hash[$class]
      $homes = @{}
      foreach ($bar in 1, 2) {
        $entries = Get-Bar $layout $bar
        if (-not $entries) { continue }
        if ($entries.Arr.Count -gt 12) { Add-Finding ERROR layout-keyboard "${rel}:$($entries.Line)" "$class keyboard bar $bar has $($entries.Arr.Count) entries; it has 12 keys" }
        if ($entries.Hash.Count -gt 0) { Add-Finding WARN layout-keyboard "${rel}:$($entries.Line)" "$class keyboard bar $bar has keyed entries ($($entries.Hash.Keys -join ', ')); only the 12-entry list is read" }
        for ($i = 0; $i -lt $entries.Arr.Count; $i++) {
          $e = $entries.Arr[$i]
          $key = $(if ($bar -eq 2) { 'Shift+' } else { '' }) + $KbKeys[$i]
          $where = "${rel}:$($e.Line)"
          Test-Entry $e $class 'keyboard' $where "$class keyboard $key" $lib $retired
          if ($e -is [LuaTable]) {
            foreach ($s in (Get-HomeNames $e)) {
              if (-not $homes.ContainsKey($s)) { $homes[$s] = New-Object System.Collections.Generic.List[string] }
              $homes[$s].Add("$key (line $($e.Line))")
            }
          }
        }
      }
      foreach ($s in $homes.Keys) {
        if ($homes[$s].Count -gt 1) { Add-Finding ERROR layout-two-homes "${rel}:$($layout.Line)" "$class keyboard: '$s' has $($homes[$s].Count) homes: $($homes[$s] -join ', ')" }
      }
      Test-MacroCasts $layout $class 'keyboard' $homes $lib $rel
    }
  }

  # Controller -------------------------------------------------------------
  foreach ($ctt in $ct) {
    foreach ($class in $ctt.Hash.Keys) {
      $layout = $ctt.Hash[$class]
      $pages = $layout.Get('pages')
      $paddles = $layout.Get('paddles')
      $homes = @{}      # spell -> list of page homes
      $padHomes = @{}   # spell -> list of paddle homes
      if (-not $pages) { Add-Finding ERROR layout-parse "${rel}:$($layout.Line)" "$class controller layout has no pages"; continue }
      for ($p = 0; $p -lt $pages.Arr.Count; $p++) {
        $page = $pages.Arr[$p]
        foreach ($key in $page.Hash.Keys) {
          if ($key -eq 'title') { continue }
          $e = $page.Hash[$key]
          $where = "${rel}:$($e.Line)"
          $label = "$class controller page $($p + 1) [$key]"
          if ($key -notmatch '^(none|LT|RT|LT\+RT) (A|X|B|Y|Up|Down|Left|Right)$') { Add-Finding ERROR layout-key $where "$label is not '<none|LT|RT|LT+RT> <A|X|B|Y|Up|Down|Left|Right>'" }
          elseif ($key -match '^none (A|X|B|Y)$') { Add-Finding ERROR layout-key $where "${label}: the Top bar's face buttons are fixed by the Gamepad UI" }
          Test-Entry $e $class 'controller' $where $label $lib $retired
          if ($e -is [LuaTable]) {
            foreach ($s in (Get-HomeNames $e)) {
              if (-not $homes.ContainsKey($s)) { $homes[$s] = New-Object System.Collections.Generic.List[string] }
              $homes[$s].Add("p$($p + 1) $key (line $($e.Line))")
            }
          }
        }
      }
      if ($paddles) {
        foreach ($key in $paddles.Hash.Keys) {
          $e = $paddles.Hash[$key]
          $where = "${rel}:$($e.Line)"
          $base = $key -replace '^LT\+', ''
          $label = "$class back button $key"
          if (-not $PadKey.ContainsKey($base)) { Add-Finding ERROR layout-key $where "$label is not L4/L5/R4/R5 (optionally LT+)" }
          else { $label = "$label ($(if ($key -like 'LT+*') { 'SHIFT-' })$($PadKey[$base]))" }
          Test-Entry $e $class 'controller' $where $label $lib $retired
          if ($e -is [LuaTable]) {
            foreach ($s in (Get-HomeNames $e)) {
              if (-not $padHomes.ContainsKey($s)) { $padHomes[$s] = New-Object System.Collections.Generic.List[string] }
              $padHomes[$s].Add("$key (line $($e.Line))")
            }
          }
        }
      }
      foreach ($s in $homes.Keys) {
        if ($homes[$s].Count -gt 1) { Add-Finding ERROR layout-two-homes "${rel}:$($layout.Line)" "$class controller: '$s' has $($homes[$s].Count) homes: $($homes[$s] -join ', ')" }
      }
      $mirrors = [ordered]@{}
      foreach ($s in $padHomes.Keys) {
        if ($padHomes[$s].Count -gt 1) { Add-Finding ERROR layout-two-homes "${rel}:$($layout.Line)" "$class back buttons: '$s' is on $($padHomes[$s].Count) back buttons: $($padHomes[$s] -join ', ')" }
        if ($homes.ContainsKey($s)) {
          $pair = "back button $($padHomes[$s] -join ', ') and $($homes[$s] -join ', ')"
          if (-not $mirrors.Contains($pair)) { $mirrors[$pair] = New-Object System.Collections.Generic.List[string] }
          $mirrors[$pair].Add("'$s'")
        }
      }
      foreach ($pair in $mirrors.Keys) {
        Add-Finding INFO layout-paddle-mirror "${rel}:$($layout.Line)" "$class controller: $($mirrors[$pair] -join ', ') on $pair (a mirror: allowed by the owner)"
      }
      $all = @{}
      foreach ($s in $homes.Keys) { $all[$s] = $homes[$s] }
      foreach ($s in $padHomes.Keys) { if (-not $all.ContainsKey($s)) { $all[$s] = $padHomes[$s] } }
      Test-MacroCasts $layout $class 'controller' $all $lib $rel
    }
  }
}

# A macro home that casts spells with their own home on the same device.
function Test-MacroCasts($layout, [string]$class, [string]$device, $homes, $lib, [string]$rel) {
  $seen = @{}
  $stack = New-Object System.Collections.Stack
  $stack.Push($layout)
  while ($stack.Count -gt 0) {
    $t = $stack.Pop()
    $macro = $t.Get('macro')
    if ($macro -and $lib.ContainsKey($macro) ) {
      $own = @($t.Strings())
      $covers = $t.Get('covers')
      $also = @()
      foreach ($s in (Get-CastSpells $lib[$macro].Body)) {
        if ($own -contains $s) { continue }
        if ($covers -is [LuaTable] -and ($covers.Strings() -contains $s)) { continue }
        if ($homes.ContainsKey($s)) { $also += "$s ($($homes[$s][0] -replace ' \(line \d+\)', ''))" }
      }
      if ($also.Count -gt 0) { $msg = "$class ${device}: macro '$macro' also casts spells that have their own home: $($also -join ', ')"; if (-not $seen.ContainsKey($msg)) { $seen[$msg] = $true; Add-Finding INFO layout-macro-casts "${rel}:$($t.Line)" $msg } }
    }
    foreach ($v in $t.Hash.Values) { if ($v -is [LuaTable]) { $stack.Push($v) } }
    foreach ($v in $t.Arr) { if ($v -is [LuaTable]) { $stack.Push($v) } }
  }
}

# ---------------------------------------------------------------------------
# rules: code that creates macros outside the library

function Test-MacroWriters {
  foreach ($file in Get-ChildItem -LiteralPath $Addon -Recurse -File -Filter '*.lua') {
    $rel = Rel $file.FullName
    if ($rel -ieq 'Macros\Library.lua') { continue }
    $lit = [LuaLit]::new((ReadText $file.FullName))
    foreach ($m in [regex]::Matches($lit.code, '\b(CreateMacro|EditMacro)\b')) {
      Add-Finding WARN code-creates-macro "${rel}:$($lit.LineAt($m.Index))" "$($m.Value) outside Macros\Library.lua: rule 'applying bars never installs macros' (Controller petauto toggles land here; owner decides if they are exempt)"
    }
  }
}

# ---------------------------------------------------------------------------
# rules: live game (read-only)

function Find-WowGame {
  $root = $WowPath
  if (-not $root) { $root = $env:WOW_PATH }
  if (-not $root) {
    foreach ($key in 'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft', 'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft') {
      try { $p = (Get-ItemProperty -Path $key -ErrorAction Stop).InstallPath; if ($p) { $root = $p.TrimEnd('\'); break } } catch {}
    }
  }
  if (-not $root) {
    foreach ($p in 'C:\Program Files (x86)\World of Warcraft', 'C:\Program Files\World of Warcraft', 'D:\World of Warcraft', 'D:\Games\World of Warcraft') {
      if (Test-Path -LiteralPath $p) { $root = $p; break }
    }
  }
  if (-not $root -or -not (Test-Path -LiteralPath $root)) { return $null }
  if ((Split-Path $root -Leaf) -match '^_.+_$') { return $root }
  foreach ($f in '_forever_', '_retail_', '_classic_era_', '_classic_', '_anniversary_') {
    $g = Join-Path $root $f
    if (Test-Path -LiteralPath (Join-Path $g 'WTF')) { return $g }
  }
  return $null
}

function Read-MacroCache([string]$file) {
  $out = @{}
  if (-not (Test-Path -LiteralPath $file)) { return $out }
  $name = $null; $body = New-Object System.Collections.Generic.List[string]
  foreach ($line in [IO.File]::ReadAllLines($file, [Text.Encoding]::UTF8)) {
    if ($line -match '^VER \d+ \S+ "(.*)" ') { $name = $Matches[1]; $body.Clear(); continue }
    if ($line -eq 'END' -and $name) { $out[$name] = ($body -join "`n"); $name = $null; continue }
    if ($name) { $body.Add($line) }
  }
  return $out
}

function Test-LiveGame($lib, $retired) {
  if ($NoGame) { return }
  $game = Find-WowGame
  if (-not $game) { Add-Finding INFO live-skipped 'game' "World of Warcraft not found (pass -WowPath or set WOW_PATH); live checks skipped"; return }
  $acctBase = Join-Path $game 'WTF\Account'
  $acct = Get-ChildItem -LiteralPath $acctBase -Directory -ErrorAction SilentlyContinue | Where-Object Name -ne 'SavedVariables' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $acct) { Add-Finding INFO live-skipped 'game' "no WTF account folder; live checks skipped"; return }
  $chars = @(Get-ChildItem -LiteralPath $acct.FullName -Directory | Where-Object Name -ne 'SavedVariables' |
    ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Directory } | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SavedVariables') } |
    Sort-Object LastWriteTime -Descending)
  $char = $chars | Select-Object -First 1

  $macros = Read-MacroCache (Join-Path $acct.FullName 'macros-cache.txt')
  $charMacros = @{}
  if ($char) { $charMacros = Read-MacroCache (Join-Path $char.FullName 'macros-cache.txt') }
  $installed = @{}
  foreach ($k in $macros.Keys) { $installed[$k] = @{ Body = $macros[$k]; Scope = 'account' } }
  foreach ($k in $charMacros.Keys) { $installed[$k] = @{ Body = $charMacros[$k]; Scope = 'character' } }

  $bindFiles = @()
  if ($char -and (Test-Path -LiteralPath (Join-Path $char.FullName 'bindings-cache.wtf'))) { $bindFiles += @{ File = (Join-Path $char.FullName 'bindings-cache.wtf'); Scope = 'character' } }
  if (Test-Path -LiteralPath (Join-Path $acct.FullName 'bindings-cache.wtf')) { $bindFiles += @{ File = (Join-Path $acct.FullName 'bindings-cache.wtf'); Scope = 'account' } }
  $paddleOf = @{ F13 = 'L4'; F14 = 'L5'; F15 = 'R4'; F16 = 'R5'; 'SHIFT-F13' = 'LT+L4'; 'SHIFT-F14' = 'LT+L5'; 'SHIFT-F15' = 'LT+R4'; 'SHIFT-F16' = 'LT+R5' }
  foreach ($bf in $bindFiles | Select-Object -First 1) {
    foreach ($line in [IO.File]::ReadAllLines($bf.File, [Text.Encoding]::UTF8)) {
      if ($line -notmatch '^bind\s+(\S+)\s+MACRO\s+(.+)$') { continue }
      $key = $Matches[1]; $name = $Matches[2].Trim()
      $pad = ''
      if ($paddleOf.ContainsKey($key)) { $pad = " (back button $($paddleOf[$key]))" }
      if (-not $installed.ContainsKey($name)) {
        $why = 'no such macro in /macro'
        if ($retired.ContainsKey($name)) { $why += "; '$name' is a retired Agentcraft macro (in L.retired: Controller Apply deletes it, and a later Apply would rebind this key)" }
        Add-Finding ERROR live-binding "$($bf.Scope) bindings-cache.wtf" "$key$pad is bound to MACRO $name, but $why. Pressing it does nothing"
      }
    }
  }
  foreach ($name in $installed.Keys) {
    if ($lib.ContainsKey($name)) {
      $want = ($lib[$name].Body -replace '\s+$', '')
      $have = ($installed[$name].Body -replace '\s+$', '')
      if ($want -ne $have) { Add-Finding INFO live-macro-outdated "$($installed[$name].Scope) macros-cache.txt" "installed macro '$name' differs from the library (Update on the Macros page)" }
    } elseif ($retired.ContainsKey($name)) {
      Add-Finding INFO live-macro-retired "$($installed[$name].Scope) macros-cache.txt" "installed macro '$name' is retired; Apply deletes it only while its text is unchanged"
    }
  }
  Add-Finding INFO live-read 'game' "read $($installed.Count) installed macros and $(@($bindFiles).Count) bindings file(s) from the newest account/character (macros-cache.txt and bindings-cache.wtf are written on logout or /reload)"
}

function Cmd-Rules {
  $data = Read-Macros
  $items = Read-ItemNames
  $lib = @{}
  $firstAt = @{}
  foreach ($m in $data.Macros) {
    if ($firstAt.ContainsKey($m.Name)) { Add-Finding ERROR macro-duplicate "$($m.File):$($m.Line)" "macro name '$($m.Name)' is also defined at $($firstAt[$m.Name])" }
    else { $firstAt[$m.Name] = "$($m.File):$($m.Line)"; $lib[$m.Name] = $m }
    Test-Macro $m $items
    if ($data.Retired.ContainsKey($m.Name)) {
      Add-Finding WARN macro-retired-name "$($m.File):$($m.Line)" "'$($m.Name)' is both a live macro and in L.retired ($($data.Retired[$m.Name].Where)); Apply deletes an installed copy whose text still equals the retired text"
    }
  }
  Test-Layout $lib $data.Retired
  Test-MacroWriters
  Test-LiveGame $lib $data.Retired
  Say "rules: $($data.Macros.Count) library macros, $($data.Retired.Count) retired names, checked against Modules\Layout.lua"
  return Write-Findings 'rules'
}

# ---------------------------------------------------------------------------
# globals: what the addon reads and writes as globals (for .luacheckrc)

$LuaKeywords = 'and break do else elseif end false for function if in local nil not or repeat return then true until while self' -split ' '

function Cmd-Globals {
  $toc = Read-Toc
  $reads = @{}; $writes = @{}
  foreach ($f in $toc.Files) {
    $full = Join-Path $Addon ($f.Path -replace '/', '\')
    if (-not (Test-Path -LiteralPath $full)) { continue }
    $code = ([LuaLit]::new((ReadText $full))).code
    $locals = @{}
    foreach ($m in [regex]::Matches($code, '\blocal\s+function\s+([A-Za-z_]\w*)')) { $locals[$m.Groups[1].Value] = 1 }
    foreach ($m in [regex]::Matches($code, '\blocal\s+((?:[A-Za-z_]\w*\s*,\s*)*[A-Za-z_]\w*)')) { foreach ($v in ($m.Groups[1].Value -split ',')) { $locals[$v.Trim()] = 1 } }
    foreach ($m in [regex]::Matches($code, '\bfunction\b[^(]*\(([^)]*)\)')) { foreach ($v in ($m.Groups[1].Value -split ',')) { $locals[$v.Trim()] = 1 } }
    foreach ($m in [regex]::Matches($code, '\bfor\s+((?:[A-Za-z_]\w*\s*,\s*)*[A-Za-z_]\w*)\s+in\b')) { foreach ($v in ($m.Groups[1].Value -split ',')) { $locals[$v.Trim()] = 1 } }
    foreach ($m in [regex]::Matches($code, '\bfor\s+([A-Za-z_]\w*)\s*=')) { $locals[$m.Groups[1].Value] = 1 }
    foreach ($m in [regex]::Matches($code, '(?<![\w.:])([A-Za-z_]\w*)')) {
      $name = $m.Groups[1].Value
      if ($LuaKeywords -contains $name -or $locals.ContainsKey($name)) { continue }
      $before = $code.Substring(0, $m.Index).TrimEnd()
      $after = $code.Substring($m.Index + $m.Length)
      $isAssign = $after -match '^\s*=(?!=)'
      if ($isAssign -and ($before.EndsWith('{') -or $before.EndsWith(','))) { continue } # table field key
      # A field (t.x, t:x) has one '.' before it; '..' (concat) and '...' (varargs) don't count.
      if ($before -match '(?<!\.)\.$' -or $before.EndsWith(':')) { continue }
      $target = $reads
      if ($isAssign) { $target = $writes }
      if (-not $target.ContainsKey($name)) { $target[$name] = New-Object System.Collections.Generic.List[string] }
      $target[$name].Add($f.Path)
    }
  }
  Say "-- globals written (luacheck 'globals'; anything unexpected here is an accidental global):"
  foreach ($k in ($writes.Keys | Sort-Object)) { Say ("  {0,-28} {1}" -f $k, (($writes[$k] | Select-Object -Unique) -join ', ')) }
  Say "-- globals read (luacheck 'read_globals'; review: some are fields the heuristic missed):"
  foreach ($k in ($reads.Keys | Where-Object { -not $writes.ContainsKey($_) } | Sort-Object)) { Say ("  {0,-40} {1}" -f $k, $reads[$k].Count) }
  return 0
}

# ---------------------------------------------------------------------------
# External tools

# dev\tools first, then PATH, then where per-user installs land without
# touching PATH in an already open shell (winget user scope, manual unzip).
function Find-Tool([string[]]$names) {
  foreach ($n in $names) {
    $local = Join-Path $DevDir "tools\$n.exe"
    if (Test-Path -LiteralPath $local) { return $local }
    $c = Get-Command $n -ErrorAction SilentlyContinue | Where-Object { $_.CommandType -eq 'Application' } | Select-Object -First 1
    if ($c) { return $c.Source }
    if ($env:LOCALAPPDATA) {
      $globs = @(
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links\$n.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\*\$n.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\*\bin\$n.exe"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\*\$n.exe"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\*\bin\$n.exe")
      )
      foreach ($g in $globs) {
        $hit = Get-Item -Path $g -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
      }
    }
  }
  return $null
}

function Missing([string]$what, [string[]]$install) {
  Say "SKIP: $what is not installed. Install one of:"
  foreach ($i in $install) { Say "  $i" }
  return 2
}

# Lua and luacheck read argv, the working directory and file names through
# the ANSI code page, which can't hold every character a user folder may have
# (luacheck then can't even find .luacheckrc). So a non-ASCII path is passed
# as its 8.3 short name, and tools get paths relative to their working dir.
function AsciiPath([string]$full) {
  if ($full -notmatch '[^\x20-\x7e]') { return $full }
  try {
    $fso = New-Object -ComObject Scripting.FileSystemObject
    $short = if (Test-Path -LiteralPath $full -PathType Container) { $fso.GetFolder($full).ShortPath } else { $fso.GetFile($full).ShortPath }
    if ($short -and $short -notmatch '[^\x20-\x7e]') { return $short }
  } catch {}
  Say "note: '$full' has non-ASCII characters and no 8.3 short name; Lua tools may not open it"
  return $full
}

# A path relative to $WowDir with forward slashes when $full is inside it, else
# an ASCII-safe absolute path.
function WowRel([string]$full) {
  if ($full.StartsWith($WowDir + '\', [StringComparison]::OrdinalIgnoreCase)) { return $full.Substring($WowDir.Length + 1).Replace('\', '/') }
  return (AsciiPath $full)
}

# Runs a native tool in $cwd and returns @{ Code; Out; Err }. Uses
# System.Diagnostics.Process, not "& exe 2>&1": Windows PowerShell 5.1 turns
# every stderr line into a terminating error under $ErrorActionPreference =
# 'Stop' (Lua 5.1 prints its version and tracebacks to stderr), and PowerShell
# expands an 8.3 working directory back to the long name, which luacheck
# can't read.
function Run-Native([string]$exe, [string[]]$argv, [string]$cwd) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $exe
  $quoted = foreach ($a in $argv) { if ($a -match '[\s"]' -or $a -eq '') { '"' + ($a -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"' } else { $a } }
  $psi.Arguments = $quoted -join ' '
  if ($cwd) { $psi.WorkingDirectory = AsciiPath $cwd }
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.StandardOutputEncoding = $utf8
  $psi.StandardErrorEncoding = $utf8
  $p = [System.Diagnostics.Process]::Start($psi)
  $errTask = $p.StandardError.ReadToEndAsync()
  $out = $p.StandardOutput.ReadToEnd()
  $p.WaitForExit()
  return @{ Code = $p.ExitCode; Out = $out; Err = $errTask.Result }
}

# Runs a native tool and prints its output (stdout, then stderr). Returns the exit code.
function Invoke-Native([string]$exe, [string[]]$argv, [string]$cwd) {
  $r = Run-Native $exe $argv $cwd
  foreach ($text in $r.Out, $r.Err) {
    $t = ($text -replace "`r`n", "`n").TrimEnd()
    if ($t) { Say $t }
  }
  return $r.Code
}

function Cmd-Lint {
  $exe = Find-Tool @('luacheck')
  if (-not $exe) { return Missing 'luacheck' @('scoop install luacheck', "download https://github.com/lunarmodules/luacheck/releases/download/v1.2.0/luacheck.exe to $DevDir\tools\luacheck.exe") }
  Say "lint: $exe"
  # Relative paths, so the files["addon/Agentcraft/..."] sections in .luacheckrc match.
  # luacheck exits 0 clean, 1 warnings, 2 errors, 3+ crash.
  $code = Invoke-Native $exe @((WowRel $Addon), 'dev/harness', 'dev/tests', '--config', '.luacheckrc', '--quiet', '--no-color') $WowDir
  if ($code -eq 0) { return 0 }
  return 1
}

function Find-Lua {
  foreach ($n in 'lua5.1', 'lua51', 'luajit', 'lua') {
    $exe = Find-Tool @($n)
    if (-not $exe) { continue }
    $r = Run-Native $exe @('-v') $null
    $ver = "$($r.Out)$($r.Err)".Trim()
    if ($ver -match 'Lua 5\.1|LuaJIT') { return $exe }
    Say "note: $exe is '$ver', not Lua 5.1; skipping it"
  }
  return $null
}

function Cmd-Test {
  $exe = Find-Lua
  if (-not $exe) { return Missing 'Lua 5.1' @('scoop bucket add versions; scoop install lua51', 'winget install --id DEVCOM.LuaJIT -e') }
  Say "test: $exe"
  $code = Invoke-Native $exe @('dev/harness/run.lua', (WowRel $Addon), 'dev/tests') $WowDir
  if ($code -eq 0) { return 0 }
  return 1
}

function Cmd-Types {
  $exe = Find-Tool @('lua-language-server')
  if (-not $exe) { return Missing 'lua-language-server' @('winget install --id LuaLS.lua-language-server -e') }
  Say "types: $exe"
  $code = Invoke-Native $exe @('--check', $Addon, '--configpath', (Join-Path $WowDir '.luarc.json'), '--checklevel=Warning') $WowDir
  if ($code -eq 0) { return 0 }
  return 1
}


function Run-Step([string]$name, [scriptblock]$fn) {
  Say ""
  Say "################ $name ################"
  try { $r = & $fn; return [int]($r | Select-Object -Last 1) }
  catch { Say "FAIL: $name crashed: $($_.Exception.Message) ($($_.InvocationInfo.ScriptLineNumber))"; return 1 }
}

function Cmd-Check {
  $results = [ordered]@{}
  $results['toc'] = Run-Step 'toc' { Cmd-Toc }
  $results['rules'] = Run-Step 'rules' { Cmd-Rules }
  $results['lint'] = Run-Step 'lint' { Cmd-Lint }
  $results['types'] = Run-Step 'types' { Cmd-Types }
  $results['test'] = Run-Step 'test' { Cmd-Test }
  Say ""
  Say "################ summary ################"
  $fail = $false
  foreach ($k in $results.Keys) {
    $label = switch ($results[$k]) { 0 { 'pass' } 2 { 'skipped (tool missing)' } default { 'FAIL' } }
    if ($results[$k] -eq 1) { $fail = $true }
    Say ("  {0,-6} {1}" -f $k, $label)
  }
  if ($fail) { return 1 }
  return 0
}

$code = 0
try {
  switch ($Command.ToLowerInvariant()) {
    'check' { $code = Cmd-Check }
    'toc' { $code = Cmd-Toc }
    'rules' { $code = Cmd-Rules }
    'lint' { $code = Cmd-Lint }
    'test' { $code = Cmd-Test }
    'types' { $code = Cmd-Types }
    'globals' { $code = Cmd-Globals }
    default { Say "unknown command '$Command'. Commands: check, toc, rules, lint, test, types, globals"; $code = 1 }
  }
} catch {
  Say "dev.ps1 crashed: $($_.Exception.Message) at line $($_.InvocationInfo.ScriptLineNumber)"
  $code = 1
}
exit ([int]($code | Select-Object -Last 1))
