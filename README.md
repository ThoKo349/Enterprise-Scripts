# 🛠 Enterprise-Scripts

Willkommen im **Enterprise-Scripts** Repository!  
Schnelle, praxistaugliche PowerShell-Skripte für Administration, Audits und Troubleshooting.  
Alle Skripte sind direkt aus GitHub per **Einzeiler** startbar.

---

## ⚡ Quick Start

**Beliebiges Skript direkt ausführen (Beispiel):**
```powershell
iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/Restart-VBR-Services.ps1")
irm = Invoke-RestMethod, iex = Invoke-Expression
Tipp: Für mehr Kontrolle Skript zuerst herunterladen, prüfen, dann starten.

📚 Inhaltsverzeichnis
🖥 System / Veeam (VBR)

🔍 Active Directory (AD)

🖥 Windows / Systemskripte (SYS)

🌐 Netzwerk (NET)

🗄️ SQL Server (SQL)

⚙️ Ausführung & Sicherheit

🤝 Mitwirken

🖥 System / Veeam (VBR)
Skript	Beschreibung	Einzeiler
Restart-VBR-Services.ps1	Startet alle relevanten Veeam Backup & Replication Dienste neu und prüft den Status.	powershell<br>iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/Restart-VBR-Services.ps1")<br>

🔍 Active Directory (AD)
Skript	Zweck	Einzeiler
AD-CheckADReplication.ps1	Kurzer Replikations-Gesundheitscheck via repadmin /replsummary.	powershell<br>iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/AD-CheckADReplication.ps1")<br>
AD-ExportGroups.ps1	Exportiert AD-Gruppen (z. B. zur Doku/Übersicht).	powershell<br>iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/AD-ExportGroups.ps1")<br>
AD-FindAdmins.ps1	Listet Mitglieder privilegierter Gruppen (Domain/Enterprise/Schema Admins).	powershell<br>iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/AD-FindAdmins.ps1")<br>
AD-FindInactiveComputers.ps1	Findet Computerobjekte ohne Logon seit X Tagen (Default 90).	powershell<br>iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/AD-FindInactiveComputers.ps1")<br>
AD-FindInactiveUsers.ps1	Findet Benutzer ohne Anmeldung seit X Tagen (Default 90).	powershell<br>iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/AD-FindInactiveUsers.ps1")<br>
AD-FindUsersNeverExpire.ps1	Benutzer mit „Passwort läuft nie ab“ – Audit/Security.	powershell<br>iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/AD-FindUsersNeverExpire.ps1")<br>

🖥 Windows / Systemskripte (SYS)
Skript	Zweck	Einzeiler
(Platzhalter)	z. B. SYS-ClearTemp.ps1 – Löscht Temp-Ordner & Update-Cache	powershell<br>iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/SYS-ClearTemp.ps1")<br>
(Platzhalter)	z. B. SYS-CheckDiskSpace.ps1 – Listet freien Speicher	powershell<br>iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/SYS-CheckDiskSpace.ps1")<br>

🌐 Netzwerk (NET)
Skript	Zweck	Einzeiler
(Platzhalter)	z. B. NET-TestConnectivity.ps1 – Ping, DNS, Traceroute	powershell<br>iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/NET-TestConnectivity.ps1")<br>

🗄️ SQL Server (SQL)
Skript	Zweck	Einzeiler
(Platzhalter)	z. B. SQL-CheckBackupStatus.ps1 – Prüft letzte Backups	powershell<br>iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/SQL-CheckBackupStatus.ps1")<br>

⚙️ Ausführung & Sicherheit
Nur aus vertrauenswürdigen Quellen ausführen (idealerweise aus deinem eigenen Repo).

Optional sicherer: erst herunterladen, prüfen, dann starten:

powershell
Code kopieren
$u = "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/AD-FindInactiveUsers.ps1"
$p = "$env:TEMP\AD-FindInactiveUsers.ps1"
Invoke-WebRequest -Uri $u -OutFile $p
& $p -DaysInactive 120
🤝 Mitwirken
Beiträge willkommen!
Falls du ein nützliches Skript oder Verbesserungsvorschläge hast:

Forke das Repo

Erstelle einen Branch (feature/dein-script)

Stelle einen Pull Request 🎉

yaml
Code kopieren
