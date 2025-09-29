<#
.SYNOPSIS
  Findet inaktive AD-Computerobjekte.

.PARAMETER DaysInactive
  Anzahl Tage Inaktivität (Standard: 90)

.EXAMPLE
  .\Find-ADInactiveComputers.ps1 -DaysInactive 180
#>
[CmdletBinding()]
param([int]$DaysInactive = 90)

Import-Module ActiveDirectory
$cutoff = (Get-Date).AddDays(-$DaysInactive)

Get-ADComputer -Filter * -Properties LastLogonDate,OperatingSystem |
  Where-Object { $_.LastLogonDate -lt $cutoff -or -not $_.LastLogonDate } |
  Select-Object Name, OperatingSystem, LastLogonDate |
  Sort-Object LastLogonDate
