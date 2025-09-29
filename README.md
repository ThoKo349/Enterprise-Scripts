# 🛠 Enterprise-Scripts

Willkommen im **Enterprise-Scripts** Repository!  
Schnelle, praxistaugliche PowerShell-Skripte für Administration, Audits und Troubleshooting.  
Alle Skripte sind direkt aus GitHub per **Einzeiler** startbar.

---

## ⚡ Quick Start

**Beliebiges Skript direkt ausführen (Beispiel):**
```powershell
iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/SCRIPT-NAME.ps1")
```

---

## 📚 Inhaltsverzeichnis
- [🖥 System / Veeam (VBR)](#-system--veeam-vbr)
- [🔍 Active Directory (AD)](#-active-directory-ad)
- [🖥 Windows / Systemskripte (SYS)](#-windows--systemskripte-sys)
- [⚙️ Ausführung & Sicherheit](#️-ausführung--sicherheit)
- [🤝 Mitwirken](#-mitwirken)

---

## 🖥 System / Veeam (VBR)

| Skript | Beschreibung | Einzeiler |
|---|---|---|
| **VBR-RestartAndCheckServices.ps1** | Startet alle relevanten **Veeam Backup & Replication** Dienste neu und prüft den Status. | `iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/VBR-RestartAndCheckServices.ps1")` |

---

## 🔍 Active Directory (AD)

| Skript | Zweck | Einzeiler |
|---|---|---|
| **AD-CheckADReplication.ps1** | Kurzer Replikations-Gesundheitscheck via `repadmin /replsummary`. | `iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/AD-CheckADReplication.ps1")` |
| **AD-ExportGroups.ps1** | Exportiert AD-Gruppen (z. B. zur Doku/Übersicht). | `iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/AD-ExportGroups.ps1")` |
| **AD-FindAdmins.ps1** | Listet Mitglieder privilegierter Gruppen (Domain/Enterprise/Schema Admins). | `iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/AD-FindAdmins.ps1")` |
| **AD-FindInactiveComputers.ps1** | Findet Computerobjekte ohne Logon seit X Tagen (Default 90). | `iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/AD-FindInactiveComputers.ps1")` |
| **AD-FindInactiveUsers.ps1** | Findet Benutzer ohne Anmeldung seit X Tagen (Default 90). | `iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/AD-FindInactiveUsers.ps1")` |
| **AD-FindUsersNeverExpire.ps1** | Benutzer mit „Passwort läuft nie ab“ – Audit/Security. | `iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/AD-FindUsersNeverExpire.ps1")` |

---

## 🖥 Windows / Systemskripte (SYS)

| Skript | Zweck | Einzeiler |
|---|---|---|
| **SYS-ClearTemp.ps1** | Bereinigt Temp-Ordner und optional den Windows Update Cache. | `iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/SYS-ClearTemp.ps1")` |
| **SYS-CheckDiskSpace.ps1** | Listet freien Speicherplatz aller Laufwerke und warnt bei <10%. | `iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/SYS-CheckDiskSpace.ps1")` |
| **SYS-CheckEventlog.ps1** | Zeigt kritische/Fehler-Events der letzten 24h. | `iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/SYS-CheckEventlog.ps1")` |
| **SYS-CheckPendingReboot.ps1** | Prüft, ob ein Neustart aussteht und zeigt Gründe. | `iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/SYS-CheckPendingReboot.ps1")` |

---

## ⚙️ Ausführung & Sicherheit

- **Nur aus vertrauenswürdigen Quellen** ausführen (idealerweise aus deinem eigenen Repo).
- Optional sicherer: erst herunterladen, prüfen, dann starten:
  ```powershell
  $u = "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/AD-FindInactiveUsers.ps1"
  $p = "$env:TEMP\AD-FindInactiveUsers.ps1"
  Invoke-WebRequest -Uri $u -OutFile $p
  & $p -DaysInactive 120
  ```

---

## 🤝 Mitwirken

Beiträge willkommen!  
Falls du ein nützliches Skript oder Verbesserungsvorschläge hast:
1. Forke das Repo  
2. Erstelle einen Branch (`feature/dein-script`)  
3. Stelle einen Pull Request 🎉  
