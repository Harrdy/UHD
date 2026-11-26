# Hinweise für KI-Agenten in diesem Repo

## Verbindliche Regeln
- Keine Änderungen am produktiven Ticketsystem. Live-Tests nur nach ausdrücklicher Freigabe und nur mit dafür vorgesehenen Testtickets.
- Keine Endpunkte, Parameter oder Rückgabewerte erfinden. Nur bestätigte Befunde aus `docs/endpoints.md` verwenden. Unbekanntes als „offen“ markieren.
- Keine Zugangsdaten, Session-IDs, Tokens oder HAR-Inhalte in Code, Doku, Tests oder Commits.
- Schreibende Requests nie automatisch wiederholen.
- TLS-Prüfung nie deaktivieren.
- Sitzungs-IDs und Kennwörter nie loggen. Logs über `ConvertTo-UHDMaskedUrl` führen.
- Nach jeder erfolgreichen Coding-Session die eigenen Änderungen committen und auf `origin/develop` pushen, sofern Tests und PSScriptAnalyzer bestanden sind. Bei fehlgeschlagenen oder nicht ausgeführten Prüfungen weder committen noch pushen.
- Commit-Nachrichten auf Englisch. Branch `develop`, kein Merge nach `main`, kein Force-Push.

## Stil
- PowerShell 7, Advanced Functions mit `[CmdletBinding()]`, Verb-Noun-Namen.
- Strukturierte Rückgaben (`[pscustomobject]`), keine reinen Textausgaben.
- Fehlertexte und Kommentare auf Deutsch, Code-Bezeichner auf Englisch oder wie im Ticketsystem.

## Aktueller Stand
Siehe `README.md` und `docs/analysis.md` (Abschnitt Offene Punkte).
