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
- Nur über `[pscredential]` übergeben. Kennwort wird nur für den Login-POST ausgelesen und danach aus dem Formular-Hashtable gelöscht.
- Keine Speicherung im Repo oder im Modul.
