<# 
.SYNOPSIS
  Stoppt alle Veeam-Dienste, wartet 5 Sekunden und startet sie wieder.

.HINWEIS
  Mit Administratorrechten ausführen!
#>

# 1. Alle Veeam-Dienste stoppen
Write-Host "Stoppe alle Veeam-Dienste..." -ForegroundColor Cyan
Get-Service -Name "Veeam*" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        Stop-Service -Name $_.Name -Force -ErrorAction Stop
        Write-Host "Gestoppt: $($_.DisplayName)"
    } catch {
        Write-Warning "Konnte $($_.DisplayName) nicht stoppen: $($_.Exception.Message)"
    }
}

# 2. 5 Sekunden warten
Write-Host "Warte 5 Sekunden..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# 3. Alle Veeam-Dienste starten
Write-Host "Starte alle Veeam-Dienste..." -ForegroundColor Cyan
Get-Service -Name "Veeam*" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        Start-Service -Name $_.Name -ErrorAction Stop
        Write-Host "Gestartet: $($_.DisplayName)"
    } catch {
        Write-Warning "Konnte $($_.DisplayName) nicht starten: $($_.Exception.Message)"
    }
}

# 4. Status-Tabelle ausgeben
Write-Host "`nAktueller Status der Veeam-Dienste:" -ForegroundColor Green
Get-Service -Name "Veeam*" -ErrorAction SilentlyContinue |
    Sort-Object Name |
    Select-Object Name, DisplayName, Status |
    Format-Table -AutoSize
