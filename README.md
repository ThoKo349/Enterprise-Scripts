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

## 🖥 System / Veeam (VBR)

| Skript | Beschreibung | Einzeiler |
|---|---|---|
| **VBR-RestartAndCheckServices.ps1** | Stopt und startet alle Dienste von Veeam Backup and Replication. | `iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/VBR-RestartAndCheckServices.ps1")` |

---

## Microsoft Active Directory

| Skript | Zweck | Einzeiler |
|---|---|---|
| **AD-CheckADReplication.ps1** | Prüft den Status der AD Replication. | `iex (irm "https://raw.githubusercontent.com/ThoKo349/Enterprise-Scripts/main/AD-CheckADReplication.ps1")` |

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
