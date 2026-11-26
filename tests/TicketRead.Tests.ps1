Import-Module (Join-Path $PSScriptRoot '../src/UHDServiceDesk/UHDServiceDesk.psd1') -Force

Describe 'UHD-Tickets lesen' {
    InModuleScope UHDServiceDesk {
        BeforeEach {
            $script:UHDSession = $null
            $config = Join-Path $TestDrive 'ticket-read-config.json'
            '{"BaseUrl":"https://uhd.invalid/CAisd/"}' | Set-Content -LiteralPath $config
            $dummyPin = [System.Security.SecureString]::new()
            $dummyPin.AppendChar([char]65)
            $script:testCredential = [pscredential]::new('synthetisch', $dummyPin)
            Mock Invoke-WebRequest { throw 'Offline-Test: Netzwerkzugriff ist verboten.' }
            Mock Invoke-UHDRequest { throw 'Offline-Test: nicht erwarteter UHD-Request.' }
            Mock Invoke-UHDRequest {
                [pscustomobject]@{
                    Content = '<script>window.location="/CAisd/pdmweb2.exe?SID=151+FID=49+OP=REPLACE_LOGIN+HTMPL=post_menu.htmpl";</script>'
                }
            } -ParameterFilter { $Method -eq 'POST' -and $Form.OP -eq 'LOGIN' }
            Mock Invoke-UHDRequest {
                [pscustomobject]@{ Content = '<input name="SID" value="478"><input name="FID" value="913">' }
            } -ParameterFilter { $RelativeUrl -like '*OP=REPLACE_LOGIN*' }
            Mock Invoke-UHDRequest {
                [pscustomobject]@{ Content = '<title>Menü</title>' }
            } -ParameterFilter { $Method -eq 'POST' -and $Form.OP -eq 'MENU' }
            Mock Invoke-UHDRequest {
                [pscustomobject]@{ Content = 'OK' }
            } -ParameterFilter { $RelativeUrl -like '*ENDSESSION=1' }
        }

        AfterEach {
            $script:UHDSession = $null
            Should -Invoke Invoke-WebRequest -Exactly 0
        }

        It 'verbindet, sucht, liest Details und meldet offline ab' {
            Mock Invoke-UHDRequest {
                [pscustomobject]@{ Content = @'
<html><script>
var recordData = {"ref_num":"TEST-42","summary":"Erster Treffer","status":"crs:5200"};
recordData = {"ref_num":"TEST-57","summary":"Zweiter Treffer","unknown":"nicht ausgeben"};
</script></html>
'@ }
            } -ParameterFilter { $RelativeUrl -like '*OP=SEARCH+FACTORY=cr+*' }
            Mock Invoke-UHDRequest {
                [pscustomobject]@{ Content = @'
<form>
<input name="ref_num" value="TEST-42">
<input value="Anfrage &amp; Antwort" name='summary'>
<input name="status" value="crs:5200">
<textarea name="description">Text &lt;mit Inhalt&gt;</textarea>
</form>
'@ }
            } -ParameterFilter { $RelativeUrl -like '*OP=SHOW_DETAIL*' }

            (Connect-UHD -ConfigPath $config -Credential $script:testCredential).IsConnected | Should -BeTrue
            $tickets = @(Find-UHDTicket -GroupMemberId '17', '29')
            $tickets.Count | Should -Be 2
            ($tickets.RefNum -join ',') | Should -Be 'TEST-42,TEST-57'
            $tickets[1].PSObject.Properties.Name | Should -Not -Contain 'unknown'
            $ticket = Get-UHDTicket -Id 42
            $ticket.RequestedId | Should -Be '42'
            $ticket.RefNum | Should -Be 'TEST-42'
            $ticket.Status | Should -Be 'crs:5200'
            $ticket.Summary | Should -Be 'Anfrage & Antwort'
            $ticket.Description | Should -Be 'Text <mit Inhalt>'
            (Disconnect-UHD).RequestSent | Should -BeTrue

            Should -Invoke Invoke-UHDRequest -Exactly 6
            Should -Invoke Invoke-UHDRequest -Exactly 1 -ParameterFilter {
                $Method -eq 'GET' -and $ReadOnly -and
                $RelativeUrl -eq 'pdmweb2.exe?SID=478+FID=913+OP=SEARCH+FACTORY=cr+KEEP.where_clause=group.%5Bgroup%5Dgroup_list.member%20IN%20%2817%2C29%29'
            }
            Should -Invoke Invoke-UHDRequest -Exactly 1 -ParameterFilter {
                $Method -eq 'GET' -and $ReadOnly -and
                $RelativeUrl -eq 'pdmweb2.exe?SID=478+FID=913+OP=SHOW_DETAIL+FACTORY=cr+PERSID=cr%3A42'
            }
        }

        It 'meldet unbekannte Unterticket- und Anhangformate, aber sendet die belegten Requests' {
            $null = Connect-UHD -ConfigPath $config -Credential $script:testCredential
            Mock Invoke-UHDRequest {
                [pscustomobject]@{ Content = '<html>Unbekanntes Layout</html>' }
            } -ParameterFilter { $RelativeUrl -like '*OP=SEARCH*' }

            { Get-UHDTicket -Id 42 -Children } | Should -Throw '*Antwortformat der Unterticketliste*'
            { Get-UHDTicketAttachment -Id 42 } | Should -Throw '*Antwortformat der Anhangliste*'
            Should -Invoke Invoke-UHDRequest -Exactly 1 -ParameterFilter {
                $Method -eq 'GET' -and $ReadOnly -and
                $RelativeUrl -eq 'pdmweb2.exe?SID=478+FID=913+OP=SEARCH+FACTORY=in+QBE.EQ.parent.id=42'
            }
            Should -Invoke Invoke-UHDRequest -Exactly 1 -ParameterFilter {
                $Method -eq 'GET' -and $ReadOnly -and
                $RelativeUrl -eq 'pdmweb2.exe?SID=478+FID=913+OP=SEARCH+FACTORY=attmnt+QBE.EQ.requests.cr.persistent_id=cr%3A42'
            }
        }

        It 'lehnt nicht numerische IDs vor dem Request ab' {
            { Find-UHDTicket -GroupMemberId '17,29' } | Should -Throw
            { Get-UHDTicket -Id 'cr:42' } | Should -Throw
            { Get-UHDTicketAttachment -Id 'TEST-42' } | Should -Throw
            Should -Invoke Invoke-UHDRequest -Exactly 0
        }

        It 'meldet fehlende Sitzung vor dem Request' {
            { Find-UHDTicket -GroupMemberId 17 } | Should -Throw '*Keine aktive UHD-Sitzung*'
            Should -Invoke Invoke-UHDRequest -Exactly 0
        }

        It 'meldet fehlendes recordData als unbekannt, nicht als leere Liste' {
            { ConvertFrom-UHDTicketResponse -Content '<html><title>Ergebnis</title></html>' -Layout Search } |
                Should -Throw '*Antwortformat*'
        }

        It 'wertet Skriptcode nicht aus und ignoriert auskommentierte Daten' {
            $html = @'
<script>
/*
recordData = {"ref_num":"TEST-42","summary":"Auskommentiert"};
*/
recordData = makeRecord();
</script>
'@
            { ConvertFrom-UHDTicketResponse -Content $html -Layout Search } | Should -Throw '*Antwortformat*'
        }

        It 'gibt bei ungültigem JSON keine Teilergebnisse oder rohen Parserfehler aus' {
            $html = @'
<script>
recordData = {"ref_num":"TEST-42","summary":"Gültiges Einzelobjekt"};
recordData = {"interner-Schlüssel-TEST-SENTINEL": invalid!};
</script>
'@
            $emitted = [System.Collections.Generic.List[object]]::new()
            {
                ConvertFrom-UHDTicketResponse -Content $html -Layout Search -ErrorVariable script:parseErrors |
                    ForEach-Object { $emitted.Add($_) }
            } | Should -Throw '*Antwortformat*'
            $emitted.Count | Should -Be 0
            $errorText = $script:parseErrors | Out-String
            $errorText | Should -Match 'Antwortformat'
            $errorText | Should -Not -Match 'TEST-SENTINEL|Conversion from JSON'
        }

        It 'ignoriert scheinbare Zuweisungen innerhalb von mehrzeiligen Zeichenketten' {
            $html = @'
<script>
const fake = `
recordData = {"ref_num":"TEST-42","summary":"Keine Zuweisung"};
`;
</script>
'@
            { ConvertFrom-UHDTicketResponse -Content $html -Layout Search } | Should -Throw '*Antwortformat*'
        }

        It 'verwirft die ganze Seite, wenn eine echte mehrzeilige Zuweisung nicht unterstützt wird' {
            $html = @'
<script>
/*
recordData = {
    "ref_num":"DECOY-1"
};
*/
const decoy = `
recordData = {
    "ref_num":"DECOY-2"
};
`;
recordData = {"ref_num":"TEST-42","summary":"Gültiger Treffer"};
recordData =
{
    "ref_num":"TEST-57",
    "summary":"Mehrzeiliger Treffer"
};
</script>
'@
            $emitted = [System.Collections.Generic.List[object]]::new()
            {
                ConvertFrom-UHDTicketResponse -Content $html -Layout Search |
                    ForEach-Object { $emitted.Add($_) }
            } | Should -Throw '*Antwortformat*'
            $emitted.Count | Should -Be 0
        }

        It 'verwirft die ganze Seite bei einer Zuweisung nach <Prefix>' -ForEach @(
            @{ Prefix = 'einem Blockkommentar'; Code = '/* nächster Treffer */' }
            @{ Prefix = 'einer anderen Anweisung'; Code = 'const marker = 1;' }
        ) {
            $html = @"
<script>
recordData = {"ref_num":"TEST-42","summary":"Gültiger Treffer"};
$Code recordData = {"ref_num":"TEST-57","summary":"Anderes Layout"};
</script>
"@
            $emitted = [System.Collections.Generic.List[object]]::new()
            {
                ConvertFrom-UHDTicketResponse -Content $html -Layout Search |
                    ForEach-Object { $emitted.Add($_) }
            } | Should -Throw '*Antwortformat*'
            $emitted.Count | Should -Be 0
        }

        It 'ignoriert mehrzeilige Zuweisungsattrappen neben einem echten Treffer' {
            $html = @'
<script>
/*
recordData = {
    "ref_num":"DECOY-1"
};
*/
const decoy = `
recordData = {
    "ref_num":"DECOY-2"
};
`;
elsewhere. /* Mitglied, keine eigenständige Zuweisung */ recordData = {};
otherRecordData = {};
recordData = {"ref_num":"TEST-42","summary":"Gültiger Treffer"};
</script>
'@
            (ConvertFrom-UHDTicketResponse -Content $html -Layout Search).RefNum | Should -BeExactly 'TEST-42'
        }

        It 'erhält wörtliche Kommentar-, Script- und Style-Zeichen in Detailfeldern' {
            $html = @'
<!-- <input name="ref_num" value="DECOY-1"> -->
<script>const decoy = '<input name="ref_num" value="DECOY-2">';</script>
<style>.decoy { content: '<input name="ref_num" value="DECOY-3">'; }</style>
<input name="ref_num" value="TEST-42">
<input name="summary" value="Titel <!-- Kommentar --> <script>Code</script> <style>Stil</style>">
<textarea name="description">Text <!-- Kommentar --> <script>Code</script> <style>Stil</style> <input name="ref_num" value="DECOY-4"></textarea>
'@
            $ticket = ConvertFrom-UHDTicketResponse -Content $html -Layout Detail
            $ticket.RefNum | Should -BeExactly 'TEST-42'
            $ticket.Summary | Should -BeExactly 'Titel <!-- Kommentar --> <script>Code</script> <style>Stil</style>'
            $ticket.Description | Should -BeExactly 'Text <!-- Kommentar --> <script>Code</script> <style>Stil</style> <input name="ref_num" value="DECOY-4">'
        }

        It 'meldet kommentierte oder uneindeutige Detailfelder als unbekannt' {
            $html = '<!-- <input name="ref_num" value="TEST-42"> --><input name="summary" value="Text">'
            { ConvertFrom-UHDTicketResponse -Content $html -Layout Detail } | Should -Throw '*Antwortformat*'
            $html = '<input name="ref_num" value="TEST-42"><input name="ref_num" value="TEST-57"><input name="summary" value="Text">'
            { ConvertFrom-UHDTicketResponse -Content $html -Layout Detail } | Should -Throw '*Antwortformat*'
        }
    }
}
