<# 
  AD-CheckADReplication.ps1 (simple + Pause/Watch)
  - Zeigt den eingehenden Replikationsstatus je DC der aktuellen Domäne.
  - Bleibt am Ende offen (Enter zum Beenden).
  - Optional: Watch-Modus mit periodischer Aktualisierung.
#>

param(
    [int]$MaxHealthyHours = 12,  # Warnschwelle für maximale Replikationslatenz (Stunden)
    [switch]$Watch,              # Wenn gesetzt, aktualisiert die Ansicht periodisch
    [int]$IntervalSeconds = 15   # Aktualisierungsintervall im Watch-Modus
)

function Show-Status {
    $now = Get-Date

    try {
        $dcs = Get-ADDomainController -Filter * -ErrorAction Stop
    } catch {
        Write-Error "Domänencontroller konnten nicht gelesen werden: $($_.Exception.Message)"
        return
    }

    $rows = foreach ($dc in $dcs) {
        $dcName = $dc.HostName

        # Partner (eingehend)
        $partners = @()
        try { $partners = Get-ADReplicationPartnerMetadata -Target $dcName -Scope Server -PartnerType Incoming -ErrorAction Stop } catch {}
        $inboundCount = ($partners | Measure-Object).Count

        $lastSuccessTimes = $partners | Where-Object { $_.LastReplicationSuccess } | Select-Object -ExpandProperty LastReplicationSuccess
        $lastSuccess = if ($lastSuccessTimes) { ($lastSuccessTimes | Sort-Object -Descending | Select-Object -First 1) } else { $null }
        $maxDelta = if ($lastSuccessTimes) {
            ($lastSuccessTimes | ForEach-Object { ($now - $_).TotalHours } | Measure-Object -Maximum).Maximum
        } else { $null }

        # Fehler (eingehend)
        $fail = @(); try { $fail = Get-ADReplicationFailure -Target $dcName -Scope Server -ErrorAction SilentlyContinue } catch {}
        $failureCount = ($fail | Measure-Object).Count

        $health = 'OK'
        if ($failureCount -gt 0 -or ($maxDelta -ne $null -and $maxDelta -gt $MaxHealthyHours)) { $health = 'Problem' }

        [PSCustomObject]@{
            DC           = $dcName
            Site         = $dc.Site
            InboundLinks = $inboundCount
            LastSuccess  = if ($lastSuccess) { $lastSuccess.ToString('yyyy-MM-dd HH:mm') } else { 'n/a' }
            MaxDelta_h   = if ($maxDelta -ne $null) { [math]::Round($maxDelta,2) } else { 'n/a' }
            Failures     = $failureCount
            Health       = $health
        }
    }

    Clear-Host
    Write-Host "AD-Replikationsprüfung (eingehend) – $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    $rows | Sort-Object Health, DC | Format-Table -AutoSize
}

# Modul laden
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory-Modul nicht gefunden. Bitte RSAT installieren."
    Read-Host "`nDrücke Enter zum Schließen"
    exit 2
}
Import-Module ActiveDirectory -ErrorAction Stop

if ($Watch) {
    while ($true) {
        Show-Status
        Write-Host ""
        Write-Host "Aktualisiere wieder in $IntervalSeconds s ... (Beenden mit STRG+C)" -ForegroundColor Yellow
        Start-Sleep -Seconds $IntervalSeconds
    }
} else {
    Show-Status
    # Hält das Fenster offen, bis Enter gedrückt wird
    Read-Host "`nFertig. Drücke Enter zum Schließen"
}
