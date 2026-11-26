# Ticketaktivitäten lesen

`Get-UHDTicketActivity -Id <interne Ticket-ID>` liest die Aktivitäten des angegebenen Tickets. Die beobachtete Anfrage ist ein GET mit `OP=SEARCH`, `FACTORY=alg` und `QBE.EQ.call_req_id=cr:<ID>` sowie den zwei Sitzungsfeldern. Die sichtbare Ticketnummer ist keine interne ID.

Die Browserliste enthält literale Datensatz-Zuweisungen. Ausgegeben werden `Id` (numerische Aktivitäts-ID), `TicketId` (pro Zeile über die Persistenzkennung bestätigt), `RefNum` (sichtbare Ticketnummer), `Analyst` und `AnalystId`, `Timestamp` (UTC), `Type` und `TypeCode` sowie `Description`. Für die Beschreibung wird wie in der Browserliste der letzte von zwei beobachteten Zuweisungswerten verwendet; Anzeige-Markup bleibt Text und wird nicht ausgeführt. Das Modul öffnet keine Links und gibt keine Sitzungsfelder oder Navigations-URLs aus.

Unterstützt sind positive Listen im beobachteten Format; sichere Leer- und Paging-Befunde fehlen. Falsche Ticketzuordnungen, doppelte Aktivitäts-IDs und unvollständige oder unbekannte Datenformate werden ohne Teilausgabe abgelehnt. Es werden keine Aktivitäten geschrieben.
