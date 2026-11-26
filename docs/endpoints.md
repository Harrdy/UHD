# Endpunkte

Basis: `https://<host>/CAisd/`. Die bestätigten Requests nutzen GET, außer Login und Menü (POST). Der abgeleitete Multipart-Upload ist nicht implementiert.

Hinweis: Der Servlet-Name variiert zwischen Aufzeichnungen (`pdmweb.exe`, `pdmweb2.exe`, `pdmweb3.exe`). Das Modul startet die Anmeldung über `pdmweb3.exe` und übernimmt danach den validierten Servlet-Namen aus der Sitzungsweiterleitung. Der Menü-Logout verwendet den dokumentierten abweichenden Pfad `pdmweb.exe`. Die Tabelle zeigt die Pfade der Aufzeichnungen, nicht einen festen Servlet-Namen für alle Operationen.
Trennzeichen zwischen Parametern in Query-Strings ist meist `+` (CA-Format). Formularfelder werden mit `&` gesendet.

Die Spalte **Protokollbefund** beschreibt die Aufzeichnungen. **Phase 2** beschreibt nur den Modulstand. Die angegebenen Tests prüfen den Request-Aufbau und, wo vorhanden, die Auswertung synthetischer Antworten. Keiner davon prüft die Live-Kompatibilität. Die verlinkten Tests sind Pester-Suites.

| Zweck | Methode | Pfad und Parameter | Protokollbefund | Phase 2 / Offline-Beleg |
|---|---|---|---|---|
| Login | POST | `pdmweb3.exe`: `PortalSession`, `USERNAME`, `PIN`, `PDA=No`, `OP=LOGIN`, `INITIAL_LOAD` | bestätigt | Öffentlich: `Connect-UHD`, [Sitzungstest][session]. |
| Sitzungsweiterleitung | GET | `pdmweb3.exe?SID=…+FID=…+OP=REPLACE_LOGIN+HTMPL=post_menu.htmpl` | bestätigt | Öffentlich über `Connect-UHD`: Ziel wird validiert; [Sitzungstest][session]. |
| Menü öffnen | POST | `pdmweb3.exe`: `SID`, `FID`, `OP=MENU`, `POST_MENU=1` | bestätigt | Öffentlich über `Connect-UHD`, [Sitzungstest][session]. |
| Sitzung beenden (Fenster schließen) | GET | `pdmweb3.exe?SID=…+FID=0+ENDSESSION=1` | bestätigt | Öffentlich: `Disconnect-UHD`, [Sitzungstest][session]. |
| Abmelden über Menü | GET | `pdmweb.exe?SID=…+FID=…+OP=LOGOUT` | bestätigt, Servlet abweichend | Öffentlich: `Disconnect-UHD -MenuLogout`, [Sitzungstest][session]. |
| Ticketsuche | GET | `pdmweb3.exe?…+OP=SEARCH+FACTORY=cr+KEEP.where_clause=…` | bestätigt; zwei Filtervarianten, siehe unten | Öffentlich: `Find-UHDTicket -GroupMemberId` oder `-AllActiveIncidents`. Liest die erste Seite im beobachteten JavaScript- oder HTML-Listenformat. Keine implementierte Pagination und kein belegtes Leerlistenformat. [Lesetest][read]. |
| Ticket öffnen | GET | `pdmweb3.exe?…+OP=SHOW_DETAIL+FACTORY=cr+PERSID=cr:<id>` | bestätigt | Öffentlich: `Get-UHDTicket -Id`; unterstützt ausgewählte benannte Felder aus dem synthetisch geprüften Formularlayout. [Lesetest][read]. |
| Anhang-Liste | GET | `pdmweb3.exe?…+OP=SEARCH+FACTORY=attmnt+QBE.EQ.requests.cr.persistent_id=cr:<id>` | bestätigt | Öffentlich: `Get-UHDTicketAttachment -Id` sendet den Request. Antwortformat offen; keine Liste und kein Download. [Lesetest][read]. |
| Untertickets | GET | `pdmweb3.exe?…+OP=SEARCH+FACTORY=in+QBE.EQ.parent.id=<id>` | bestätigt | Öffentlich: `Get-UHDTicket -Id -Children` sendet den Request. Antwortformat offen; keine Liste. [Lesetest][read]. |
| Neues Ticket (Formular) | GET | `pdmweb3.exe?…+OP=CREATE_NEW+FACTORY=cr+PRESET=type:I` | bestätigt | Interner Request über `Invoke-UHDAuxiliaryRequest`; kein öffentlicher Formularparser. [Hilfstest][aux]. |
| Speichern (neu und ändern) | GET | `pdmweb3.exe?JEDIT=1&…&OP=UPDATE&FACTORY=cr&SET.*&KEY.*` | bestätigt, Antwort auswertbar | Gesperrt: vollständiges Formular und Verifikation nicht belegt. `New-UHDTicket` und `Set-UHDTicket` senden keine Requests. [Null-Request-Test][aux]. |
| Ticket öffnen für Bearbeitung | GET | `pdmweb3.exe?…+OP=UPDATE+FACTORY=cr+SET.id=<id>` | bestätigt | Nur Query-Vorlage in `Get-UHDAuxiliaryQuery`; kein Request. Mandantenparameter und mögliches Sperrverhalten sind offen. [Hilfstest][aux]. |
| Erlaubte Statuswechsel | GET | `pdmweb3.exe?…+OP=VALID_TRANSITIONS+STATUS=<status>+PERSID=cr:<id>+TYPE=I` | bestätigt, Codes offen | Öffentlich: `Get-UHDStatus -Id -Status` liefert `Code` und `Label` für genau einen URL-kodierten Eintrag. Listenrahmen und Leerformat sind offen. [Hilfstest][aux]. |
| Pflichtfelder prüfen | GET | `pdmweb3.exe?…+OP=GET_REQUIRED_FIELDS+FACTORY=cr+status=<status>` | bestätigt | Interner Request über `Invoke-UHDAuxiliaryRequest`; kein bestätigtes Antwortlayout. [Hilfstest][aux]. |
| Kontakt laden | GET | `pdmweb3.exe?…+OP=SPEC_HAND+FACTORY=cnt+PERSID=cnt:<id>` | bestätigt | Interner Request nach Kontakt-ID über `Invoke-UHDAuxiliaryRequest`; keine Benutzersuche oder öffentliche Rohantwort. [Hilfstest][aux]. |
| Servicevertrag laden | GET | `pdmweb3.exe?…+OP=GET_SVC_CONTRACT+new_customer=cnt:<id>` | bestätigt | Interner Request nach Kontakt-ID über `Invoke-UHDAuxiliaryRequest`; keine öffentliche Antwortauswertung. [Hilfstest][aux]. |
| Prioritätsberechnung | GET | `pdmweb3.exe?…+OP=GET_PRI_CAL+FACTORY=in` | bestätigt | Interner Request über `Invoke-UHDAuxiliaryRequest`; keine Prioritätsliste. [Hilfstest][aux]. |
| Gruppenzuordnung | GET | `pdmweb3.exe?…+OP=GROUP_IN_AGT` / `AGT_IN_GROUP` | bestätigt; `group_id` ist die 32-stellige Hex-Kennung der Gruppe | Interne Vorlagen für beide `OP`-Werte; keine Requests, da der vollständige Vertrag offen ist. [Hilfstest][aux]. |
| Anhang hochladen | POST multipart | `/CAisd/UploadServlet`, Formular `frmUpload`, Popup | aus JavaScript abgeleitet, Popup-URL nicht einzeln aufrufbar, zurückgestellt | Offen: kein vollständiger Multipart-Request; kein Upload. |
| Kommentar | offen | offen | offen | Offen: kein belegter Request zum manuellen Anlegen. |
| Abschluss | offen | offen | offen | Offen: kein belegter Abschluss mit Lösung. |
| WSDL | GET | `pdmws.exe?WSDL` | **404**, nicht verfügbar | Nicht unterstützt; kein Request im Modul. |

## Bestätigte Filtervarianten für die Ticketsuche

Neben der Browserliste wurde für denselben Suchendpunkt eine skriptlose HTML-Antwort mit der Tabelle „Request-Liste“ beobachtet. Sie liefert sichtbare Request-Nummer, Endanwender, Status, Priorität und Zusammenfassung, aber keine interne Ticket- oder Gruppen-ID. Zeilenlinks enthalten einen positionsbezogenen Index; er ist keine Ticket-ID. Die Seite enthält Links mit `OP=PG` für Folgeseiten; Ausführung und Antwortverhalten dieser Links sind noch offen.

Beim aufgezeichneten Klick auf „Alle Tickets“ ist die Suche der erste und einzige Servlet-Request im Mitschnitt; danach folgen statische Ressourcen. Der Menühandler erzeugt für den Suchrequest eine eigene FID (siehe [Authentifizierung](authentication.md)); sie ist kein fester Code für die jeweilige Ansicht.

- **Aktive Incidents ohne Gruppenfilter:** `active=1 AND type = 'I' AND template_name is NULL`. Der Filter schließt Vorlagen aus und ist keine Suche nach allen Ticketarten oder inaktiven Tickets.
- **Gruppenmitgliedschaft:** `(status <> 'EXTERL' AND status <> 'EXTABG') and active=1 AND type = 'I' AND group.[group]group_list.member IN (U'<Kennung>')`. Belegt ist genau eine 32-stellige Hex-Mitgliedskennung ohne Bindestriche; das Modul ergänzt das `U'…'`-Literal selbst. Mehrere Kennungen und Dezimal-IDs sind nicht belegt.

Die Mitgliedskennung steht im Filter `group_list.member` einer bestehenden Browser-Anfrage zur eigenen Ticketliste. Sie ist **nicht** `group_id`; die Gruppenkennung erscheint in der Zuordnungsabfrage und im Bearbeitungsformular unter `SET.group`. Ein Suchfilter für genau eine Gruppenkennung ist nicht belegt. Die Mitgliedersuche kann Treffer aus mehreren Gruppen liefern.

Die beobachtete Trefferliste beginnt jeden Treffer mit `recordData = new Object()`, enthält feldweise Zuweisungen und schließt ihn mit `rs.addRow(…)` ab. Die interne Ticket-ID ist im Feld `persid` als `cr:<ID>` belegt und wird als `Id` ausgegeben. Eine vorhandene Gruppenkennung aus `group.id` wird als `GroupId` ausgegeben, kann aber nicht als Suchfilter verwendet werden. Das Modul liest die Daten, ohne das Skript auszuführen. Eine aufgezeichnete Seite enthielt 50 Treffer; Folgeanfragen und Positivmerkmale für eine leere Antwort bleiben offen.

Die Browserliste enthält außerdem `group` (Arbeitsgruppe), `assignee` (Bearbeiter) und `last_mod_dt` (letzte Änderung). Der Browser formatiert den letzten Wert aus Unix-Sekunden; das Modul gibt ihn als `LastModified` in UTC aus. In der skriptlosen Request-Liste fehlen alle drei Spalten.

## Hinweis zu Speicher-Requests
Beim Speichern werden alle Formularfelder gesendet. Die URL ist 1,5 KB lang. Beschreibung und Personendaten stehen in der URL. Logs müssen maskieren.
[session]: ../tests/Session.Tests.ps1
[read]: ../tests/TicketRead.Tests.ps1
[aux]: ../tests/TicketAuxiliary.Tests.ps1

In der Analyse erwähnte Aktivitäten (`SEARCH FACTORY=alg`) sind kein vollständig belegter Request-Vertrag. Allgemeine Benutzer- und Gruppensuche sowie Kategorie-, Status- und Prioritätskataloge sind nicht umgesetzt.
