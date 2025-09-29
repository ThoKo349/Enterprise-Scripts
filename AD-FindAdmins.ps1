<#
.SYNOPSIS
  Zeigt Mitglieder privilegierter AD-Gruppen.

.DESCRIPTION
  Prüft 'Domain Admins', 'Enterprise Admins' und 'Schema Admins'.
#>
Import-Module ActiveDirectory
$groups = 'Domain Admins','Enterprise Admins','Schema Admins'

foreach ($g in $groups) {
  Write-Host "`nMitglieder von $g:" -ForegroundColor Cyan
  Get-ADGroupMember -Identity $g -Recursive |
    Get-ADUser -Property DisplayName -ErrorAction SilentlyContinue |
    Select-Object SamAccountName, DisplayName
}
