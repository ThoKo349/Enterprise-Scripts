<# 
.SYNOPSIS
  Neustartet alle Windows-Dienste, deren Name mit 'Veeam*' beginnt, wartet kurz,
  und zeigt anschließend eine Status-Tabelle an.

.HINWEIS
  Als Administrator ausführen.
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [int]$TimeoutSeconds = 30
)

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Error "Dieses Skript muss mit Administratorrechten ausgeführt werden."
    exit 1
}

# Dienste einsammeln
$services = Get-Service -Name 'Veeam*' -ErrorAction SilentlyContinue | Sort-Object Name
if (-not $services) {
    Write-Warning "Keine Dienste gefunden, die mit 'Veeam*' beginnen."
    return
}

# Warten ohne .ToString() und robust gegen $null
function Wait-ServiceStatus {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [ValidateSet('Running','Stopped','Paused')] [string]$DesiredStatus,
        [int]$Timeout = 30
    )
    $desiredEnum = [System.ServiceProcess.ServiceControllerStatus]::$DesiredStatus
    $sw = [Diagnostics.Stopwatch]::StartNew()
    do {
        $s = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($s -and $s.Status -eq $desiredEnum) { return $true }
        Start-Sleep -Milliseconds 500
    } while ($sw.Elapsed.TotalSeconds -lt $Timeout)
    return $false
}

$errors = @()

foreach ($svc in $services) {
    try {
        if ($PSCmdlet.ShouldProcess($svc.Name, "Restart/Start")) {
            if ($svc.Status -eq 'Running') {
                try {
                    Restart-Service -Name $svc.Name -Force -ErrorAction Stop
                } catch {
                    Write-Verbose "Restart-Service für $($svc.Name) fehlgeschlagen, versuche Stop/Start. $_"
                    Stop-Service -Name $svc.Name -Force -ErrorAction Stop
                    Start-Service -Name $svc.Name -ErrorAction Stop
                }
            } else {
                Start-Service -Name $svc.Name -ErrorAction Stop
            }

            # Immer auf 'Running' warten; das ist robust und einfach
            $ok = Wait-ServiceStatus -Name $svc.Name -DesiredStatus 'Running' -Timeout $TimeoutSeconds
            if (-not $ok) {
                $errors += [PSCustomObject]@{
                    Service = $svc.Name
                    Action  = 'Start/Restart'
                    Message = "Dienst wurde nicht innerhalb von $TimeoutSeconds s 'Running'."
                }
            }
        }
    } catch {
        $errors += [PSCustomObject]@{
            Service = $svc.Name
            Action  = 'Start/Restart'
            Message = $_.Exception.Message
        }
    }
}

# Abschluss: Status-Tabelle (Startmodus via CIM, da Get-Service kein StartType zuverlässig liefert)
# Fällt bei Bedarf auf 'Unbekannt' zurück, falls CIM für einzelne Dienste nicht auflösbar ist.
$cim = Get-CimInstance -ClassName Win32_Service -Filter "Name LIKE 'Veeam%'" -ErrorAction SilentlyContinue |
       Group-Object Name -AsHashTable -AsString

$report =
    Get-Service -Name 'Veeam*' -ErrorAction SilentlyContinue |
    Sort-Object Name |
    Select-Object `
        Name,
        DisplayName,
        @{Name='Läuft'; Expression = { if ($_.Status -eq 'Running') { 'Ja' } else { 'Nein' } }},
        Status,
        @{Name='StartMode'; Expression = {
            if ($cim.ContainsKey($_.Name)) { $cim[$_.Name].StartMode } else { 'Unbekannt' }
        }}

$report | Format-Table -AutoSize

if ($errors.Count -gt 0) {
    Write-Host "`nHinweise/Fehler:" -ForegroundColor Yellow
    $errors | Format-Table -AutoSize
}
