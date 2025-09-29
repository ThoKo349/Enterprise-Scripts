<# 
  AD-CheckADReplication.ps1 (simple)
  Prüft eingehende AD-Replikation je DC und zeigt eine kurze Übersicht.

  Voraussetzungen:
  - RSAT / ActiveDirectory-Modul
#>

# --- Grundeinstellungen (einfach anpassen) ---
$MaxHealthyHours = 12   # Warnschwelle für maximale Replikationslatenz (in Stunden)

# --- Modul prüfen & laden ---
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory-Modul nicht gefunden. Bitte RSAT installieren."
    exit 2
}
Import-Module ActiveDirectory -ErrorAction Stop

$now = Get-Date

# --- DCs der aktuellen Domäne holen ---
try {
    $dcs = Get-ADDomainController -Filter * -ErrorAction Stop
} catch {
    Write-Error "Domänencontroller konnten nicht gelesen werden: $($_.Exception.Message)"
    exit 2
}

if (-not $dcs -or $dcs.Count -eq 0) {
    Write-Error "Keine Domänencontroller gefunden."
    exit 2
}

# --- Replikationsdaten je DC ermitteln (einfacher Loop, keine Pipes nach Blöcken) ---
$rows = @()
$anyProblem = $false

foreach ($dc in $dcs) {
    $dcName = $dc.HostName

    # Eingehende Partner/Erfolge
    $partners = @()
    try { $partners = Get-ADReplicationPartnerMetadata -Target $dcName -Scope Server -PartnerType Incoming -ErrorAction Stop }
    catch { $partners = @() }

    $inboundCount = ($partners | Measure-Object).Count
    $lastSuccessTimes = $partners | Where-Object { $_.LastReplicationSuccess } | Select-Object -ExpandProperty LastReplicationSuccess
    $lastSuccess = if ($lastSuccessTimes) { ($lastSuccessTimes | Sort-Object -Descending | Select-Object -First 1) } else { $null }
    $maxDelta = if ($lastSuccessTimes) {
        ($lastSuccessTimes | ForEach-Object { ($now - $_).TotalHours } | Measure-Object -Maximum).Maximum
    } else { $null }

    # Fehler (eingehend)
    $fail = @()
    try { $fail = Get-ADReplicationFailure -Target $dcName -Scope Server -ErrorAction SilentlyContinue }
    catch { $fail = @() }
    $failureCount = ($fail | Measure-Object).Count

    # Bewertung (simpel)
    $health = 'OK'
    if ($failureCount -gt 0 -or ($maxDelta -ne $null -and $maxDelta -gt $MaxHealthyHours)) {
        $health = 'Problem'
        $anyProblem = $true
    }

    $rows += [PSCustomObject]@{
        DC           = $dcName
        Site         = $dc.Site
        InboundLinks = $inboundCount
        LastSuccess  = if ($lastSuccess) { $lastSuccess.ToString('yyyy-MM-dd HH:mm') } else { 'n/a' }
        MaxDelta_h   = if ($maxDelta -ne $null) { [math]::Round($maxDelta,2) } else { 'n/a' }
        Failures     = $failureCount
        Health       = $health
    }
}

# --- Ausgabe (kompakt) ---
Write-Host "AD-Replikationsprüfung (eingehend) – $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
$rows | Sort-Object Health, DC | Format-Table -AutoSize

# Exitcode: 0 = OK, 1 = Problem(e)
if ($anyProblem) { exit 1 } else { exit 0 }
