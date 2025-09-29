<#
.SYNOPSIS
  Listet AD-Benutzer, die seit X Tagen nicht mehr aktiv waren.

.PARAMETER DaysInactive
  Anzahl Tage Inaktivität (Standard: 90)

.EXAMPLE
  .\Find-ADInactiveUsers.ps1 -DaysInactive 120
#>
[CmdletBinding()]
param([int]$DaysInactive = 90)

Import-Module ActiveDirectory
$cutoff = (Get-Date).AddDays(-$DaysInactive)

Get-ADUser -Filter * -Properties LastLogonDate |
  Where-Object { $_.Enabled -and $_.LastLogonDate -lt $cutoff } |
  Select-Object SamAccountName, DisplayName, LastLogonDate, Enabled |
  Sort-Object LastLogonDate
