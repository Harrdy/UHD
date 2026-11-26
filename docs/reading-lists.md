# Unterticket- und Anhanglisten: bestätigte Leseformen

Das Modul ruft nur den jeweiligen Listenendpunkt per GET auf. Es führt weder
JavaScript aus noch folgt es Links oder lädt Anhänge herunter.

| Liste | Begleitparameter neben Sitzung, `OP=SEARCH` und `FACTORY` | Bestätigtes Ausgabeformat |
|---|---|---|
| Untertickets | `QBE.EQ.parent.id=<Ticket-ID>`, `KEEP.forInChildList=1` | Leere Trefferliste im Template `list_in.htmpl` |
| Anhänge | `HTMPL=list_attmnt_sd.htmpl`, `KEEP.ticketFac=cr`, `QBE.EQ.requests.cr.persistent_id=cr:<Ticket-ID>` | Leere Trefferliste im Template `list_attmnt_sd.htmpl` |

Die Unterticketform wurde in drei Antworten, die Anhangform in vier Antworten
beobachtet. Die Modulabfragen verwenden die gewöhnliche Leseliste. Eine
Anhangantwort wurde zusätzlich mit `KEEP.forSavedAttmnts=1` beobachtet; das
Modul setzt diesen Zusatz für den gewöhnlichen Abruf nicht.

Die erkannten leeren Seiten deklarieren den passenden `propFactory`- und
`propFormName`-Wert, beide Zähler (`cfgTotal`, `cfgRecordCount`) mit null
und Listenaufbau ohne Datensätze. `Get-UHDTicket -Children` und
`Get-UHDTicketAttachment` geben dann keine Objekte aus. Fehlt dieser
eindeutige Nachweis, meldet das Modul einen Formatfehler statt einer leeren
Liste. Die beobachteten Anhangskripte enthalten Anzeige- und Verknüpfungscode,
aber keinen ausgefüllten Metadatensatz.

## Fehlende Belege

Für die Auswertung nicht leerer Ergebnisse werden je ein freigegebenes
Testticket mit Unterticket und mit bereits vorhandenem Anhang benötigt.
Bei den Testtickets nur die jeweilige Liste öffnen; keinen Anhang hinzufügen,
ändern oder herunterladen. Benötigt werden die Struktur der Antwortfelder,
ihre Datentypen und die Grenzen eines Datensatzes, nicht die konkreten Namen,
Dateipfade oder Inhalte. Rohaufzeichnungen, URLs mit Sitzungswerten und
Ticketdaten nicht teilen oder versionieren.
