# Auftrag: GITOPS-UEBUNG-1/-2 – ein Zyklus je Lauf: Pages löschen, einschalten, Push, warten bis HTTP 200 mit neuer Fassung.
# Schreibt je Lauf eine JSON-Zeile nach messung.jsonl (auch bei Abbruch, dann mit Feld fehler). Aufruf: pwsh -NoProfile -File zyklus.ps1 [-Anzahl 3]
# Bricht beim ersten Fehler ab (Exit-Code ungleich 0, roter Lauf, Frist abgelaufen) und endet dann mit Exit 1.
param([int]$Anzahl = 1, [int]$MaxWarten = 900, [string]$Auftrag = 'GITOPS-UEBUNG-2')
$ErrorActionPreference = 'Stop'
$repo = 'ArmanBehzadi/gitops-uebung'
$url = 'https://armanbehzadi.github.io/gitops-uebung/'
$wd = $PSScriptRoot

# Liefert den HTTP-Status, 'alt' (200 ohne Muster) oder 'fehler' (Netz, DNS, Zeitlimit: zählt nie als gelöscht).
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
# Führt einen externen Befehl aus, prüft seinen Exit-Code und gibt die Dauer in Sekunden zurück.
function Measure-Schritt([string]$name, [scriptblock]$s) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $aus = & $s 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) { throw "$name mit Exit $LASTEXITCODE`: $($aus.Trim())" }
  [math]::Round($sw.Elapsed.TotalSeconds, 1)
}
function Get-Lauf([scriptblock]$s) {
  $j = & $s 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) { throw "gh run mit Exit $LASTEXITCODE`: $($j.Trim())" }
  $j | ConvertFrom-Json | Select-Object -First 1
}

for ($i = 1; $i -le $Anzahl; $i++) {
  $z = [ordered]@{ start = (Get-Date).ToString('o') }
  try {
    $z.vorher_status = Get-Status
    $z.loeschen_s = Measure-Schritt 'Pages löschen' { gh api -X DELETE "repos/$repo/pages" }
    $z.weg_s = Wait-Bis { (Get-Status) -eq 404 } 300
    $z.weg_status = Get-Status
    if ($null -eq $z.weg_s) { throw "Seite nach 300 s nicht weg (Status $($z.weg_status))" }
    $z.einschalten_s = Measure-Schritt 'Pages einschalten' { gh api -X POST "repos/$repo/pages" -f build_type=workflow }
    $z.commit_s = Measure-Schritt 'git commit' { git -C $wd commit --allow-empty -q -m "Zyklus $i $($z.start)" -m "Auftrag: $Auftrag" }
    $z.push_s = Measure-Schritt 'git push' { git -C $wd push -q origin main }
    $sha = (git -C $wd rev-parse HEAD).Trim()
    $z.sha = $sha
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $run = $null
    $z.lauf_sichtbar_s = Wait-Bis { $script:run = Get-Lauf { gh run list -R $repo -w pages.yml -c $sha --json databaseId,status,conclusion };[bool]$script:run } 120
    if ($null -eq $z.lauf_sichtbar_s) { throw "Lauf zu $sha nach 120 s nicht sichtbar" }
    $z.lauf_id = $run.databaseId
    $z.lauf_fertig_s = Wait-Bis { $script:run = Get-Lauf { gh run view $z.lauf_id -R $repo --json databaseId,status,conclusion };$script:run.status -eq 'completed' } $MaxWarten
    $z.lauf_ergebnis = $run.conclusion
    if ($null -eq $z.lauf_fertig_s) { throw "Lauf $($z.lauf_id) nach $MaxWarten s nicht fertig" }
    if ($run.conclusion -ne 'success') { throw "Lauf $($z.lauf_id) rot: $($run.conclusion)" }
    $z.bis_200_s = Wait-Bis { (Get-Status $sha) -eq 200 } $MaxWarten
    $z.push_bis_200_s = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    if ($null -eq $z.bis_200_s) { throw "Seite nach $MaxWarten s nicht 200 mit Fassung $sha" }
  } catch { $z.fehler = "$_" } finally {
    $z.ende = (Get-Date).ToString('o')
    $z.gesamt_s = [math]::Round(([datetime]$z.ende - [datetime]$z.start).TotalSeconds, 1)
    $zeile = $z | ConvertTo-Json -Compress
    Add-Content -Path (Join-Path $wd 'messung.jsonl') -Value $zeile -Encoding utf8
    $zeile
  }
  if ($z.fehler) { exit 1 }
}
