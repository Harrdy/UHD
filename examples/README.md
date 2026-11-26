# Beispiele

## Offline: Anmeldung, Suche, Detailabruf und Abmeldung

Aus dem Repository-Root ausführen. Der Pester-Test nutzt synthetische Antworten; keine UHD-Konfiguration und kein UHD-Zugang sind nötig.

```powershell
$config = New-PesterConfiguration
$config.Run.Path = './tests/TicketRead.Tests.ps1'
$config.Filter.FullName = '*verbindet, sucht, liest Details und meldet offline ab*'
$config.Run.Exit = $true
Invoke-Pester -Configuration $config
```

## Öffentliche API

Dieses Beispiel zeigt die Aufruffolge und die Parameter, nicht einen ausgeführten Live-Test. Nur mit ausdrücklicher Freigabe und vorgesehenen Testtickets verwenden. Die beispielhaften numerischen IDs durch die internen Kennungen des freigegebenen Tests ersetzen. Die Suchtreffer liefern nicht zwingend eine interne Ticket-ID.

```powershell
Import-Module ./src/UHDServiceDesk/UHDServiceDesk.psd1
$credential = Get-Credential -Message 'Anmeldung am Testsystem'
Connect-UHD -ConfigPath ./config.local.json -Credential $credential -ErrorAction Stop

try {
    Find-UHDTicket -GroupMemberId '17', '29'
    Get-UHDTicket -Id 42
}
finally {
    Disconnect-UHD
}
```

`config.local.json` muss vorab nach [der Vorlage](../config.example.json) mit der freigegebenen HTTPS-Basis angelegt werden. `Get-UHDTicket -Id` erwartet die interne Ticket-ID, nicht die sichtbare Ticketnummer (`RefNum`). Die Aufruffolge ist im Offline-Test oben mit gemocktem Transport abgedeckt.
