<#
.SYNOPSIS
  Exportiert die Mitglieder einer AD-Gruppe.

.PARAMETER GroupName
  Name der AD-Gruppe

.EXAMPLE
  .\Export-ADGroupMembership.ps1 -GroupName "Domain Admins"
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$GroupName)

Import-Module ActiveDirectory
Get-ADGroupMember -Identity $GroupName -Recursive |
  Get-ADUser -Property DisplayName -ErrorAction SilentlyContinue |
  Select-Object SamAccountName, DisplayName, Enabled
