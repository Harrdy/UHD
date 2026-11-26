# Offline-Tests und Leseproben

Arbeite aus dem Repository-Root in PowerShell 7. Die beiden Prüfscripte geben
Strukturmerkmale aus, keine Rohantworten. **Teile nur die bereinigte JSON-Ausgabe,
niemals HAR-Dateien, vollständige URLs, HTML oder gewöhnliche Cmdlet-Ausgaben mit
Ticketdaten.**

## Offline mit synthetischen Antworten prüfen

Der Pester-Test prüft Anmeldung, Suche, Detailabruf und Abmeldung mit
synthetischen Antworten. Ein UHD-Konto und eine Konfiguration sind nicht nötig.

```powershell
$config = New-PesterConfiguration
$config.Run.Path = './tests/TicketRead.Tests.ps1'
$config.Filter.FullName = '*verbindet, sucht, liest Details und meldet offline ab*'
$config.Run.Exit = $true
Invoke-Pester -Configuration $config
```

## Eine freigegebene Leseprobe ausführen

Nur mit ausdrücklicher Freigabe für das **dafür vorgesehene Testticket**.
Verwende eine PowerShell-Sitzung mit genau einem geladenen UHDServiceDesk-Modul
und bereits aktiver UHD-Sitzung. Das Skript meldet dich weder an noch ab.
`-ApprovedLiveRead` bestätigt eine vorhandene Freigabe; es erteilt keine.

Der Parameter `-TestTicketId` erwartet die numerische **interne Ticket-ID**,
nicht die sichtbare Ticketnummer `RefNum`. Gib sie lokal ein. Wähle je Aufruf
genau einen Fall. Die Aufrufvarianten wurden mit gemocktem Transport getestet,
nicht im Live-System.

```powershell
$testId = Read-Host 'Interne ID des freigegebenen Testtickets'
./examples/Invoke-UHDReadProbe.ps1 -Case Children -TestTicketId $testId -ApprovedLiveRead |
    ConvertTo-Json -Depth 8
```

| `-Case` | Geeignetes, bereits vorhandenes Testticket |
|---|---|
| `Detail` | Ticket mit den zu prüfenden Detailfeldern, etwa Kategorie und Elternticket |
| `Children` | Elternticket mit mindestens einem vorhandenen Unterticket |
| `Attachments` | Ticket mit mindestens einem vorhandenen Anhang; die Probe liest nur die Liste |
| `Activities` | Ticket mit vorhandenem Aktivitätsverlauf; bei Freigabe zusätzlich ein Ticket ohne Aktivitäten, falls verfügbar |
| `Transitions` | Incident mit bekanntem Status-Kurzcode und bekannter Mandantenkennung |

Für Statusübergänge sind beide Zusatzwerte erforderlich. Die Mandantenkennung
hat 32 Hex-Zeichen. Die Probe ändert keinen Status.

```powershell
$testId = Read-Host 'Interne ID des freigegebenen Testtickets'
$status = Read-Host 'Aktueller Status-Kurzcode'
$tenant = Read-Host 'Mandantenkennung (32 Hex-Zeichen)'
./examples/Invoke-UHDReadProbe.ps1 -Case Transitions -TestTicketId $testId -ApprovedLiveRead -Status $status -TenantId $tenant |
    ConvertTo-Json -Depth 8
```

Pro Aufruf sendet das Skript höchstens einen belegten GET-Request für das gewählte
Ticket. Es folgt keinen Links, lädt keine Anhänge herunter und führt keine
Änderungen aus. Die Ausgabe enthält nur den ausgewählten Fall, den HTTP-Status
und bereinigte Antwortmerkmale. Diese Merkmale sind Hinweise auf die Struktur,
kein Nachweis, dass alle Felder ausgewertet werden können.

## Einen vorhandenen Browsermitschnitt offline auswerten

Nutze nur eine bereits vorhandene Aufzeichnung einer freigegebenen lesenden
Browseraktion. Erstelle oder ändere dafür keine Tickets und öffne keinen
Bearbeitungsmodus. Das Skript liest ausschließlich die lokale Datei, ruft kein
System auf und speichert nichts. Bestehende `Page`- oder `ListDetail`-Requests
werden nur im Mitschnitt erkannt, niemals wiederholt.

```powershell
$har = Read-Host 'Pfad zum lokalen Mitschnitt'
./examples/Measure-UHDReadCapture.ps1 -HarPath $har -Scenario Page -MaxReports 1 |
    ConvertTo-Json -Depth 8
```

Wähle `-Scenario` passend zum bereits beobachteten GET:

| Offener Leseweg | Benötigte Beobachtung | Szenario |
|---|---|---|
| Folgeseiten | Bereits aufgezeichneter Wechsel auf eine zweite Seite einer freigegebenen Testliste | `Page` |
| Detail aus der skriptlosen Suchliste | Bereits aufgezeichneter Aufruf eines freigegebenen Testtickets direkt aus der Liste | `ListDetail` |
| Nicht leere Unterticket- oder Anhangliste | Antwort für ein Testticket mit vorhandenen Einträgen | `Children`, `Attachments` |
| Such- und Detailvarianten | Antwort einer freigegebenen Testsuche bzw. Detailansicht, insbesondere bei noch nicht erkannten Feldern | `Search`, `Detail` |
| Weitere Leseformate für Aktivitäten oder Übergänge | Bereits aufgezeichnetes leeres oder abweichendes Antwortformat | `Activities`, `Transitions` |
| Hilfsabfragen | Bereits beobachtete GET-Anfrage einschließlich Antwort; keine zusätzlichen Browseraktionen auslösen | `RequiredFields`, `Contact`, `ServiceContract`, `PriorityCalculation`, `AgentGroups`, `GroupAgents` |

Es werden höchstens fünf passende Berichte ausgegeben, wenn du
`-MaxReports` nicht angibst. Der Bericht enthält nur bekannte Operationen,
erlaubte Parameternamen ohne Werte, den HTTP-Status sowie Antwortmerkmale.
`TextBodyAvailable = False` bedeutet, dass kein Klartext-Antwortkörper zur
Auswertung vorlag. Keine Ausgabe bedeutet, dass im Mitschnitt kein passender
Request erkannt wurde. Der Endpunktstand steht in der
[Endpunktmatrix](../docs/endpoints.md).
