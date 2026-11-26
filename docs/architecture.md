# Architektur

## Schichten

| Schicht | Verantwortung |
|---|---|
| `Public/` | Cmdlets validieren Eingaben und geben strukturierte Fach- oder Sitzungsobjekte zurück. |
| `$script:UHDSession` | Privater Sitzungszustand für Basis-URL, Servlet, Timeout, SID und FID. |
| `ConvertTo-UHDOperationUrl` | Baut die CA-Abfrage, kodiert Werte und ergänzt die Sitzungsfelder. |
| `Invoke-UHDRequest` | Validiert den Endpunkt, steuert Timeouts und Wiederholungen und erkennt bekannte Hinweise auf eine ungültige Sitzung. |
| `Invoke-UHDWebRequest` | Kapselt das Webcmdlet. Der isolierte Runspace hält rohe HTTP-Fehler und Requestobjekte von der Fehlerhistorie des Aufrufers fern. |
| `ConvertFrom-UHDTicketResponse` | Liest ausgewählte Felder aus unterstützten Ticket-Layouts. Führt keine Skripte aus. |

## Grenzen des Lesepfads

Die Suche übernimmt nur JSON-kompatible `recordData`-Zuweisungen im unterstützten Layout. Fehlt ein auswertbarer Treffer, kann das Modul nicht zwischen einer leeren Liste und einem unbekannten Format unterscheiden; es meldet einen Fehler. Der Detailparser unterstützt ausgewählte benannte Formularfelder. `RequestedId` stammt aus dem Aufruf und bestätigt nicht unabhängig die Identität des Antwortdatensatzes. Beide Auswertungen sind mit synthetischen Antworten geprüft.

## Transport

- Cmdlets benutzen ausschließlich den zentralen Transport. Die TLS-Zertifikatsprüfung bleibt aktiv.
- Der Transport deaktiviert automatische HTTP-Weiterleitungen und HTTP-Retries. Explizit lesende Operationen können eine Wiederholung im Request-Helfer anfordern; standardmäßig wird nicht wiederholt. Schreibende, potenziell sperrende und sitzungsverändernde Operationen werden nicht automatisch wiederholt.
- `ConvertTo-UHDMaskedUrl` entfernt Query, Fragment und Benutzerinformationen aus Request-Logs. Öffentliche Sitzungsobjekte enthalten weder SID noch FID.

## Schreibgrenze für Phase 2

`New-UHDTicket` und `Set-UHDTicket` senden aktuell keine Requests. Der Anlegeformularabruf ist intern implementiert; für das potenziell sperrende Bearbeitungsöffnen ist nur der belegte Query-Anteil vorbereitet. Es fehlen insbesondere der vollständige Speichervertrag und die eindeutige Identifikation des Datensatzes in der nachfolgenden Detailantwort.

Vor einer späteren Schreibfreigabe: vollständiges Formular und Pflichtfelder bestätigen, den Datensatz eindeutig identifizieren, maximal einen Save senden und den gewünschten Zustand über `SHOW_DETAIL` verifizieren. Ein HTTP 200 allein gilt nicht als Erfolg. Bei unklarem Schreibergebnis nicht automatisch erneut speichern.
