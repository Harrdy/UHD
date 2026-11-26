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

## Erste Incident-Seite suchen

Nur mit ausdrücklicher Freigabe und vorgesehenen Testtickets verwenden. Die Aufruffolge wurde mit gemocktem Transport geprüft, nicht live. Lege vorher `config.local.json` nach [der Vorlage](../config.example.json) mit der freigegebenen HTTPS-Basis an.

```powershell
Import-Module ./src/UHDServiceDesk/UHDServiceDesk.psd1 -Force
$credential = Get-Credential -Message 'Anmeldung am Testsystem'
Connect-UHD -ConfigPath ./config.local.json -Credential $credential -ErrorAction Stop

try {
    Find-UHDTicket -AllActiveIncidents |
        Format-Table Id, RefNum, Status, Summary, Group, GroupId -AutoSize

    $memberId = Read-Host 'Mitgliedskennung (32 Hex-Zeichen ohne Bindestriche)'
    Find-UHDTicket -GroupMemberId $memberId |
        Format-Table Id, RefNum, Status, Summary, Group, GroupId -AutoSize
}
finally {
    Disconnect-UHD
}
```

`-AllActiveIncidents` zeigt die erste Seite aktiver Incidents ohne Gruppenfilter und ohne Vorlagen. `-GroupMemberId` zeigt die erste Seite aktiver Incidents aus den Gruppen der angegebenen Mitgliedschaft, außer den Status `EXTERL` und `EXTABG`. Die Mitgliedskennung steht in einer bestehenden Browser-Suchanfrage im Filter `group_list.member`: Gib nur die Hex-Zeichen ein, ohne das umgebende `U'…'`. `GroupId` in der Ausgabe bezeichnet dagegen die Gruppe des Tickets. Ein Filter nach genau einer Gruppe, weitere Seiten und eine Suche nach allen Tickets werden noch nicht unterstützt.

Für einen Detailabruf erwartet `Get-UHDTicket -Id` den Wert aus der Spalte `Id`, nicht die sichtbare Ticketnummer `RefNum`. Der Detailparser wurde nur mit synthetischen Antworten geprüft.
