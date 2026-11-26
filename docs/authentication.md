# Authentifizierung und Sitzung

Die dokumentierte Anmeldung ist formularbasiert (`USERNAME` und `PIN` als POST). Die Aufzeichnungen zeigen keine Cookies und keine SSO-, Kerberos- oder NTLM-Anmeldung. Die Sitzung wird über `SID` in URL und Formular geführt.

## Ablauf im Modul

1. `Connect-UHD` sendet den Login-POST an den dokumentierten Startpfad `pdmweb3.exe`.
2. Das Modul liest die `REPLACE_LOGIN`-Zieladresse aus der HTML-Antwort, ohne JavaScript auszuführen. Das Ziel muss dieselbe HTTPS-Basis verwenden und auf einen der dokumentierten Servlet-Namen unter dieser Basis zeigen.
3. Das Modul übernimmt `SID` und `FID` getrennt aus dem folgenden Formular und verwendet sie für `OP=MENU`. Nach dem Menüaufruf gibt `Connect-UHD` nur `IsConnected` und `ConnectedAt` aus.

Nach dem Login verwendet das Modul den übernommenen Servlet-Namen für Sitzungsrequests. Beim Klick auf eine Ticketliste im linken Menü erzeugt der Browser für die Anfrage eine FID: Der Menühandler ruft den Generator auf, der einen Zufallswert zwischen 0 und 10000 rundet. Die SID bleibt dabei gleich. Das Modul bildet dieses Verhalten für `Find-UHDTicket` nach, ohne die im Menüformular übernommene FID zu ändern. Für andere Operationen bleibt die FID-Herkunft offen. Antwortet ein Request in einer aktiven Sitzung mit dem erkannten Login-Formular, verwirft das Modul den aktiven Status und verlangt eine erneute Anmeldung. Das Verhalten bei tatsächlich abgelaufener Sitzung ist nicht live geprüft.

## Abmelden

- `Disconnect-UHD`: dokumentiertes Sitzungsende über das übernommene Servlet, `FID=0` und `ENDSESSION=1`.
- `Disconnect-UHD -MenuLogout`: dokumentierter Menü-Logout über `pdmweb.exe` und `OP=LOGOUT`.

Das Modul verwirft die lokale Sitzung auch bei einem Abmeldefehler. Ohne aktive Sitzung wird kein Request gesendet. Beide Wege sind offline geprüft.

## Zugangsdaten

- Ohne explizites `-Credential` lädt `Connect-UHD` gespeicherte Zugangsdaten oder fragt sie über `Get-Credential` ab und speichert sie mit `Export-Clixml` in `CredentialPath`.
- Unter Windows schützt DPAPI die Datei für denselben Benutzer auf demselben Rechner. Außerhalb von Windows warnt das Modul vor unzureichendem Schutz; dort empfiehlt sich die explizite Übergabe als `PSCredential`.
- `Connect-UHD -ResetCredential` erzwingt beim Aufbau einer Sitzung eine neue Abfrage, sofern kein explizites `-Credential` vorliegt.
- Das Modul speichert ein explizit übergebenes `-Credential` nicht. Das Login-Formular wird nach dem Request geleert; dies garantiert kein unmittelbares Löschen des Kennwortstrings aus dem Speicher.
