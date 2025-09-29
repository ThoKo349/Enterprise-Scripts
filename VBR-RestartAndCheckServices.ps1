<# 
.SYNOPSIS
  Neustartet alle Windows-Dienste, deren Name mit 'Veeam*' beginnt, wartet kurz,
  und zeigt anschließend eine Status-Tabelle (laufend/nicht laufend) an.

.HINWEIS
  Als Administrator ausführen.
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    # Wartezeit (Sek.) nach Start/Neustart pro Dienst
    [int]$TimeoutSeconds = 30
)

function Test-Admin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
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

# Hilfsfunktion: auf gewünschten Status warten
function Wait-ServiceStatus {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [ValidateSet('Running','Stopped','Paused')]
        [string]$DesiredStatus,
        [int]$Timeout = 30
    )
    $sw = [Diagnostics.Stopwatch]::StartNew()
    do {
        $s = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($null -ne $s -and $s.Status.ToString() -eq $DesiredStatus) {
            return $true
        }
        Start-Sleep -Milliseconds 500
    } while ($sw.Elapsed.TotalSeconds -lt $Timeout)

    return $false
}

$errors = @()

foreach ($svc in $services) {
    try {
        if ($PSCmdlet.ShouldProcess($svc.Name, "Restart/Start")) {
            # Wenn gerade läuft: sauber neustarten
            if ($svc.Status -eq 'Running') {
                try {
                    Restart-Service -Name $svc.Name -Force -ErrorAction Stop
                } catch {
                    # Falls Restart scheitert, versuchen wir Stop/Start separat
                    Write-Verbose "Restart-Service für $($svc.Name) fehlgeschlagen, versuche Stop/Start. $_"
                    Stop-Service -Name $svc.Name -Force -ErrorAction Stop
                    Start-Service -Name $svc.Name -ErrorAction Stop
                }
            } else {
                # Lief nicht -> starten (kein erzwungener Stop)
                Start-Service -Name $svc.Name -ErrorAction Stop
            }

            # Auf Running warten (aber nur für StartType nicht 'Disabled')
            $svcRefreshed = Get-Service -Name $svc.Name
            if ($svcRefreshed.StartType -ne 'Disabled') {
                $ok = Wait-ServiceStatus -Name $svc.Name -DesiredStatus 'Running' -Timeout $TimeoutSeconds
                if (-not $ok) {
                    $errors += [PSCustomObject]@{
                        Service    = $svc.Name
                        Action     = 'Start/Restart'
                        Message    = "Dienst wurde nicht innerhalb von $TimeoutSeconds s 'Running'."
                    }
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

# Abschluss: Status-Tabelle zeigen
$report =
    Get-Service -Name 'Veeam*' -ErrorAction SilentlyContinue |
    Sort-Object Name |
    Select-Object `
        Name,
        DisplayName,
        @{Name='Läuft'; Expression = { if ($_.Status -eq 'Running') { 'Ja' } else { 'Nein' } }},
        Status,
        StartType

$report | Format-Table -AutoSize

# Eventuelle Fehlermeldungen gesammelt ausgeben
if ($errors.Count -gt 0) {
    Write-Host "`nHinweise/Fehler:" -ForegroundColor Yellow
    $errors | Format-Table -AutoSize
}
