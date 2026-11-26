# Analyse der HAR-Aufzeichnungen

Stand: 2026-11-26. Die ursprüngliche Auswertung umfasst 10 Aufzeichnungen (Login, Menü, Suche, Detail, Anlegen, Speichern, Statuswechsel, Anhang, Logout, WSDL-Test). Für 0.3.0 wurden die Suchbefunde anhand von drei aufgezeichneten Trefferseiten ergänzt.

## Bestätigt

### Anmeldung
- Formularbasiert. Keine Cookies, kein 401, kein NTLM/Kerberos-Challenge.
- Session läuft vollständig über den URL-Parameter `SID` und das Formularfeld `SID`.
- Ablauf: POST Login → JS-Weiterleitung mit SID/FID (`OP=REPLACE_LOGIN`) → GET → Auto-POST `OP=MENU`.

### Session-Ende
- Beim Schließen des Fensters: `GET pdmweb3.exe?SID=…+FID=0+ENDSESSION=1` (Antwort 200, 3 Byte).
- Logout über Menü: `GET pdmweb.exe?SID=…+FID=…+OP=LOGOUT`. Der Pfad weicht von den übrigen Requests ab.

### Ticketsuche
- `OP=SEARCH&FACTORY=cr` mit `KEEP.where_clause` (SQL-artige Bedingung).
- Zwei Filter sind belegt: aktive Incidents ohne Gruppenfilter und ohne Vorlagen sowie aktive Incidents über eine Gruppenmitgliedschaft mit Ausschluss von `EXTERL` und `EXTABG`. Die [Endpunktmatrix](endpoints.md#bestätigte-filtervarianten-für-die-ticketsuche) nennt die genaue Syntax.
- Der Mitgliedschaftsfilter verwendet genau eine 32-stellige Hex-Kennung ohne Bindestriche. Diese ist nicht die Gruppenkennung; die Gruppe steht in der Trefferliste gesondert in `group.id`.
- Die Antwort ist HTML mit eingebettetem JavaScript. Feldweise Zuweisungen an `recordData` und ein abschließender Zeilenaufruf bilden jeden Treffer. Der Parser wertet die Daten aus, ohne JavaScript auszuführen. Die interne Ticket-ID stammt aus `persid` und ist nicht die sichtbare Ticketnummer.
- Die Offline-Auswertung erkannte auf drei aufgezeichneten Seiten 50, 30 und 31 Treffer. Sie bestätigt weder eine feste Seitengröße noch das Format einer leeren Liste. Parameter für Folgeseiten und ein Filter nach genau einer Gruppe bleiben offen.

### Ticketdetails
- `OP=SHOW_DETAIL&FACTORY=cr&PERSID=cr:<id>`.
- Felder: `ref_num`, `status` (`crs:<id>`), `summary`, `description`, `assignee`, `group`, `category`, `priority`, `urgency`, `impact`, `customer`, `parent`, Zeitstempel.
- Zusätzlich Anhang-Tab (`xx_attmnt_tab.htmpl`) und Untertickets (`SEARCH FACTORY=in&QBE.EQ.parent.id`).

### Anlegen
- `OP=CREATE_NEW&FACTORY=cr&PRESET=type:I`: Formular.
- Speichern: `OP=UPDATE&FACTORY=cr&JEDIT=1&SET.*&KEY.*`, als **GET** mit allen Feldern in der URL. Antwort enthält die neue ID (`cr:<id>`).
- Gespeicherter Status bei Neuanlage: `OP` (`crs:5200`). Beim Anlegen werden Werte wie `SET.zTyp=Incident`, `SET.status=OP` übergeben.
- Verifikation: `SHOW_DETAIL` nach dem Speichern zeigt Status und Zusammenfassung korrekt.

### Ändern
- Zweite Änderung (Aufzeichnung 40d31bdb): `SET.description` um `\n\nÄnderung 2` erweitert, `SET.urgency` und `SET.man_urg` von `1`/`-1` auf `2`, `SET.status` von `OP` auf `WIP`. Die Antwort enthält `Änderung 2`. Die Feldliste ist identisch zur ersten Änderung.
- Kein Read-back per `SHOW_DETAIL` nach dem Speichern.
- Servlet-Name in dieser Aufzeichnung: `pdmweb2.exe` (10 Requests), vorherige: `pdmweb3.exe`.
- Öffnen: `OP=UPDATE&SET.id=<id>&SET.tenant=…` (ohne Änderung).
- Speichern: `JEDIT=1&OP=UPDATE&SET.*` mit **dem kompletten Formular**. Unveränderte Felder werden mitgesendet.
- Getestet: Beschreibung um `\n\nÄnderung 1` erweitert. Antwort enthält den neuen Text.

### Statuswechsel
- Ein Statuswechsel ist ein Speichern mit geändertem `SET.status`. Eigener Übergangs-Request existiert nicht.
- Vorab: `VALID_TRANSITIONS` mit `STATUS=<aktueller Status>`. Danach `GET_REQUIRED_FIELDS` für alten und neuen Status.
- Getestet: `OP` → `WIP` (`crs:5208`).

### Hilfs-Requests
- `GET_REQUIRED_FIELDS`, `VALID_TRANSITIONS`, `SPEC_HAND` (Kontakt, Factory `cnt`), `GET_SVC_CONTRACT`, `GET_PRI_CAL`, `AGT_IN_GROUP`, `GROUP_IN_AGT`, `SEARCH FACTORY=alg`.

### Anhänge
- Die Anhang-ID erscheint nach dem Upload (Beispiel `6212972`).
- Upload-Endpunkt laut Client-Skript: `POST /CAisd/UploadServlet`, `multipart/form-data`, Ergebnis im iframe `IFUpload`.

### Fehlerfälle
- Keine HTTP-Fehler (4xx/5xx) in den Ticket-Aufzeichnungen. Fehler kommen als HTML.
- `AHD…`-Codes im Quelltext sind Meldungskatalog-Einträge des Clients, keine Serverantworten.
- Echte Serverantwort: `AHD04406: Status: 204 Keine Antwort` bei `GET_REQUIRED_FIELDS` für ein noch nicht gespeichertes Ticket (Vermutung).

### Nicht vorhanden
- `pdmws.exe?WSDL` liefert **404**. Kein SOAP-Endpunkt unter diesem Pfad.
- Keine REST- oder JSON-Schnittstelle erkennbar.

## Aktivitäten (Reiter "Aktivitäten", Factory `alg`)

- Die Aktivitätsliste ist ein **automatisches Änderungsprotokoll**. Jeder Speicher-Vorgang erzeugt Einträge.
- Die Beschreibung eines Eintrags nennt die Änderung, z. B. `Status wurde von 'In Bearbeitung' in 'Gelöst' geändert`, `Übertragen von Zuständiger von 'X' auf 'Y'` oder `FELD='Beschreibung' OLD=…`.
- Beobachtete Typen (`listtypecode`): `FLD` Feldaktualisierung (15), `INIT` Anfang (9), `ST` Status aktualisieren (5), `ATTACHTDOC` Dokument anhängen (6), `TR` Transfer (4), `ADJURGIMP` Auswirkungsdringlichkeit anpassen (4), `RE` Abgeschlossen (1).
- Ein manuell angelegter Eintrag ist in keiner Aufzeichnung enthalten.
- Der Statuscode `PF` entspricht vermutlich `Gelöst` (Zusammenhang: Speichern mit `SET.status=PF`, Aktivität „… in ‚Gelöst‘ geändert“). Vermutung, nicht bestätigt.

## Statuscodes

| Code | Bezeichnung | Status |
|---|---|---|
| `OP` | Offen | bestätigt (`crs:5200`) |
| `WIP` | In Bearbeitung | bestätigt (`crs:5208`) |
| `FWD` | Weitergeleitet | bestätigt (Dropdown-Label) |
| `CB` | Rückfrage | bestätigt (Dropdown `crs:4454780`, Speichern mit `SET.status=CB`) |
| `CL` | Geschlossen | bestätigt (`VALID_TRANSITIONS` ab `PF`: `CL@Geschlossen`) |
| `PF` | Gelöst | Vermutung (Aktivität „Status … in ‚Gelöst‘ geändert“ nach `SET.status=PF`) |
| `EXTERL` | extern erledigt | Vermutung über Ausschluss, Zuordnung zu `EXTABG` unsicher |
| `EXTABG` | extern abgegeben | Vermutung über Ausschluss, Zuordnung zu `EXTERL` unsicher |

Übergänge laut Aufzeichnungen:
- Ab `WIP`: `EXTERL`, `EXTABG`, `CL`, `PF`, `FWD`, `CB`.
- Ab `PF` (Gelöst): `CL`, `WIP`.
- Ab `CB` (Rückfrage): `WIP`, `FWD`.
- Format der Antwort auf `VALID_TRANSITIONS` mit Labels: `CODE@Bezeichnung` (URL-kodiert), z. B. `WIP@In%20Bearbeitung`, `CL@Geschlossen`.

Die Statusliste aus dem Client (6 Folgestatus aus In Bearbeitung) passt zur Anzahl der Codes.

## Offen

| Punkt | Warum offen | Nächste Aufzeichnung |
|---|---|---|
| Bedeutung der Transitionscodes `CL`, `FWD`, `CB`, `PF`, `EXTERL`, `EXTABG` | nicht dokumentiert | Statuswechsel auf jeden Zielstatus |
| Manueller Aktivitäts-Eintrag ("Kommentar") | nicht aufgezeichnet, unklar ob die Oberfläche das vorsieht. Aktivitäten entstehen automatisch beim Speichern | Reiter "Aktivitäten" öffnen, Eintrag manuell anlegen (falls vorhanden) |
| Bearbeiterwechsel | nur Felder bekannt | Bearbeiter ändern + speichern |
| Abschluss mit Lösung | nicht aufgezeichnet | Ticket abschließen |
| Anhang-Upload als Multipart | Upload läuft über ein Popup, das im Entwicklerwerkzeug nicht erscheint; die Popup-URL lässt sich nicht einzeln öffnen. Für den PoC nicht erforderlich | zurückgestellt |
| Anhang abrufen (Download-URL) | nur Liste bekannt | Download eines Anhangs |
| Fehlerfall Pflichtfeld fehlt | nicht aufgezeichnet | Speichern mit leerem Pflichtfeld |
| Fehlerfall Berechtigung | nicht aufgezeichnet | Ticket einer fremden Gruppe öffnen |
| Verhalten bei abgelaufener Sitzung | nicht aufgezeichnet | Sitzung ablaufen lassen, dann Request |
| URL-Länge | Testwert 1562 Zeichen funktioniert, IIS-Standard 2048 | Speichern mit sehr langer Beschreibung |
| Sperre beim Bearbeiten | unklar, ob `SET.id`-Schritt sperrt | Parallel-Bearbeitung |
| FID-Herkunft | Wert wiederholt sich im Formular, Quelle unklar | Vergleich mehrerer Formulare |
| Servlet-Name `pdmweb`, `pdmweb2`, `pdmweb3` | drei Namen in den Aufzeichnungen beobachtet, Auslöser unklar | Vergleich gleicher Aktion in neuer Sitzung |
| Benutzer- und Gruppensuche | nur Hilfsabfragen | Suche nach Benutzer |
| Kategorie-, Status- und Prioritätslisten | nur Einzelwerte | Dropdown-Werte auslesen |

## Sicherheit
- Login-Aufzeichnung enthält das Kennwort im Klartext (Feld `PIN`). Nicht versionieren, nach Analyse löschen.
- Session-IDs stehen in URLs und können in Logs auftauchen.
