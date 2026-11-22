# Auftrag: GITOPS-UEBUNG-1 – ein Zyklus je Lauf: Pages löschen, einschalten, Push, warten bis HTTP 200 mit neuer Fassung.
# Schreibt je Lauf eine JSON-Zeile nach messung.jsonl. Aufruf: pwsh -NoProfile -File zyklus.ps1 [-Anzahl 3]
param([int]$Anzahl = 1, [int]$MaxWarten = 900)
$ErrorActionPreference = 'Stop'
$repo = 'ArmanBehzadi/gitops-uebung'
$url = 'https://armanbehzadi.github.io/gitops-uebung/'
$wd = $PSScriptRoot

function Get-Status([string]$muster) {
  try {
    $r = Invoke-WebRequest -Uri "$url`?t=$([guid]::NewGuid())" -Headers @{ 'Cache-Control' = 'no-cache' } -SkipHttpErrorCheck -TimeoutSec 20
    if ($muster -and $r.StatusCode -eq 200 -and -not $r.Content.Contains($muster)) { return 'alt' }
    return [int]$r.StatusCode
  } catch { return 'fehler' }
}
function Wait-Bis([scriptblock]$bedingung, [int]$max) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $max) { if (& $bedingung) { return [math]::Round($sw.Elapsed.TotalSeconds, 1) }; Start-Sleep -Seconds 3 }
  return $null
}
function Measure-Schritt([scriptblock]$s) { [math]::Round((Measure-Command $s).TotalSeconds, 1) }

for ($i = 1; $i -le $Anzahl; $i++) {
  $z = [ordered]@{ start = (Get-Date).ToString('o') }
  $z.vorher_status = Get-Status
  $z.loeschen_s = Measure-Schritt { gh api -X DELETE "repos/$repo/pages" 2>&1 | Out-Null }
  $z.weg_s = Wait-Bis { (Get-Status) -ne 200 } 300
  $z.weg_status = Get-Status
  $z.einschalten_s = Measure-Schritt { gh api -X POST "repos/$repo/pages" -f build_type=workflow 2>&1 | Out-Null }
  $z.push_s = Measure-Schritt {
    git -C $wd commit --allow-empty -q -m "Zyklus $i $($z.start)" -m 'Auftrag: GITOPS-UEBUNG-1' | Out-Null
    git -C $wd push -q origin main 2>&1 | Out-Null
  }
  $sha = (git -C $wd rev-parse HEAD).Trim()
  $z.sha = $sha
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $run = $null
  $z.lauf_sichtbar_s = Wait-Bis { $script:run = gh run list -R $repo -w pages.yml -c $sha --json databaseId,status,conclusion | ConvertFrom-Json | Select-Object -First 1; [bool]$script:run } 120
  $z.lauf_fertig_s = Wait-Bis { $script:run = gh run view $script:run.databaseId -R $repo --json databaseId,status,conclusion | ConvertFrom-Json; $script:run.status -eq 'completed' } $MaxWarten
  $z.lauf_id = $run.databaseId
  $z.lauf_ergebnis = $run.conclusion
  $z.bis_200_s = Wait-Bis { (Get-Status $sha) -eq 200 } $MaxWarten
  $z.push_bis_200_s = [math]::Round($sw.Elapsed.TotalSeconds, 1)
  $z.ende = (Get-Date).ToString('o')
  $z.gesamt_s = [math]::Round(([datetime]$z.ende - [datetime]$z.start).TotalSeconds, 1)
  $zeile = $z | ConvertTo-Json -Compress
  Add-Content -Path (Join-Path $wd 'messung.jsonl') -Value $zeile -Encoding utf8
  $zeile
}
