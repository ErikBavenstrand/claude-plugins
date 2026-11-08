<#
.SYNOPSIS
  Reads World of Warcraft data from disk and prints it as JSON or text.
.DESCRIPTION
  Commands:
    overview                          install, characters, saved-variable files, logs, addons
    character [-Character] [-Path]    TinkerKit snapshot (written on every /reload and logout)
    sv -File <name> [-Character] [-Path]  any addon's SavedVariables file, parsed from Lua
    binds [-Character]                keybinds (bindings-cache.wtf)
    errors [-Count]                   recent Lua errors and console messages
    log [-File] [-Tail] [-Grep]       a file in Logs (default: newest combat log)
    file -Path <rel> [-Tail] [-Grep]  any text file under the game folder
    install [-Link]                   copy the bundled TinkerKit addon into AddOns
  -Path walks into the data with "/" between keys, e.g. -Path talents or -Path pet/spellbook.
  Output larger than -Max characters is replaced by a list of keys to narrow with -Path.
  Needs only Windows PowerShell 5.1.
#>
param(
  [Parameter(Position = 0)][string]$Command = 'overview',
  [string]$Character,
  [string]$Path,
  [string]$File,
  [int]$Max = 40000,
  [int]$Tail = 200,
  [string]$Grep,
  [int]$Count = 30,
  [string]$WowPath,
  [string]$Flavor,
  [string]$Account,
  [switch]$Link
)

$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 otherwise serialises arrays as {"value": [...], "Count": n}.
Remove-TypeData System.Array -ErrorAction SilentlyContinue
$utf8 = New-Object System.Text.UTF8Encoding($false)
try { [Console]::OutputEncoding = $utf8 } catch {}

function Out-Text([string]$text) { [Console]::Out.WriteLine($text) }

# ---------------------------------------------------------------------------
# Lua parser for SavedVariables files ("Name = { ... }" statements).
# Tables become ordered dictionaries; tables with keys 1..n become arrays.
class LuaParser {
  [string]$s
  [int]$i
  [int]$n
  static [regex]$Num = [regex]'\G-?(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)'
  static [regex]$Word = [regex]'\G-?[A-Za-z_][A-Za-z0-9_]*'
  static [regex]$Assign = [regex]'\G([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)'
  static [char[]]$StrStop = [char[]]@('"', '\')
  static [char[]]$StrStop1 = [char[]]@("'", '\')

  LuaParser([string]$text) { $this.s = $text; $this.i = 0; $this.n = $text.Length }

  [void] Skip() {
    while ($this.i -lt $this.n) {
      $c = [int]$this.s[$this.i]
      if ($c -le 32) { $this.i++; continue }
      if ($c -eq 45 -and $this.i + 1 -lt $this.n -and [int]$this.s[$this.i + 1] -eq 45) {
        if ([string]::CompareOrdinal($this.s, $this.i, '--[[', 0, 4) -eq 0) {
          $e = $this.s.IndexOf(']]', $this.i + 4)
          if ($e -lt 0) { $this.i = $this.n } else { $this.i = $e + 2 }
        } else {
          $e = $this.s.IndexOf("`n", $this.i)
          if ($e -lt 0) { $this.i = $this.n } else { $this.i = $e + 1 }
        }
        continue
      }
      break
    }
  }

  [void] Expect([char]$ch) {
    if ($this.i -ge $this.n -or $this.s[$this.i] -ne $ch) { throw "expected '$ch' at offset $($this.i)" }
    $this.i++
  }

  [object] Value() {
    $this.Skip()
    if ($this.i -ge $this.n) { throw 'unexpected end of file' }
    $c = $this.s[$this.i]
    if ($c -eq '{') { return $this.Table() }
    if ($c -eq '"' -or $c -eq "'") { return $this.Str() }
    $m = [LuaParser]::Num.Match($this.s, $this.i)
    if ($m.Success) { $this.i += $m.Length; return [LuaParser]::ToNumber($m.Value) }
    $m = [LuaParser]::Word.Match($this.s, $this.i)
    if ($m.Success) {
      $this.i += $m.Length
      if ($m.Value -eq 'nil') { return $null }
      if ($m.Value -eq 'true') { return $true }
      if ($m.Value -eq 'false') { return $false }
      return $m.Value
    }
    throw "unexpected '$c' at offset $($this.i)"
  }

  static [object] ToNumber([string]$t) {
    if ($t -match '^-?0[xX]') {
      $neg = $t.StartsWith('-')
      $v = [Convert]::ToInt64($t.TrimStart('-').Substring(2), 16)
      if ($neg) { return - $v } else { return $v }
    }
    if ($t -match '^-?\d{1,15}$') { return [long]$t }
    return [double]::Parse($t, [Globalization.CultureInfo]::InvariantCulture)
  }

  [string] Str() {
    $q = $this.s[$this.i]
    $this.i++
    $stops = [LuaParser]::StrStop
    if ($q -eq "'") { $stops = [LuaParser]::StrStop1 }
    $sb = New-Object System.Text.StringBuilder
    while ($true) {
      $j = $this.s.IndexOfAny($stops, $this.i)
      if ($j -lt 0) { throw 'unterminated string' }
      [void]$sb.Append($this.s, $this.i, $j - $this.i)
      $this.i = $j
      if ($this.s[$j] -eq $q) { $this.i++; return $sb.ToString() }
      # backslash escape
      $this.i++
      $d = $this.s[$this.i]
      if ($d -eq 'n') { [void]$sb.Append("`n"); $this.i++ }
      elseif ($d -eq 't') { [void]$sb.Append("`t"); $this.i++ }
      elseif ($d -eq 'r') { [void]$sb.Append("`r"); $this.i++ }
      elseif ($d -eq "`r") { [void]$sb.Append("`n"); $this.i++; if ($this.s[$this.i] -eq "`n") { $this.i++ } }
      elseif ($d -ge '0' -and $d -le '9') {
        $k = 0; $code = 0
        while ($k -lt 3 -and $this.i -lt $this.n -and $this.s[$this.i] -ge '0' -and $this.s[$this.i] -le '9') {
          $code = $code * 10 + ([int]$this.s[$this.i] - 48); $this.i++; $k++
        }
        [void]$sb.Append([char]$code)
      }
      else { [void]$sb.Append($d); $this.i++ }
    }
    return $null
  }

  [object] Table() {
    $this.i++
    $t = [ordered]@{}
    $next = 1
    while ($true) {
      $this.Skip()
      if ($this.i -ge $this.n) { throw 'unterminated table' }
      $c = $this.s[$this.i]
      if ($c -eq '}') { $this.i++; break }
      $key = $null
      if ($c -eq '[') {
        $this.i++
        $k = $this.Value()
        $this.Skip(); $this.Expect([char]']'); $this.Skip(); $this.Expect([char]'=')
        $key = [string]$k
      } else {
        $m = [LuaParser]::Assign.Match($this.s, $this.i)
        if ($m.Success) { $key = $m.Groups[1].Value; $this.i += $m.Length }
        else { $key = [string]$next; $next++ }
      }
      $t[$key] = $this.Value()
      $this.Skip()
      if ($this.i -lt $this.n -and ($this.s[$this.i] -eq ',' -or $this.s[$this.i] -eq ';')) { $this.i++ }
    }
    $count = $t.Count
    if ($count -eq 0) { return $t }
    for ($k = 1; $k -le $count; $k++) { if (-not $t.Contains([string]$k)) { return $t } }
    $arr = New-Object object[] $count
    for ($k = 1; $k -le $count; $k++) { $arr[$k - 1] = $t[[string]$k] }
    return $arr
  }

  [object] Document() {
    $doc = [ordered]@{}
    while ($true) {
      $this.Skip()
      if ($this.i -ge $this.n) { break }
      $m = [LuaParser]::Assign.Match($this.s, $this.i)
      if (-not $m.Success) { throw "expected 'Name =' at offset $($this.i)" }
      $this.i += $m.Length
      $doc[$m.Groups[1].Value] = $this.Value()
    }
    return $doc
  }
}

function Read-Lua([string]$file) {
  $text = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8)
  return ([LuaParser]::new($text)).Document()
}

# ---------------------------------------------------------------------------
# Locating the game

function Find-WowRoot {
  if ($WowPath) { return $WowPath }
  if ($env:WOW_PATH) { return $env:WOW_PATH }
  foreach ($key in 'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft',
                   'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft') {
    try {
      $p = (Get-ItemProperty -Path $key -ErrorAction Stop).InstallPath
      if ($p) {
        $p = $p.TrimEnd('\')
        if ((Split-Path $p -Leaf) -match '^_.+_$') { $p = Split-Path $p }
        if (Test-Path $p) { return $p }
      }
    } catch {}
  }
  foreach ($p in 'C:\Program Files (x86)\World of Warcraft', 'C:\Program Files\World of Warcraft',
                 'D:\World of Warcraft', 'D:\Games\World of Warcraft') {
    if (Test-Path $p) { return $p }
  }
  throw 'World of Warcraft not found. Pass -WowPath "<folder that holds _retail_, _forever_, ...>" or set WOW_PATH.'
}

$Root = Find-WowRoot
$Flavors = @(Get-ChildItem -LiteralPath $Root -Directory | Where-Object { $_.Name -match '^_.+_$' } | Select-Object -ExpandProperty Name)
if (-not $Flavor) {
  $Flavor = @('_forever_', '_retail_', '_classic_era_', '_classic_', '_anniversary_') | Where-Object { $Flavors -contains $_ } | Select-Object -First 1
  if (-not $Flavor) { $Flavor = $Flavors | Select-Object -First 1 }
}
$Game = Join-Path $Root $Flavor
$WTF = Join-Path $Game 'WTF'

function Get-AccountDir {
  $base = Join-Path $WTF 'Account'
  if (-not (Test-Path -LiteralPath $base)) { return $null }
  $dirs = @(Get-ChildItem -LiteralPath $base -Directory | Where-Object { $_.Name -ne 'SavedVariables' })
  if ($Account) { $dirs = @($dirs | Where-Object { $_.Name -like "*$Account*" }) }
  # Most recently used account first.
  return $dirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

# Character folders: WTF\Account\<acct>\<realm>\<Name-Realm>
function Get-CharacterDirs($acct) {
  if (-not $acct) { return @() }
  return @(Get-ChildItem -LiteralPath $acct.FullName -Directory | Where-Object { $_.Name -ne 'SavedVariables' } |
    ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Directory } |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SavedVariables') })
}

function Find-CharacterDir($acct, [string]$name) {
  $dirs = Get-CharacterDirs $acct
  if (-not $name) { return $dirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1 }
  $hit = $dirs | Where-Object { $_.Name -like "$name*" } | Select-Object -First 1
  if (-not $hit) { throw "No character folder matches '$name'. Have: $(($dirs | ForEach-Object Name) -join ', ')" }
  return $hit
}

function Assert-Inside([string]$full) {
  $resolved = [IO.Path]::GetFullPath($full)
  if (-not $resolved.StartsWith([IO.Path]::GetFullPath($Game), [StringComparison]::OrdinalIgnoreCase)) {
    throw "Path is outside the game folder: $resolved"
  }
  return $resolved
}

# ---------------------------------------------------------------------------
# Navigation and output

function Step($node, [string]$seg) {
  if ($node -is [System.Collections.IDictionary]) {
    if ($node.Contains($seg)) { return , $node[$seg] }
    foreach ($k in $node.Keys) { if ([string]$k -ieq $seg) { return , $node[$k] } }
    foreach ($k in $node.Keys) { if ([string]$k -ilike "$seg*") { return , $node[$k] } }
    $keys = @($node.Keys | Select-Object -First 60) -join ', '
    throw "No key '$seg'. Keys here: $keys"
  }
  if ($node -is [array]) {
    $idx = 0
    if ([int]::TryParse($seg, [ref]$idx) -and $idx -ge 1 -and $idx -le $node.Count) { return , $node[$idx - 1] }
    throw "No index '$seg'. This is a list of $($node.Count) items (1-based)."
  }
  throw "Cannot go into '$seg': this value is $node"
}

function Walk($node, [string]$p) {
  if (-not $p) { return , $node }
  foreach ($seg in ($p -split '/' | Where-Object { $_ -ne '' })) { $node = Step $node $seg }
  return , $node
}

function Describe($v) {
  if ($null -eq $v) { return 'nil' }
  if ($v -is [System.Collections.IDictionary]) { return "table, $($v.Count) keys" }
  if ($v -is [array]) { return "list, $($v.Count) items" }
  if ($v -is [string]) { if ($v.Length -gt 80) { return '"' + $v.Substring(0, 80) + '..."' } return '"' + $v + '"' }
  return [string]$v
}

function Out-Data($obj, [string]$label) {
  $json = ConvertTo-Json -InputObject $obj -Depth 60
  if ($json.Length -le $Max) { Out-Text $json; return }
  $lines = @("$label is $($json.Length) characters, over the $Max limit. Narrow it with -Path (or raise -Max). Contents:")
  if ($obj -is [System.Collections.IDictionary]) {
    $i = 0
    foreach ($k in $obj.Keys) {
      if ($i -ge 300) { $lines += "  ... $($obj.Count - 300) more keys"; break }
      $lines += "  $k : $(Describe $obj[$k])"; $i++
    }
  } elseif ($obj -is [array]) {
    $lines += "  list of $($obj.Count) items; first item: $(Describe $obj[0])"
  }
  Out-Text ($lines -join "`n")
}

function Out-Lines([string[]]$lines) {
  if ($Grep) { $lines = @($lines | Where-Object { $_ -match $Grep }) }
  if ($Tail -gt 0 -and $lines.Count -gt $Tail) { $lines = $lines[($lines.Count - $Tail)..($lines.Count - 1)] }
  $text = $lines -join "`n"
  if ($text.Length -gt $Max) { $text = '...' + $text.Substring($text.Length - $Max) }
  Out-Text $text
}

function Read-TailLines([string]$file, [int]$n) {
  # Combat logs grow to gigabytes; only read the end.
  $fs = [IO.File]::Open($file, 'Open', 'Read', 'ReadWrite')
  try {
    $chunk = [Math]::Min($fs.Length, [long]([Math]::Max($n, 1) * 400 + 65536))
    if ($Grep) { $chunk = [Math]::Min($fs.Length, 64MB) }
    [void]$fs.Seek(-$chunk, 'End')
    $buf = New-Object byte[] $chunk
    [void]$fs.Read($buf, 0, $chunk)
    $lines = [Text.Encoding]::UTF8.GetString($buf) -split "`r?`n"
    if ($chunk -lt $fs.Length) { $lines = $lines | Select-Object -Skip 1 }
    return , @($lines)
  } finally { $fs.Dispose() }
}

# ---------------------------------------------------------------------------
# Commands

function Cmd-Overview {
  $acct = Get-AccountDir
  $info = [ordered]@{
    wowPath = $Root
    flavor = $Flavor
    otherFlavors = @($Flavors | Where-Object { $_ -ne $Flavor })
    account = if ($acct) { $acct.Name } else { $null }
  }
  $snapFile = if ($acct) { Join-Path $acct.FullName 'SavedVariables\TinkerKit.lua' }
  $snaps = [ordered]@{}
  if ($snapFile -and (Test-Path -LiteralPath $snapFile)) {
    $db = (Read-Lua $snapFile)['TinkerKitDB']
    $all = $null
    try { $all = $db['modules']['Snapshot'] } catch {}
    if ($all) {
      foreach ($k in $all.Keys) {
        $s = $all[$k]
        $b = $s['basics']
        $snaps[$k] = "saved $($s['time'])" + $(if ($b) { ", level $($b['level']) $($b['race']) $($b['class'])" } else { '' })
      }
    }
  }
  $info.snapshots = if ($snaps.Count) { $snaps } else { 'none yet: install the TinkerKit addon (install command), log in and /reload' }
  $info.characterFolders = @(Get-CharacterDirs $acct | ForEach-Object { $_.Name })
  if ($acct) {
    $info.accountSavedVariables = @(Get-ChildItem -LiteralPath (Join-Path $acct.FullName 'SavedVariables') -Filter *.lua -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName })
  }
  $info.addons = @(Get-ChildItem -LiteralPath (Join-Path $Game 'Interface\AddOns') -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike 'Blizzard_*' } | ForEach-Object { $_.Name })
  $info.logs = @(Get-ChildItem -LiteralPath (Join-Path $Game 'Logs') -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 15 |
    ForEach-Object { "$($_.Name) ($([Math]::Round($_.Length / 1KB)) KB, $($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')))" })
  Out-Data $info 'Overview'
}

function Cmd-Character {
  $acct = Get-AccountDir
  $f = Join-Path $acct.FullName 'SavedVariables\TinkerKit.lua'
  if (-not (Test-Path -LiteralPath $f)) { throw 'No TinkerKit data yet. Install the addon (install command), log in and type /reload.' }
  $all = (Read-Lua $f)['TinkerKitDB']['modules']['Snapshot']
  if (-not $all -or $all.Count -eq 0) { throw 'TinkerKit is installed but has no snapshot yet. Type /reload in game.' }
  $key = $null
  if ($Character) {
    $key = @($all.Keys | Where-Object { $_ -like "$Character*" }) | Select-Object -First 1
    if (-not $key) { throw "No snapshot for '$Character'. Have: $(@($all.Keys) -join ', ')" }
  } else {
    $key = @($all.Keys | Sort-Object { $all[$_]['time'] } -Descending) | Select-Object -First 1
  }
  $snap = $all[$key]
  if (-not $Path) {
    $withName = [ordered]@{ character = $key }
    foreach ($k in $snap.Keys) { $withName[$k] = $snap[$k] }
    $snap = $withName
  }
  Out-Data (Walk $snap $Path) "Snapshot of $key"
}

function Cmd-SV {
  if (-not $File) { throw 'Pass -File <addon file name>, e.g. -File TradeSkillMaster. The overview command lists them.' }
  $acct = Get-AccountDir
  $name = $File -replace '\.lua$', ''
  $f = $null
  if ($Character) {
    $c = Find-CharacterDir $acct $Character
    $f = Join-Path $c.FullName "SavedVariables\$name.lua"
  } else {
    foreach ($cand in (Join-Path $acct.FullName "SavedVariables\$name.lua"), (Join-Path $WTF "SavedVariables\$name.lua")) {
      if (Test-Path -LiteralPath $cand) { $f = $cand; break }
    }
  }
  if (-not $f -or -not (Test-Path -LiteralPath $f)) { throw "No SavedVariables file '$name.lua' found. Per-character files need -Character." }
  Out-Data (Walk (Read-Lua $f) $Path) "$name.lua"
}

function Cmd-Binds {
  $acct = Get-AccountDir
  $f = Join-Path $acct.FullName 'bindings-cache.wtf'
  if ($Character) {
    $cf = Join-Path (Find-CharacterDir $acct $Character).FullName 'bindings-cache.wtf'
    if (Test-Path -LiteralPath $cf) { $f = $cf }
  }
  $binds = [ordered]@{}
  foreach ($line in [IO.File]::ReadAllLines($f, [Text.Encoding]::UTF8)) {
    if ($line -match '^bind\s+(\S+)\s+(.+)$') { $binds[$Matches[1]] = $Matches[2].Trim() }
  }
  if ($Grep) {
    $filtered = [ordered]@{}
    foreach ($k in $binds.Keys) { if ($k -match $Grep -or $binds[$k] -match $Grep) { $filtered[$k] = $binds[$k] } }
    $binds = $filtered
  }
  Out-Data $binds 'Keybinds'
}

function Cmd-Errors {
  $f = Join-Path $WTF 'SavedVariables\Blizzard_Console.lua'
  if (-not (Test-Path -LiteralPath $f)) { throw 'No console history file yet.' }
  $hist = (Read-Lua $f)['Blizzard_Console_SavedVars']['messageHistory']
  $msgs = @($hist | ForEach-Object { if ($_ -is [array]) { [string]$_[0] } else { [string]$_ } })
  if (-not $Grep) { $script:Grep = '(?i)\.lua:\d+|lua error|attempt to|traceback|ADDON_ACTION|taint' }
  $script:Tail = $Count
  Out-Lines $msgs
}

function Cmd-Log {
  $dir = Join-Path $Game 'Logs'
  $target = $null
  if ($File) {
    $target = Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Name -like "*$File*" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $target) { throw "No log matches '$File' in $dir." }
  } else {
    $target = Get-ChildItem -LiteralPath $dir -File -Filter 'WoWCombatLog*' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $target) { throw 'No combat log yet. Type /combatlog in game to start one (it stops on logout).' }
  }
  Out-Text "# $($target.Name), $([Math]::Round($target.Length / 1KB)) KB, last written $($target.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
  Out-Lines (Read-TailLines $target.FullName $Tail)
}

function Cmd-File {
  if (-not $Path) { throw 'Pass -Path relative to the game folder, e.g. -Path WTF/Config.wtf' }
  $full = Assert-Inside (Join-Path $Game $Path)
  if (Test-Path -LiteralPath $full -PathType Container) {
    Out-Text ((Get-ChildItem -LiteralPath $full | ForEach-Object { if ($_.PSIsContainer) { "$($_.Name)/" } else { "$($_.Name) ($($_.Length) bytes)" } }) -join "`n")
    return
  }
  Out-Lines (Read-TailLines $full $Tail)
}

function Cmd-Install {
  $source = Join-Path $PSScriptRoot '..\addon\TinkerKit' | Resolve-Path | Select-Object -ExpandProperty Path
  $target = Join-Path $Game 'Interface\AddOns\TinkerKit'
  $item = Get-Item -LiteralPath $target -ErrorAction SilentlyContinue
  if ($item -and $item.LinkType) {
    Out-Text "$target is already a link to $($item.Target). Nothing to do."
    return
  }
  if ($Link) {
    if ($item) { throw "$target exists as a normal folder. Remove it first, then run install -Link again." }
    New-Item -ItemType Junction -Path $target -Target $source | Out-Null
    Out-Text "Linked $target -> $source. Edits in the plugin folder load on /reload."
    return
  }
  & robocopy $source $target /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
  Out-Text "Installed TinkerKit to $target. In game: /reload (or restart), then /tk opens the window."
}

try {
  switch ($Command.ToLower()) {
    'overview' { Cmd-Overview }
    'character' { Cmd-Character }
    'sv' { Cmd-SV }
    'binds' { Cmd-Binds }
    'errors' { Cmd-Errors }
    'log' { Cmd-Log }
    'file' { Cmd-File }
    'install' { Cmd-Install }
    default { throw "Unknown command '$Command'. Use: overview, character, sv, binds, errors, log, file, install." }
  }
} catch {
  [Console]::Error.WriteLine("error: $($_.Exception.Message)")
  exit 1
}
