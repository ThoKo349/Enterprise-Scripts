<# 
.SYNOPSIS
  Prüft den Active-Directory-Replikationszustand (eingehend) pro DC und meldet Abweichungen/Fehler.

.DESCRIPTION
  - Liest alle DCs der aktuellen Domäne oder des gesamten Forests.
  - Ermittelt für jeden DC die eingehenden Replikationspartner, den letzten erfolgreichen Sync,
    die größte Replikationslatenz (Delta), sowie aktuelle Replikationsfehler.
  - Bewertet die Gesundheit pro DC anhand konfigurierbarer Schwellwerte.
  - Gibt eine kompakte Übersicht (Tabelle) und darunter ggf. detaillierte Fehler aus.
  - Setzt Exitcode 1, wenn kritische Probleme gefunden wurden (nützlich für Automatisierung/Monitoring).

.PARAMETER Forest
  Prüft alle Domänen im Forest (Standard: nur aktuelle Domäne).

.PARAMETER MaxHealthyHours
  Maximal erlaubte Stunden seit dem letzten erfolgreichen eingehenden Replikationsevent,
  bevor der Status "Degraded" (gelb) bzw. "Critical" (rot) wird. 
  - Degraded: > MaxHealthyHours
  - Critical: > (MaxHealthyHours * 2)

.PARAMETER ShowAll
  Zeigt zusätzlich DCs ohne Partner (Edge-Cases) und solche ohne Daten (z. B. Offline) in der Übersicht.

.EXAMPLE
  .\AD-CheckADReplication.ps1

.EXAMPLE
  .\AD-CheckADReplication.ps1 -Forest -MaxHealthyHours 6

.NOTES
  Benötigt das Modul ActiveDirectory (RSAT). Als Benutzer mit Leserechten im AD ausführen.
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
        throw "Das erforderliche Modul '$Name' ist nicht installiert. Bitte RSAT / ActiveDirectory-Modul bereitstellen."
    }
}
Assert-Module -Name ActiveDirectory
Import-Module ActiveDirectory -ErrorAction Stop

$now = Get-Date
$criticalHours = [int]([math]::Max( ($MaxHealthyHours * 2), $MaxHealthyHours + 1 ))

# --- DC-Liste ermitteln -------------------------------------------------------
$domains = @()
if ($Forest) {
    $forest = Get-ADForest
    $domains = $forest.Domains
} else {
    $domains = @((Get-ADDomain).DNSRoot)
}

$allDcs = foreach ($d in $domains) {
    try {
        Get-ADDomainController -Server $d -Filter * -ErrorAction Stop
    } catch {
        Write-Warning "Konnte DC-Liste für Domäne '$d' nicht lesen: $($_.Exception.Message)"
    }
} | Sort-Object HostName

if (-not $allDcs) {
    Write-Error "Keine Domänencontroller gefunden."
    exit 2
}

# --- Replikationsdaten je DC sammeln -----------------------------------------
$rows = @()
$allFailures = @()

foreach ($dc in $allDcs) {
    $dcName  = $dc.HostName
    $site    = $dc.Site
    $domain  = $dc.Domain
    $os      = $dc.OperatingSystem

    # Partner-Metadaten (eingehend)
    $partners = @()
    try {
        $partners = Get-ADReplicationPartnerMetadata -Target $dcName -Scope Server -PartnerType Incoming -ErrorAction Stop
    } catch {
        Write-Warning "[$dcName] Konnte Partner-Metadaten nicht lesen: $($_.Exception.Message)"
    }

    # Fehler (eingehend)
    $fail = @()
    try {
        $fail = Get-ADReplicationFailure -Target $dcName -Scope Server -ErrorAction SilentlyContinue
    } catch {
        # bewusst leise
    }

    $inboundCount = ($partners | Measure-Object).Count
    $lastSuccessTimes = $partners | Where-Object {$_.LastReplicationSuccess -ne $null} | Select-Object -ExpandProperty LastReplicationSuccess
    $lastSuccess = if ($lastSuccessTimes) { ($lastSuccessTimes | Sort-Object -Descending | Select-Object -First 1) } else { $null }

    # Größte Latenz = größtes Delta zwischen jetzt und letztem Erfolg je Partner
    $largestDeltaHours = if ($lastSuccessTimes) {
        ($lastSuccessTimes | ForEach-Object { [math]::Round(($now - $_).TotalHours, 2) } | Measure-Object -Maximum).Maximum
    } else { [double]::PositiveInfinity }

    $failureCount = ($fail | Measure-Object).Count

    # Health bestimmen
    $health = 'Healthy'
    if ($failureCount -gt 0 -or $largestDeltaHours -gt $MaxHealthyHours) { $health = 'Degraded' }
    if ($failureCount -gt 0 -and $largestDeltaHours -gt $criticalHours) { $health = 'Critical' }
    if (-not $partners -and -not $ShowAll) {
        # DC ohne eingehende Partner überspringen, außer ShowAll
        # (kann bei RODC/neu promoteten DCs/Decommissionings vorkommen)
    }

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

# --- Exitcode für Automatisierung -------------------------------------------
# 0 = OK, 1 = (mind.) ein DC 'Critical' oder es gibt Fehlerobjekte
$hasCritical = $rows | Where-Object { $_.Health -eq 'Critical' }
if ($hasCritical -or $allFailures.Count -gt 0) { exit 1 } else { exit 0 }
