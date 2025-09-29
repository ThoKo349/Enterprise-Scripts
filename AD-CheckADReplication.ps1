<#
.SYNOPSIS
  Führt eine AD-Replikationsprüfung durch.
#>
Write-Host "Starte AD-Replikationsprüfung..." -ForegroundColor Cyan
repadmin /replsummary
