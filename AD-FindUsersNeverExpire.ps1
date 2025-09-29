<#
.SYNOPSIS
  Listet Benutzer, deren Passwort nie abläuft.
#>
Import-Module ActiveDirectory

Get-ADUser -Filter * -Properties PasswordNeverExpires |
  Where-Object { $_.PasswordNeverExpires -eq $true } |
  Select-Object SamAccountName, DisplayName, Enabled
