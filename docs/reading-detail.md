# Bestätigte Detailfelder aus `SHOW_DETAIL`

Bei `SHOW_DETAIL` für `FACTORY=cr` wurde lokal das klassische Browserformular mit statischen Formularfeldern und JavaScript-Daten beobachtet. Der Parser führt kein JavaScript aus und akzeptiert nur die belegten Namen und Literalformen. Unbekannte Layouts sind kein Erfolg.

- `argPersistentID` hat die Form `cr:<interne ID>`; `argRefNum` enthält die sichtbare Request-Nummer. Das Modul gibt beide als `Id` und `RefNum` aus. Weicht die bestätigte Antwort-ID von `RequestedId` ab, wird die Antwort verworfen. Bei der älteren einfachen Formularform bleibt die Antwort-ID nicht belegt.
- Strukturierte Formularwerte stammen aus `SET.summary`, `SET.description`, `SET.assignee`, `SET.group`, `SET.customer`, `SET.priority`, `SET.urgency`, `SET.impact`, `SET.change` und `SET.affected_resource`. IDs und Anzeigenamen aus den jeweils belegten `*_combo_name`-Feldern bleiben getrennt.
- Der ausgewählte Status im Browserlayout ist ein Literal `crs:<Kennung>` in der belegten Status-Dropdown-Signatur. Eine menschenlesbare Statusbezeichnung ist hier nicht garantiert.
- Die beobachteten Datumsfelder `open_date`, `last_mod_dt`, `resolve_date` und `close_date` nutzen Unix-Sekunden. Das Modul gibt belegte Zeitwerte als UTC-`DateTimeOffset` aus; leere Werte bleiben leer.
- Eine zuverlässige Zuordnung für Kategorie, Elternticket und weitere Detailfelder ist noch offen. Der Nachweis bezieht sich auf das lokal vorhandene Antwortformat, nicht auf alle Formvarianten.
