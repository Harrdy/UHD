# Endpunkte

Basis: `https://<host>/CAisd/`. Alle Requests sind GET, außer Login und Menü (POST).

Hinweis: Der Servlet-Name variiert zwischen Aufzeichnungen (`pdmweb.exe`, `pdmweb2.exe`, `pdmweb3.exe`). Das Modul sollte den Namen aus der Anmeldung übernehmen und nicht fest verdrahten.
Trennzeichen zwischen Parametern in Query-Strings ist meist `+` (CA-Format). Formularfelder werden mit `&` gesendet.

| Zweck | Methode | Pfad und Parameter | Status |
|---|---|---|---|
| Login | POST | `pdmweb3.exe`: `PortalSession`, `USERNAME`, `PIN`, `PDA=No`, `OP=LOGIN`, `INITIAL_LOAD` | bestätigt |
| Sitzungsweiterleitung | GET | `pdmweb3.exe?SID=…+FID=…+OP=REPLACE_LOGIN+HTMPL=post_menu.htmpl` | bestätigt |
| Menü öffnen | POST | `pdmweb3.exe`: `SID`, `FID`, `OP=MENU`, `POST_MENU=1` | bestätigt |
| Sitzung beenden (Fenster schließen) | GET | `pdmweb3.exe?SID=…+FID=0+ENDSESSION=1` | bestätigt |
| Abmelden über Menü | GET | `pdmweb.exe?SID=…+FID=…+OP=LOGOUT` | bestätigt, Servlet abweichend |
| Ticketsuche | GET | `pdmweb3.exe?…+OP=SEARCH+FACTORY=cr+KEEP.where_clause=…` | bestätigt |
| Ticket öffnen | GET | `pdmweb3.exe?…+OP=SHOW_DETAIL+FACTORY=cr+PERSID=cr:<id>` | bestätigt |
| Anhang-Liste | GET | `pdmweb3.exe?…+OP=SEARCH+FACTORY=attmnt+QBE.EQ.requests.cr.persistent_id=cr:<id>` | bestätigt |
| Untertickets | GET | `pdmweb3.exe?…+OP=SEARCH+FACTORY=in+QBE.EQ.parent.id=<id>` | bestätigt |
| Neues Ticket (Formular) | GET | `pdmweb3.exe?…+OP=CREATE_NEW+FACTORY=cr+PRESET=type:I` | bestätigt |
| Speichern (neu und ändern) | GET | `pdmweb3.exe?JEDIT=1&…&OP=UPDATE&FACTORY=cr&SET.*&KEY.*` | bestätigt, Antwort auswertbar |
| Ticket öffnen für Bearbeitung | GET | `pdmweb3.exe?…+OP=UPDATE+FACTORY=cr+SET.id=<id>` | bestätigt |
| Erlaubte Statuswechsel | GET | `pdmweb3.exe?…+OP=VALID_TRANSITIONS+STATUS=<status>+PERSID=cr:<id>+TYPE=I` | bestätigt, Codes offen |
| Pflichtfelder prüfen | GET | `pdmweb3.exe?…+OP=GET_REQUIRED_FIELDS+FACTORY=cr+status=<status>` | bestätigt |
| Kontakt laden | GET | `pdmweb3.exe?…+OP=SPEC_HAND+FACTORY=cnt+PERSID=cnt:<id>` | bestätigt |
| Servicevertrag laden | GET | `pdmweb3.exe?…+OP=GET_SVC_CONTRACT+new_customer=cnt:<id>` | bestätigt |
| Prioritätsberechnung | GET | `pdmweb3.exe?…+OP=GET_PRI_CAL+FACTORY=in` | bestätigt |
| Gruppenzuordnung | GET | `pdmweb3.exe?…+OP=GROUP_IN_AGT` / `AGT_IN_GROUP` | bestätigt |
| Anhang hochladen | POST multipart | `/CAisd/UploadServlet`, Formular `frmUpload`, Popup | aus JavaScript abgeleitet, Popup-URL nicht einzeln aufrufbar, zurückgestellt |
| Kommentar | offen | offen | offen |
| Abschluss | offen | offen | offen |
| WSDL | GET | `pdmws.exe?WSDL` | **404**, nicht verfügbar |

## Hinweis zu Speicher-Requests
Beim Speichern werden alle Formularfelder gesendet. Die URL ist 1,5 KB lang. Beschreibung und Personendaten stehen in der URL. Logs müssen maskieren.
