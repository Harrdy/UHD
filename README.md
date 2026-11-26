# UHDServiceDesk

PowerShell-7-Modul für den UHD Service Desk (CA Service Desk Manager).

**Stand: Phase 2, Proof of Concept 0.2.0.** Anmeldung, Ticketsuche, Detailabruf und Abmeldung wurden als zusammenhängender Ablauf offline mit synthetischen Antworten geprüft. Es gibt keine Live-Verifikation.

| Cmdlet | Stand |
|---|---|
| `Connect-UHD`, `Disconnect-UHD` | Formularanmeldung und Sitzungsende; optionaler Menü-Logout |
| `Find-UHDTicket -GroupMemberId` | Suche nach numerischen Gruppenmitglieds-IDs; nur erste Seite, kein Freitextfilter |
| `Get-UHDTicket -Id` | Liest unterstützte Detailantworten zu einer internen numerischen Ticket-ID |
| `Get-UHDStatus -Id -Status` | Liest einen Statusübergang, wenn die Antwort aus genau einem `CODE@Bezeichnung`-Eintrag besteht |
| `Get-UHDTicket -Children`, `Get-UHDTicketAttachment` | Die dokumentierten Requests sind implementiert. Das Antwortformat ist offen; die Cmdlets melden einen Fehler statt einer leeren Liste. Kein Download. |
| Änderung, Abschluss, Kommentar, Upload, Benutzer-/Gruppensuche und Kataloge | Nicht verfügbar. Insbesondere senden `New-UHDTicket` und `Set-UHDTicket` keine Requests. |

Die [Endpunktmatrix](docs/endpoints.md) unterscheidet zwischen getestetem Request-Aufbau, ausgewerteten Antwortformaten und offenen Protokolldetails. [Beispiele](examples/README.md) zeigen den Offline-Test und die öffentliche API.

## Voraussetzungen und Konfiguration

PowerShell 7.0 oder neuer. Für Offline-Tests und statische Analyse müssen Pester 5 und PSScriptAnalyzer lokal verfügbar sein. Die Offline-Tests benötigen kein UHD-Konto.

Für eine ausdrücklich freigegebene Verbindung eine lokale Konfiguration nach [config.example.json](config.example.json) anlegen. Das Modul sucht sie in dieser Reihenfolge:

1. `Connect-UHD -ConfigPath`
2. Umgebungsvariable `UHD_CONFIG_PATH`
3. `UHDServiceDesk/config.json` unter dem Anwendungsdatenordner des Benutzers (unter Windows: `%APPDATA%`)

| Schlüssel | Bedeutung |
|---|---|
| `BaseUrl` | HTTPS-Basis-URL bis `/CAisd/`, ohne Benutzerinformationen, Query oder Fragment |
| `CredentialPath` | Absolut oder relativ zum Konfigurationsordner; Standard: `uhd.credential.xml` in diesem Ordner |
| `TimeoutSec` | Timeout in Sekunden (5–600, Standard 60) |

Keine lokalen Konfigurationen, Credential-Dateien oder HAR-Dateien versionieren. Mit explizitem `-Credential` speichert das Modul keine Anmeldedaten; diese Variante wird insbesondere außerhalb von Windows empfohlen. Details: [Authentifizierung](docs/authentication.md).

## Offline prüfen

Aus dem Repository-Root in einer PowerShell-7-Sitzung:

```powershell
Import-Module ./src/UHDServiceDesk/UHDServiceDesk.psd1 -Force
Get-Command -Module UHDServiceDesk -CommandType Function

$config = New-PesterConfiguration
$config.Run.Path = './tests'
$config.Run.Exit = $true
Invoke-Pester -Configuration $config
```

Die Tests mocken die Serverantworten; ein zusätzlicher Test prüft eine Verbindungsverweigerung lokal über Loopback. Für die statische Analyse in einer separaten PowerShell-Sitzung:

```powershell
Invoke-ScriptAnalyzer -Path ./src/UHDServiceDesk -Recurse -ExcludeRule PSUseBOMForUnicodeEncodedFile
```

Die ausgeschlossene Regel empfiehlt für Windows PowerShell einen BOM. Das Modul richtet sich an PowerShell 7; das Repository verwendet UTF-8 gemäß `.editorconfig`.

## Entwicklung

- [Architektur](docs/architecture.md) und [Analyse / offene Punkte](docs/analysis.md)
- Keine Tests am Live-System ohne ausdrückliche Freigabe und vorgesehene Testtickets. TLS-Zertifikatsprüfung bleibt aktiv; Logs entfernen die ganze URL-Query.
- Nach einer erfolgreichen Coding-Session mit bestandenen Pester- und PSScriptAnalyzer-Prüfungen die eigenen Änderungen mit englischer Commit-Nachricht committen und auf `origin/develop` pushen. Kein Merge nach `main`, kein Force-Push.
