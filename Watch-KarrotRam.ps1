# Karrot RAM16 watcher (unattended, read-only).
# Target: DDR4 notebook 16GB sticks for Lenovo 82JQ (8GBx2 -> 16GBx2 upgrade).
# Alert when: 2+ distinct 16GB listings on sale, or any single listing mentioning 2 sticks.
# Source is ASCII-only; Korean is handled via regex \u escapes and runtime URL-decoding.
param()
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$StateDir = Join-Path $Dir 'state'
$LogDir = Join-Path $Dir 'logs'
New-Item -ItemType Directory -Force -Path $StateDir, $LogDir | Out-Null
$SeenFile = Join-Path $StateDir 'karrot-seen.json'
$AlertFile = Join-Path $Dir 'alert-ram16.txt'
$Day = Get-Date -Format 'yyyyMMdd'
$LogFile = Join-Path $LogDir ('karrot-' + $Day + '.log')
function Log($s) {
  $line = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $s
  Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
  Write-Output $line
}
$Regions = @(
  @{ Id = 4537; Name = 'Yeongtong' },
  @{ Id = 4502; Name = 'Seohyeon' },
  @{ Id = 4720; Name = 'Pungdeokcheon' }
)
$Keywords = @('%EB%85%B8%ED%8A%B8%EB%B6%81%EB%9E%A8', 'DDR4%2016GB')
$seen = @()
if (Test-Path -LiteralPath $SeenFile) {
  try { $seen = @(Get-Content -LiteralPath $SeenFile -Raw | ConvertFrom-Json) } catch { $seen = @() }
}
$re16   = '16\s?(GB|\uAE30\uAC00)'
$reNb   = '(\uB178\uD2B8\uBD81|\uB7A8|DDR4?|SODIMM|SO-DIMM|3200|2666|2400|4800|5600)'
$reDesk = '(\uB370\uC2A4\uD06C\uD0D1|\uB370\uD0D1)'
$reTwo  = '(2\s?(\uAC1C|\uC7A5)|\uB450\s?\uAC1C|[xX]2|2\s?[xX])'
$rePrice = '([\d,]+)\uC6D0'
$reA = [regex]'<a[^>]*href="(/kr/buy-sell/[^"]+-[A-Za-z0-9]+/?)"[^>]*>([\s\S]*?)</a>'
$found = @{}
foreach ($rg in $Regions) {
  foreach ($kw in $Keywords) {
    $url = 'https://www.daangn.com/kr/search/buy-sell/?in=x-' + $rg.Id + '&q=' + $kw + '&only_on_sale=true'
    try {
      $html = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30).Content
    } catch {
      Log ('FETCH-FAIL ' + $rg.Name + ' ' + $_.Exception.Message)
      continue
    }
    foreach ($m in $reA.Matches($html)) {
      $href = $m.Groups[1].Value
      $raw = $m.Groups[2].Value -replace '(?s)<noscript>.*?</noscript>', '' -replace '<img[^>]*>', '' -replace '(?s)<svg.*?</svg>', '' -replace '<[^>]+>', ([string][char]1)
      $parts = @($raw.Split([char]1) | ForEach-Object { $_.Trim() } | Where-Object { $_ })
      if ($parts.Count -lt 2) { continue }
      $title = [System.Net.WebUtility]::HtmlDecode(($parts -join ' '))
      $flat = $title -replace '\s+', ''
      $slug = [Uri]::UnescapeDataString($href) -replace '[^0-9A-Za-z\uAC00-\uD7A3]+', ''
      $both = $flat + $slug
      $isGen4 = ($both -match 'DDR4') -or ($both -notmatch 'DDR[0-9]')
      if (($both -match '16(GB|\uAE30\uAC00)') -and ($both -match '(\uB178\uD2B8\uBD81|\uB7A8|DDR4|SODIMM|3200|2666|2400)') -and ($both -notmatch '(\uB370\uC2A4\uD06C\uD0D1|\uB370\uD0D1)') -and $isGen4 -and ($both -notmatch '(ECC|\uC11C\uBC84\uC6A9|\uAD50\uD658)') -and ($both -notmatch '(\uC778\uCE58|\uADF8\uB7A8|\uB9E5\uBD81|\uBCF8\uCCB4|\uCD1D\s?16|8\s?GB\s?(2\uAC1C|[xX×]\s?2))')) {
        $price = ''
        $pm = [regex]::Match($title, $rePrice)
        if ($pm.Success) { $price = $pm.Groups[1].Value }
        if (-not $found.ContainsKey($href)) {
          $found[$href] = @{ Title = $title; Price = $price; Region = $rg.Name; Url = 'https://www.daangn.com' + $href }
        }
      }
    }
    Start-Sleep -Seconds 1
  }
}
$cands = @($found.Values)
$newOnes = @($cands | Where-Object { $seen -notcontains $_.Url })
$seen = @(($seen + @($cands | ForEach-Object { $_.Url })) | Sort-Object -Unique)
$seen | ConvertTo-Json | Set-Content -LiteralPath $SeenFile -Encoding UTF8
Log ('SWEEP regions=3 keywords=2 candidates=' + $cands.Count + ' new=' + $newOnes.Count)
foreach ($c in $newOnes) { Log ('NEW [' + $c.Region + '] ' + $c.Price + ' | ' + $c.Title + ' | ' + $c.Url) }
$twoStick = @($cands | Where-Object { $_.Title -match $reTwo })
$cond = ($cands.Count -ge 2) -or ($twoStick.Count -ge 1)
if ($cond -and ($newOnes.Count -ge 1)) {
  $lines = @()
  $lines += 'RAM16 ALERT ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  $lines += 'Target: DDR4 notebook 16GB x2 (Yeongtong/Seohyeon/Pungdeokcheon)'
  $lines += ''
  foreach ($c in $cands) { $lines += ('- [' + $c.Region + '] ' + $c.Price + ' | ' + $c.Title); $lines += ('  ' + $c.Url) }
  $lines | Set-Content -LiteralPath $AlertFile -Encoding UTF8
  Log ('ALERT fired: candidates=' + $cands.Count + ' twoStick=' + $twoStick.Count)
  Write-Output 'ALERT: 16GB listings found - see alert-ram16.txt'
} else {
  Write-Output ('done: candidates=' + $cands.Count + ' new=' + $newOnes.Count)
}
