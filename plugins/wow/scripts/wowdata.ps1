<#
.SYNOPSIS
  Reads World of Warcraft data from disk and prints it as JSON or text.
.DESCRIPTION
  Commands:
    overview                          install, characters, saved-variable files, logs, addons
    character [-Character] [-Path]    Agentcraft snapshot (saved 10 s after changes, on disk after /reload)
    sv -File <name> [-Character] [-Path]  any addon's SavedVariables file, parsed from Lua
    binds [-Character] [-Grep]        keybinds (bindings-cache.wtf)
    errors [-Count] [-Character]      Lua errors in the console history, plus snapshot section errors
    log [-File] [-Tail] [-Grep]       a file in Logs (default: newest combat log)
    file -Path <rel> [-Tail] [-Grep]  any text file under the game folder
    install [-Link]                   copy the bundled Agentcraft addon into AddOns
  Global options: -Flavor _forever_|_retail_|... (default: _forever_ first), -Account <part of name>,
  -WowPath <folder> (or WOW_PATH), -Max <chars>.
  -Path walks into the data with "/" between keys, e.g. -Path talents or -Path pet/spellbook.
  A key may be shortened to a unique prefix.
  Output larger than -Max characters is replaced by a list of keys to narrow with -Path.
  Needs only Windows PowerShell 5.1. Windows only: it finds the game through the registry,
  builds Windows paths and installs with robocopy and a junction.
  log -Grep and -Tail 0 read at most the last 64 MB and say so.
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
  static [Text.Encoding]$Utf8 = (New-Object System.Text.UTF8Encoding($false, $true))

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
        # \ddd is one byte of a Lua byte string; decode a run of them as UTF-8.
        $run = New-Object System.Collections.Generic.List[byte]
        while ($true) {
          $k = 0; $code = 0
          while ($k -lt 3 -and $this.i -lt $this.n -and $this.s[$this.i] -ge '0' -and $this.s[$this.i] -le '9') {
            $code = $code * 10 + ([int]$this.s[$this.i] - 48); $this.i++; $k++
          }
          $run.Add([byte]($code -band 255))
          if ($this.i + 1 -lt $this.n -and $this.s[$this.i] -eq '\' -and $this.s[$this.i + 1] -ge '0' -and $this.s[$this.i + 1] -le '9') { $this.i++ }
          else { break }
        }
        [void]$sb.Append([LuaParser]::Bytes($run.ToArray()))
      }
      else { [void]$sb.Append($d); $this.i++ }
    }
    return $null
  }

  static [string] Bytes([byte[]]$b) {
    try { return [LuaParser]::Utf8.GetString($b) } catch { return [Text.Encoding]::GetEncoding(28591).GetString($b) }
  }

  # Lua keys are case-sensitive; [ordered]@{} is not.
  static [System.Collections.Specialized.OrderedDictionary] NewTable() {
    return New-Object System.Collections.Specialized.OrderedDictionary
  }

  [object] Table() {
    $this.i++
    $t = [LuaParser]::NewTable()
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
    $doc = [LuaParser]::NewTable()
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

# Sets $Root, $Flavors, $Flavor, $Game and $WTF. Runs inside the try below,
# so a bad -WowPath or -Flavor gives a one-line error.
function Initialize-Game {
  $script:Root = Find-WowRoot
  if (-not (Test-Path -LiteralPath $Root -PathType Container)) { throw "WoW folder not found: $Root. Pass -WowPath `"<folder that holds _retail_, _forever_, ...>`"." }
  $script:Flavors = @(Get-ChildItem -LiteralPath $Root -Directory | Where-Object { $_.Name -match '^_.+_$' } | Select-Object -ExpandProperty Name)
  if ($Flavor) {
    if ($Flavor -notmatch '^_.+_$') { $script:Flavor = "_$($Flavor.Trim('_'))_" }
    if ($Flavors -notcontains $Flavor) { throw "No '$Flavor' folder under $Root. Have: $($Flavors -join ', ')" }
  } else {
    $script:Flavor = @('_forever_', '_retail_', '_classic_era_', '_classic_', '_anniversary_') | Where-Object { $Flavors -contains $_ } | Select-Object -First 1
    if (-not $Flavor) { $script:Flavor = $Flavors | Select-Object -First 1 }
    if (-not $Flavor) { throw "No game folders (_retail_, _forever_, ...) under $Root. Pass -WowPath with the folder that holds them." }
  }
  $script:Game = Join-Path $Root $Flavor
  $script:WTF = Join-Path $Game 'WTF'
}

function Get-AccountDir {
  $base = Join-Path $WTF 'Account'
  if (-not (Test-Path -LiteralPath $base)) { return $null }
  $dirs = @(Get-ChildItem -LiteralPath $base -Directory | Where-Object { $_.Name -ne 'SavedVariables' })
  if ($Account) { $dirs = @($dirs | Where-Object { $_.Name -like "*$Account*" }) }
  # Most recently used account first.
  return $dirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Get-AccountDirOrThrow {
  $acct = Get-AccountDir
  if (-not $acct) {
    $which = if ($Account) { " matching '$Account'" } else { '' }
    throw "No WTF/Account folder$which under $Game. Log in once, or pass -Flavor (have: $($Flavors -join ', ')) or -Account."
  }
  return $acct
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
    $hits = @($node.Keys | Where-Object { ([string]$_).StartsWith($seg, [StringComparison]::OrdinalIgnoreCase) })
    if ($hits.Count -eq 1) { return , $node[$hits[0]] }
    if ($hits.Count -gt 1) { throw "'$seg' matches $($hits -join ', '); be more specific." }
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
  # PowerShell 5.1 writes ' < > & as ' and so on; put them back so the text can be searched.
  $json = [regex]::Replace($json, '(?i)(?<!\\)((?:\\\\)*)\\u00(27|3c|3e|26)', {
    param($m) $m.Groups[1].Value + [char][Convert]::ToInt32($m.Groups[2].Value, 16) })
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
    if ($Grep -or $n -le 0) {
      $chunk = [Math]::Min($fs.Length, 64MB)
      if ($chunk -lt $fs.Length) { Out-Text "# read only the last 64 MB of $([Math]::Round($fs.Length / 1MB)) MB" }
    }
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
  $snapFile = if ($acct) { Join-Path $acct.FullName 'SavedVariables\Agentcraft.lua' }
  $snaps = [ordered]@{}
  if ($snapFile -and (Test-Path -LiteralPath $snapFile)) {
    $db = (Read-Lua $snapFile)['AgentcraftDB']
    $all = $null
    try { $all = $db['modules']['Snapshot'] } catch {}
    if ($all) {
      foreach ($k in $all.Keys) {
        $s = $all[$k]
        $b = $s['basics']
        $line = "saved $($s['time'])" + $(if ($b) { ", level $($b['level']) $($b['race']) $($b['class'])" } else { '' })
        # Times are "yyyy-MM-dd HH:mm:ss", so string order is time order.
        $skipped = $s['skippedIncomplete']
        if ($skipped -and [string]$skipped -gt [string]$s['time']) { $line += ", last save skipped $skipped (character not loaded)" }
        $stale = @($s.Keys | Where-Object { $s[$_] -is [System.Collections.IDictionary] -and $s[$_].Contains('staleSince') })
        if ($stale.Count) { $line += ", stale sections: $($stale -join ', ')" }
        $snaps[$k] = $line
      }
    }
  }
  $info.snapshots = if ($snaps.Count) { $snaps } else { 'none yet: install the Agentcraft addon (install command), log in and /reload' }
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

# Returns the snapshot key and table for -Character, else the newest.
function Get-Snapshot {
  $acct = Get-AccountDirOrThrow
  $f = Join-Path $acct.FullName 'SavedVariables\Agentcraft.lua'
  if (-not (Test-Path -LiteralPath $f)) { throw 'No Agentcraft data yet. Install the addon (install command), log in and type /reload.' }
  $all = $null
  try { $all = (Read-Lua $f)['AgentcraftDB']['modules']['Snapshot'] } catch {}
  if (-not $all -or $all.Count -eq 0) { throw 'Agentcraft is installed but has no snapshot yet. Wait 10 seconds in game, then type /reload.' }
  $key = $null
  if ($Character) {
    $key = @($all.Keys | Where-Object { $_ -like "$Character*" }) | Select-Object -First 1
    if (-not $key) { throw "No snapshot for '$Character'. Have: $(@($all.Keys) -join ', ')" }
  } else {
    $key = @($all.Keys | Sort-Object { $all[$_]['time'] } -Descending) | Select-Object -First 1
  }
  return $key, $all[$key]
}

function Cmd-Character {
  $key, $snap = Get-Snapshot
  if (-not $Path) {
    $withName = [ordered]@{ character = $key }
    foreach ($k in $snap.Keys) { $withName[$k] = $snap[$k] }
    $snap = $withName
  }
  Out-Data (Walk $snap $Path) "Snapshot of $key"
}

function Cmd-SV {
  if (-not $File) { throw 'Pass -File <addon file name>, e.g. -File TradeSkillMaster. The overview command lists them.' }
  $acct = Get-AccountDirOrThrow
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
  if (-not $f -or -not (Test-Path -LiteralPath $f)) {
    if ($Character) { throw "No SavedVariables file '$name.lua' for $($c.Name). Account-wide files need no -Character." }
    throw "No SavedVariables file '$name.lua' found. Per-character files need -Character."
  }
  Out-Data (Walk (Read-Lua $f) $Path) "$name.lua"
}

function Cmd-Binds {
  $acct = Get-AccountDirOrThrow
  $f = Join-Path $acct.FullName 'bindings-cache.wtf'
  if ($Character) {
    $cf = Join-Path (Find-CharacterDir $acct $Character).FullName 'bindings-cache.wtf'
    if (Test-Path -LiteralPath $cf) { $f = $cf }
  }
  if (-not (Test-Path -LiteralPath $f)) { throw "No bindings-cache.wtf in $($acct.Name) yet. The game writes it after the user changes a key binding." }
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

# Every "error: ..." string and lastError field in a snapshot, as "path: text".
function Find-SnapshotErrors($node, [string]$path, [System.Collections.Generic.List[string]]$out) {
  if ($node -is [string]) {
    if ($node.StartsWith('error: ')) { $out.Add("${path}: $node") }
  } elseif ($node -is [System.Collections.IDictionary]) {
    foreach ($k in $node.Keys) {
      $v = $node[$k]
      $p = if ($path) { "$path/$k" } else { [string]$k }
      if ($k -eq 'lastError' -and $v -is [string]) {
        $since = if ($node.Contains('staleSince')) { " (old data kept since $($node['staleSince']))" } else { '' }
        $out.Add("${path}${since}: $v")
      } else { Find-SnapshotErrors $v $p $out }
    }
  } elseif ($node -is [array]) {
    for ($i = 0; $i -lt $node.Count; $i++) { Find-SnapshotErrors $node[$i] "$path/$($i + 1)" $out }
  }
}

function Cmd-Errors {
  # Console history: errors the client logged.
  $f = Join-Path $WTF 'SavedVariables\Blizzard_Console.lua'
  if (Test-Path -LiteralPath $f) {
    $hist = (Read-Lua $f)['Blizzard_Console_SavedVars']['messageHistory']
    $msgs = @($hist | ForEach-Object { if ($_ -is [array]) { [string]$_[0] } else { [string]$_ } })
    $pattern = if ($Grep) { $Grep } else { '(?i)\.lua:\d+|lua error|attempt to|traceback|ADDON_ACTION|taint' }
    $hits = @($msgs | Where-Object { $_ -match $pattern })
    Out-Text "# console: $($hits.Count) matching of $($msgs.Count) messages"
    if ($hits.Count) {
      $script:Grep = $null
      $script:Tail = $Count
      Out-Lines $hits
    }
  } else {
    Out-Text '# console: no history file yet'
  }
  # Snapshot: sections run in pcall, so their errors never reach the console.
  try { $key, $snap = Get-Snapshot } catch { Out-Text "# snapshot: $($_.Exception.Message)"; return }
  $errs = New-Object System.Collections.Generic.List[string]
  Find-SnapshotErrors $snap '' $errs
  Out-Text "# snapshot $key (saved $($snap['time'])): $($errs.Count) errors"
  foreach ($e in $errs) { Out-Text $e }
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
  $source = Join-Path $PSScriptRoot '..\addon\Agentcraft' | Resolve-Path | Select-Object -ExpandProperty Path
  $target = Join-Path $Game 'Interface\AddOns\Agentcraft'
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
  Out-Text "Installed Agentcraft to $target. In game: /reload (or restart), then /ac opens the window."
}

try {
  Initialize-Game
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
