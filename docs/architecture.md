# Architektur

## Schichten
```
Public/*.ps1          Cmdlets (Connect-UHD, Get-UHDTicket, …)
    │
Private/Invoke-UHDRequest.ps1   zentrale HTTP-Kommunikation
    │                             - Timeouts, Wiederholung nur für GET
    │                             - Erkennung abgelaufener Sitzung
    │
$script:UHDSession              Sitzungszustand (SID, FID, BaseUrl, Status)
```

## Regeln
- Alle HTTP-Aufrufe laufen über `Invoke-UHDRequest`. Keine direkten `Invoke-WebRequest`-Aufrufe in Cmdlets.
- Schreibende Requests werden nie automatisch wiederholt.
- Logs über `ConvertTo-UHDMaskedUrl`.
- Verifikation: Nach jedem Schreibvorgang einen lesenden Request ausführen. Ein HTTP 200 allein gilt nicht als Erfolg.

## Geplante Umsetzung von Schreibvorgängen
1. Formular laden (`CREATE_NEW` bzw. `UPDATE` zum Öffnen).
2. Pflichtfelder und Übergänge prüfen (`GET_REQUIRED_FIELDS`, `VALID_TRANSITIONS`).
3. Alle Felder aus der Detailansicht übernehmen, nur gewünschte überschreiben (das Speichern schickt das komplette Formular).
4. Speichern (`UPDATE` mit `JEDIT=1`).
5. Lesen (`SHOW_DETAIL`) und mit dem Soll-Zustand vergleichen.

## Ungeklärt
- Sperrverhalten bei gleichzeitiger Bearbeitung.
- Ob Dubletten bei Timeouts entstehen. Vor jedem Neuanlegen nach dem Ticket suchen, wenn das Ergebnis unklar ist.
