# Authentifizierung und Sitzung

## Verfahren
- Formularbasiert (`USERNAME` + `PIN` als POST).
- Keine SSO-, Kerberos- oder NTLM-Signale in den Aufzeichnungen (kein 401, kein `WWW-Authenticate`).
- Keine Cookies. Die Sitzung wird über `SID` in URL und Formular geführt.

## Ablauf
1. Login-POST → Antwort ist HTML mit JavaScript-Weiterleitung. Darin stehen `SID` und `FID`.
2. GET auf die Weiterleitung (`OP=REPLACE_LOGIN`). Antwort enthält ein Formular mit `SID` und `FID`.
3. POST `OP=MENU` mit diesen Werten. Ab hier ist die Sitzung aktiv.

## FID
- Die `FID` steht bei jedem Request. Der Client erzeugt sie mit `Math.round(Math.random() * 10000)` (`fid_gen.js`).
- Im Formular wiederholt sich eine FID über mehrere Requests. Die Herkunft dieser Werte ist offen.
- Für das Modul: FID bei jedem Request neu setzen oder den Wert des Formulars übernehmen. Beides ist nicht getestet.

## Sitzungsende
- Fenster schließen: `GET …?SID=…+FID=0+ENDSESSION=1`.
- Abmelden: `GET pdmweb.exe?…+OP=LOGOUT`.

## Abgelaufene Sitzung
- In den Aufzeichnungen nicht beobachtet. Das Modul erkennt Anmeldeseiten an `name="login"` in der Antwort und wirft dann einen Fehler.
- Bekannte Einschränkung: Ein fehlgeschlagener Login erzeugt dieselbe Meldung wie eine abgelaufene Sitzung. Ein Test mit falschem Kennwort ist offen.

## Zugangsdaten

- Beim ersten Aufruf oder wenn die Credential-Datei fehlt, öffnet sich das Login-Fenster (`Get-Credential`).
- Benutzername und Kennwort werden danach mit `Export-Clixml` in `CredentialPath` gespeichert.
- Unter Windows ist die Datei mit DPAPI verschlüsselt. Sie ist nur für denselben Benutzer auf demselben Rechner lesbar.
- Ein erneutes Login-Fenster erzwingt `Connect-UHD -ResetCredential`, z. B. nach Kennwortänderung.
- Mit `-Credential` übergebene Daten werden nicht gespeichert.
- Das Kennwort wird nur für den Login-POST in das Formular geschrieben. Ein Hashtable-`Clear()` entfernt nur den Eintrag. Der String selbst bleibt bis zur Garbage Collection im Speicher, das ist ein bekanntes Restrisiko von PowerShell.
- Unter Nicht-Windows-Systemen warnt das Modul, weil der Schutz dort nicht ausreicht.
