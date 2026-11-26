# UHDServiceDesk

PowerShell-7-Modul für das Ticketsystem **UHD Service Desk** (in der Aufzeichnung als CA Service Desk Manager ausgewiesen). Ziel: Tickets abrufen, anlegen, ändern und abschließen.

**Status: Proof of Concept, Phase 2 begonnen.**

| Bereich | Stand |
|---|---|
| Analyse der HAR-Aufzeichnungen | weitgehend abgeschlossen, siehe `docs/analysis.md` |
| `Connect-UHD` / `Disconnect-UHD` | implementiert, **ungetestet** gegen das Live-System |
| `Get-UHDTicket` und weitere Cmdlets | Platzhalter (`NotImplementedException`) |
| Pester-Tests | geschrieben, **nicht ausgeführt** (pwsh in der Entwicklungsumgebung fehlt) |

## Voraussetzungen

- PowerShell 7.0 oder neuer
- Zugang zum Ticketsystem mit Benutzername und Kennwort (formularbasierte Anmeldung)
- Pester 5 und PSScriptAnalyzer für Tests und statische Analyse

## Verwendung (Stand Proof of Concept)

```powershell
Import-Module ./src/UHDServiceDesk/UHDServiceDesk.psd1

# Erster Aufruf: Login-Fenster, danach werden die Zugangsdaten gespeichert
Connect-UHD -Verbose

# Kennwort geändert: Zugangsdaten neu abfragen
Connect-UHD -ResetCredential

Disconnect-UHD
```

Die Cmdlets `Get-UHDTicket`, `Set-UHDTicket` usw. existieren als Platzhalter und werfen derzeit eine Ausnahme.

## Konfiguration

Pfad der Konfigurationsdatei, in dieser Reihenfolge:
1. Parameter `-ConfigPath`
2. Umgebungsvariable `UHD_CONFIG_PATH`
3. `%APPDATA%\UHDServiceDesk\config.json`

Vorlage: `config.example.json`. Relevante Schlüssel:

| Schlüssel | Bedeutung |
|---|---|
| `BaseUrl` | Basis-URL bis `/CAisd/`, muss `https://` sein |
| `CredentialPath` | Ort der gespeicherten Zugangsdaten. Relativ zum Ordner der Konfigurationsdatei. Standard: `uhd.credential.xml` im selben Ordner |
| `TimeoutSec` | Timeout pro Request in Sekunden, Standard 60 |

Die Konfigurationsdatei und die Credential-Datei werden nicht versioniert.

## Sicherheit

- Keine Zugangsdaten, Session-IDs oder Tokens im Quellcode, in der Dokumentation oder in Commits.
- HAR-Aufzeichnungen liegen in `captures/` und sind per `.gitignore` ausgeschlossen. Sie enthalten Klartext-Kennwörter.
- TLS-Zertifikatsprüfung bleibt aktiv.
- Logs maskieren SID und PIN über `ConvertTo-UHDMaskedUrl`.
- Schreibende Requests werden nie automatisch wiederholt.

## Projektstruktur

```
src/UHDServiceDesk/   Modul (psd1, psm1, Public/, Private/)
docs/                 Analyse, Endpunkte, Authentifizierung, Architektur
captures/             HAR-Dateien (nicht versioniert)
examples/             Anwendungsbeispiele
tests/                Pester-Tests
```

## Entwicklung

- Branch: `develop`. Kein Merge nach `main` ohne Freigabe.
- Commit-Nachrichten auf Englisch.
- Vor jedem Commit: Pester und PSScriptAnalyzer ausführen.
