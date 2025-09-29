<# 
.SYNOPSIS
  Startet Veeam-Dienste neu und prüft den Zustand der wichtigsten Services.

.PARAMETER IncludeNonCritical
  Nimmt zusätzlich alle weiteren Veeam-Dienste (Name "Veeam*") in den Neustart/Check auf.

.PARAMETER TimeoutSec
  Maximale Wartezeit pro Dienst, bis der Status "Running" erreicht ist. Standard: 60 Sekunden.

.PARAMETER SkipRestart
  Überspringt den Neustart und führt nur die Gesundheitsprüfung durch.

.EXAMPLE
  .\Check-VeeamServices.ps1

.EXAMPLE
  .\Check-VeeamServices.ps1 -IncludeNonCritical -TimeoutSec 90
#>

[CmdletBinding()]
param(
  [switch]$IncludeNonCritical,
  [int]$TimeoutSec = 60,
  [switch]$SkipRestart
)

# --- Konfiguration: "wichtige" Veeam Services (nach Bedarf anpassen) ---
# Namen sind ServiceNames, NICHT DisplayNames
$CriticalServiceNames = @(
  'VeeamBackupSvc',            # Veeam Backup Service
  'VeeamBrokerSvc',            # Veeam Broker Service
  'VeeamCatalogSvc',           # Veeam Backup Catalog Data Service
  'VeeamMountSvc',             # Veeam Mount Service
  'VeeamNFSSvc',               # Veeam vPower NFS Service
  'VeeamTransportSvc',         # Veeam Data Movers/Transport
  'VeeamTapeSvc',              # Veeam Tape Access Service (falls vorhanden)
  'VeeamInstallerSvc',         # Veeam Installer Service
  'VeeamDeploySvc',            # Veeam Deploy Service
  'VeeamRESTSvc',              # Veeam RESTful API Service (VBR/Enterprise Manager)
  'VeeamEnterpriseManagerSvc', # Enterprise Manager Web Service
  'VeeamAgentSvc'              # Veeam Agent for Microsoft Windows Service (falls auf dem Host)
) | Select-Object -Unique

function Get-ServiceSafe {
  param([string]$Name)
  try { return Get-Service -Name $Name -ErrorAction Stop } catch { return $null }
}

function Wait-ServiceRunning {
  param(
    [string]$Name,
    [int]$TimeoutSec = 60
  )
  $sw = [Diagnostics.Stopwatch]::StartNew()
  do {
    $svc = Get-ServiceSafe -Name $Name
    if ($null -eq $svc) { return $false }
    if ($svc.Status -eq 'Running') { return $true }
    Start-Sleep -Seconds 1
    try {
      if ($svc.Status -ne 'Running' -and $svc.Status -ne 'StartPending') {
        Start-Service -Name $Name -ErrorAction SilentlyContinue
      }
    } catch { }
  } while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec)
  return $false
}

function Restart-ServiceSafe {
  param(
    [string]$Name,
    [int]$TimeoutSec = 60
  )
  $svc = Get-ServiceSafe -Name $Name
  if ($null -eq $svc) {
    Write-Verbose "Dienst '$Name' nicht gefunden – übersprungen."
    return @{ Name = $Name; Restarted = $false; Success = $false; Error = "NotFound" }
  }

  try {
    if ($svc.Status -eq 'Stopped') {
      Write-Verbose "Dienst '$Name' ist gestoppt – starte."
      Start-Service -Name $Name -ErrorAction Stop
    } else {
      Write-Verbose "Neustart von '$Name'…"
      Restart-Service -Name $Name -Force -ErrorAction Stop
    }
  } catch {
    Write-Warning "Neustart von '$Name' fehlgeschlagen: $($_.Exception.Message). Versuche Soft-Stop/Start…"
    try {
      Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
      Start-Sleep -Seconds 2
      Start-Service -Name $Name -ErrorAction Stop
    } catch {
      return @{ Name = $Name; Restarted = $false; Success = $false; Error = $_.Exception.Message }
    }
  }

  $ok = Wait-ServiceRunning -Name $Name -TimeoutSec $TimeoutSec
  return @{ Name = $Name; Restarted = $true; Success = $ok; Error = $ok ? $null : "Timeout ($TimeoutSec s)" }
}

# --- Ermittlung Zielmenge ---
$allVeeam = Get-Service -Name 'Veeam*' -ErrorAction SilentlyContinue | Sort-Object -Property Name
$critSet  = $CriticalServiceNames

if (-not $allVeeam) {
  Write-Error "Keine Dienste mit 'Veeam*' gefunden. Auf dem System sind wohl keine Veeam-Dienste installiert."
  exit 2
}

$target = if ($IncludeNonCritical) {
  $allVeeam
} else {
  $allVeeam | Where-Object { $critSet -contains $_.Name }
}

if (-not $target) {
  Write-Warning "Keine der als 'wichtig' definierten Veeam-Dienste ist auf diesem Host installiert."
  # Fallback: Prüfe zumindest alle vorhandenen Veeam-Dienste
  $target = $allVeeam
}

Write-Host "Zielanzahl Dienste: $($target.Count)" -ForegroundColor Cyan

# --- Neustart (optional) ---
$restartResults = @()
if (-not $SkipRestart) {
  foreach ($svc in $target) {
    $res = Restart-ServiceSafe -Name $svc.Name -TimeoutSec $TimeoutSec
    $restartResults += [pscustomobject]$res
  }
}

# --- Gesundheitsprüfung / Inventar ---
# Für StartType/StartMode nutzen wir CIM (Get-Service zeigt keinen StartType an)
$cim = Get-CimInstance Win32_Service -Filter "Name LIKE 'Veeam%'" |
       Select-Object Name, DisplayName, State, Status, StartMode

$report = foreach ($svc in $target) {
  $ci = $cim | Where-Object { $_.Name -eq $svc.Name }
  [pscustomobject]@{
    Name        = $svc.Name
    DisplayName = $svc.DisplayName
    Status      = $svc.Status
    StartMode   = if ($ci) { $ci.StartMode } else { $null }
    IsCritical  = ($critSet -contains $svc.Name)
  }
}

# Nach Neustart Status aktualisieren
$report = $report | ForEach-Object {
  $live = Get-ServiceSafe -Name $_.Name
  $ci   = $cim | Where-Object { $_.Name -eq $live.Name }
  [pscustomobject]@{
    Name        = $_.Name
    DisplayName = $live.DisplayName
    Status      = $live.Status
    StartMode   = if ($ci) { $ci.StartMode } else { $null }
    IsCritical  = $_.IsCritical
  }
}

# --- Auswertung ---
$criticalIssues = $report | Where-Object { $_.IsCritical -and $_.Status -ne 'Running' }
$autoStopped    = $report | Where-Object { $_.StartMode -like 'Auto*' -and $_.Status -ne 'Running' }

# Ausgabe
if (-not $SkipRestart) {
  Write-Host "`nNeustart-Ergebnisse:" -ForegroundColor Cyan
  $restartResults | Sort-Object Name | Format-Table Name, Restarted, Success, Error -AutoSize
}

Write-Host "`nDienstestatus:" -ForegroundColor Cyan
$report | Sort-Object IsCritical -Descending, Name | Format-Table Name, Status, StartMode, IsCritical -AutoSize

if ($criticalIssues) {
  Write-Host "`nWARNUNG: Mindestens ein wichtiger Veeam-Dienst läuft nicht:" -ForegroundColor Yellow
  $criticalIssues | Format-Table Name, Status, StartMode -AutoSize
}

if ($autoStopped) {
  Write-Host "`nHinweis: Folgende Dienste haben StartMode 'Auto*', laufen aber nicht:" -ForegroundColor Yellow
  $autoStopped | Format-Table Name, Status, StartMode -AutoSize
}

# Exitcode für Automatisierung/Monitoring
if ($criticalIssues) { exit 1 } else { exit 0 }
