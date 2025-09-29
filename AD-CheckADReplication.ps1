<# 
.SYNOPSIS
  Prüft den Active-Directory-Replikationszustand (eingehend) pro DC und meldet Abweichungen/Fehler.

.DESCRIPTION
  - Liest alle DCs der aktuellen Domäne oder des gesamten Forests.
  - Ermittelt eingehende Replikationspartner, letzten erfolgreichen Sync, maximale Latenz und Fehler.
  - Bewertet die Gesundheit pro DC (Healthy/Degraded/Critical).
  - Setzt Exitcode 1 bei Problemen (nützlich für Monitoring/Automatisierung).

.PARAMETER Forest
  Prüft alle Domänen im Forest (Standard: nur aktuelle Domäne).

.PARAMETER MaxHealthyHours
  Maximal erlaubte Stunden seit letztem erfolgreichen eingehenden Replikationsevent.
  Degraded: > MaxHealthyHours; Critical: > (MaxHealthyHours * 2).

.PARAMETER ShowAll
  Zeigt auch DCs ohne eingehende Partner (Edge-Cases) in der Übersicht.

.NOTES
  Erfordert RSAT / ActiveDirectory-Modul.
#>

[CmdletBinding()]
param(
    [switch]$Forest,
    [int]$MaxHealthyHours = 12,
    [switch]$ShowAll
)

# --- Vorbedingungen -----------------------------------------------------------
function Assert-Module {
    param([string]$Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        throw "Erforderliches Modul '$Name' ist nicht installiert. Bitte RSAT / ActiveDirectory-Modul bereitstellen."
    }
}
Assert-Module -Name ActiveDirectory
Import-Module ActiveDirectory -ErrorAction Stop

$now = Get-Date
$criticalHours = [int]([math]::Max(($MaxHealthyHours * 2), $MaxHealthyHours + 1))

# --- Domänenliste -------------------------------------------------------------
$domains = @()
if ($Forest) {
    try {
        $forest = Get-ADForest -ErrorAction Stop
        $domains = $forest.Domains
    } catch {
        throw "Forest-Informationen konnten nicht gelesen werden: $($_.Exception.Message)"
    }
} else {
    try {
        $domains = @((Get-ADDomain -ErrorAction Stop).DNSRoot)
    } catch {
        throw "Domäneninformationen konnten nicht gelesen werden: $($_.Exception.Message)"
    }
}

if (-not $domains -or $domains.Count -eq 0) {
    throw "Keine Domänen gefunden."
}

# --- DC-Liste je Domäne (FIX: nicht direkt an Pipe hängen) -------------------
$allDcs = foreach ($d in $domains) {
    try {
        Get-ADDomainController -Server $d -Filter * -ErrorAction Stop
    } catch {
        Write-Warning "Konnte DC-Liste für Domäne '$d' nicht lesen: $($_.Exception.Message)"
    }
}

# Jetzt sortieren (kein leeres Pipe-Element mehr)
$allDcs = $allDcs | Where-Object { $_ } | Sort-Object HostName

if (-not $allDcs -or $allDcs.Count -eq 0) {
    Write-Error "Keine Domänencontroller gefunden."
    exit 2
}

# --- Replikationsdaten sammeln ------------------------------------------------
$rows = @()
$allFailures = @()

foreach ($dc in $allDcs) {
    $dcName  = $dc.HostName
    $site    = $dc.Site
    $domain  = $dc.Domain
    $os      = $dc.OperatingSystem

    # Partner (eingehend)
    $partners = @()
    try {
        $partners = Get-ADReplicationPartnerMetadata -Target $dcName -Scope Server -PartnerType Incoming -ErrorAction Stop
    } catch {
        Write-Warning "[$dcName] Partner-Metadaten nicht lesbar: $($_.Exception.Message)"
    }

    # Fehler (eingehend)
    $fail = @()
    try {
        $fail = Get-ADReplicationFailure -Target $dcName -Scope Server -ErrorAction SilentlyContinue
    } catch {
        # bewusst leise
    }

    $inboundCount = ($partners | Measure-Object).Count
    $lastSuccessTimes = $partners | Where-Object { $_.LastReplicationSuccess } | Select-Object -ExpandProperty LastReplicationSuccess
    $lastSuccess = if ($lastSuccessTimes) { ($lastSuccessTimes | Sort-Object -Descending | Select-Object -First 1) } else { $null }

    $largestDeltaHours = if ($lastSuccessTimes) {
        ($lastSuccessTimes | ForEach-Object { [math]::Round(($now - $_).TotalHours, 2) } | Measure-Object -Maximum).Maximum
    } else { [double]::PositiveInfinity }

    $failureCount = ($fail | Measure-Object).Count

    # Health
    $health = 'Healthy'
    if ($failureCount -gt 0 -or $largestDeltaHours -gt $MaxHealthyHours) { $health = 'Degraded' }
    if ($failureCount -gt 0 -and $largestDeltaHours -gt $criticalHours) { $health = 'Critical' }

    if ($ShowAll -or $inboundCount -gt 0 -or $failureCount -gt 0) {
        $rows += [PSCustomObject]@{
            Domain        = $domain
            Site          = $site
            DC            = $dcName
            InboundLinks  = $inboundCount
            LastSuccess   = if ($lastSuccess) { $lastSuccess } else { $null }
            MaxDeltaHrs   = if ([double]::IsInfinity($largestDeltaHours)) { $null } else { $largestDeltaHours }
            Failures      = $failureCount
            Health        = $health
            OS            = $os
        }
    }

    if ($failureCount -gt 0) {
        $allFailures += $fail | Select-Object `
            @{n='DC';e={$dcName}},
            @{n='Partner';e={$_.Partner}},
            @{n='FirstFailureTime';e={$_.FirstFailureTime}},
            @{n='FailureCount';e={$_.FailureCount}},
            @{n='LastError';e={$_.LastErrorStatus}},
            @{n='LastErrorCode';e={$_.LastErrorCode}}
    }
}

# --- Ausgabe -----------------------------------------------------------------
Write-Host "AD Replikationszustand (eingehend) – Stand: $($now.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
$rows |
    Sort-Object Health, Domain, Site, DC |
    Select-Object Domain, Site, DC, InboundLinks,
                  @{n='LastSuccess';e={ if ($_.LastSuccess) { $_.LastSuccess.ToString('yyyy-MM-dd HH:mm') } else { 'n/a' } }},
                  @{n='MaxDelta(h)';e={ if ($_.MaxDeltaHrs -ne $null) { $_.MaxDeltaHrs } else { 'n/a' } }},
                  Failures, Health |
    Format-Table -AutoSize

if ($allFailures.Count -gt 0) {
    Write-Host "`nDetails zu Replikationsfehlern:" -ForegroundColor Yellow
    $allFailures |
        Sort-Object FirstFailureTime -Descending |
        Select-Object DC, Partner,
                       @{n='FirstFailureTime';e={$_.FirstFailureTime.ToString('yyyy-MM-dd HH:mm')}},
                       FailureCount, LastError, LastErrorCode |
        Format-Table -AutoSize
}

# --- Exitcode ----------------------------------------------------------------
$hasCritical = $rows | Where-Object { $_.Health -eq 'Critical' }
if ($hasCritical -or $allFailures.Count -gt 0) { exit 1 } else { exit 0 }
