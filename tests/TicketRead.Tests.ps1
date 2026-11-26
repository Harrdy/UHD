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
            Mock Invoke-UHDWebRequest { throw 'Offline-Test: Netzwerkzugriff ist verboten.' }
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
            Mock Invoke-UHDRequest {
                [pscustomobject]@{ StatusCode = 200; Content = @'
<html><script>
recordData = new Object();
recordData["persid"] = "cr:42";
recordData["group.id"] = "B123456789ABCDEF0123456789ABCDEF";
writeIcon("TEST-42",ref_num_style);
recordData["ref_num"] = celldatatowrite;
rs.data("Erster Treffer");
recordData["summary"] = celldatatowrite;
rs.addRow(recordData["rownum"], recordData, styleData, imageData);
recordData = new Object();
recordData["persid"] = "cr:57";
writeIcon("TEST-57",ref_num_style);
recordData["ref_num"] = celldatatowrite;
rs.data("Zweiter Treffer");
recordData["summary"] = celldatatowrite;
rs.addRow(recordData["rownum"], recordData, styleData, imageData);
</script></html>
'@ }
            } -ParameterFilter { $RelativeUrl -like '*OP=SEARCH+FACTORY=cr+*' }
        }

        AfterEach {
            $script:UHDSession = $null
            Should -Invoke Invoke-UHDWebRequest -Exactly 0
        }

        It 'verbindet, sucht, liest Details und meldet offline ab' {
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
            $tickets = @(Find-UHDTicket -GroupMemberId 'A1B2C3D4E5F60718293A4B5C6D7E8F90')
            $tickets.Count | Should -Be 2
            ($tickets.RefNum -join ',') | Should -Be 'TEST-42,TEST-57'
            ($tickets.Id -join ',') | Should -Be '42,57'
            $tickets[0].GroupId | Should -Be 'B123456789ABCDEF0123456789ABCDEF'
            $tickets[1].Summary | Should -Be 'Zweiter Treffer'
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
                $RelativeUrl -ceq ('pdmweb2.exe?SID=478+FID=913+OP=SEARCH+FACTORY=cr+KEEP.where_clause=' +
                    [uri]::EscapeDataString("(status <> 'EXTERL' AND status <> 'EXTABG') and active=1 AND type = 'I' AND group.[group]group_list.member IN (U'A1B2C3D4E5F60718293A4B5C6D7E8F90')"))
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

        It 'sucht eine Seite aktiver Incidents ohne Gruppenfilter' {
            $null = Connect-UHD -ConfigPath $config -Credential $script:testCredential

            $tickets = @(Find-UHDTicket -AllActiveIncidents)
            ($tickets.RefNum -join ',') | Should -Be 'TEST-42,TEST-57'
            Should -Invoke Invoke-UHDRequest -Exactly 4
            Should -Invoke Invoke-UHDRequest -Exactly 1 -ParameterFilter {
                $Method -eq 'GET' -and $ReadOnly -and
                $RelativeUrl -ceq ('pdmweb2.exe?SID=478+FID=913+OP=SEARCH+FACTORY=cr+KEEP.where_clause=' +
                    [uri]::EscapeDataString("active=1 AND type = 'I' AND template_name is NULL"))
            }
        }

        It 'lehnt unbelegte oder manipulierte Mitgliedskennungen vor dem Request ab' {
            $null = Connect-UHD -ConfigPath $config -Credential $script:testCredential

            { Find-UHDTicket -GroupMemberId '17' } | Should -Throw
            { Find-UHDTicket -GroupMemberId 'A1B2C3D4-E5F6-0718-293A-4B5C6D7E8F90' } | Should -Throw
            { Find-UHDTicket -GroupMemberId "A1B2C3D4E5F60718293A4B5C6D7E8F90')" } | Should -Throw
            { Find-UHDTicket -GroupMemberId 'A1B2C3D4E5F60718293A4B5C6D7E8F90', 'B123456789ABCDEF0123456789ABCDEF' } | Should -Throw
            { Find-UHDTicket -GroupMemberId 'A1B2C3D4E5F60718293A4B5C6D7E8F90' -AllActiveIncidents } | Should -Throw
            { Find-UHDTicket -AllActiveIncidents:$false } | Should -Throw '*ausdrücklich*'
            Should -Invoke Invoke-UHDRequest -Exactly 3
            Should -Invoke Invoke-UHDRequest -Exactly 0 -ParameterFilter { $RelativeUrl -like '*OP=SEARCH*' }
        }

        It 'lehnt nicht numerische interne Ticket-IDs vor dem Request ab' {
            { Get-UHDTicket -Id 'cr:42' } | Should -Throw
            { Get-UHDTicketAttachment -Id 'TEST-42' } | Should -Throw
            Should -Invoke Invoke-UHDRequest -Exactly 0
        }

        It 'meldet fehlende Sitzung vor dem Request' {
            { Find-UHDTicket -GroupMemberId 'A1B2C3D4E5F60718293A4B5C6D7E8F90' } | Should -Throw '*Keine aktive UHD-Sitzung*'
            { Find-UHDTicket -AllActiveIncidents } | Should -Throw '*Keine aktive UHD-Sitzung*'
            Should -Invoke Invoke-UHDRequest -Exactly 0
        }

        It 'meldet unbekanntes Antwortformat und protokolliert nur feste Merkmale' {
            $null = Connect-UHD -ConfigPath $config -Credential $script:testCredential
            Mock Invoke-UHDRequest { [pscustomobject]@{ StatusCode = 200; Content = '<html><title>VERTRAULICHE-TESTMARKE</title><script>var recordData = [];</script></html>' } } -ParameterFilter {
                $RelativeUrl -like '*OP=SEARCH+FACTORY=cr+*'
            }
            $messages = & {
                try { Find-UHDTicket -AllActiveIncidents -Verbose }
                catch { $_.Exception.Message }
            } 4>&1
            $messages -join ' ' | Should -Match 'UHD-Suchantwort: HTTP=200; Zeichen=\d+; HTML=True; Skript=True; recordData=True; addRow=False'
            $messages -join ' ' | Should -Match 'Antwortformat'
            $messages -join ' ' | Should -Not -Match 'VERTRAULICHE-TESTMARKE|SID=|FID='
            Should -Invoke Invoke-UHDRequest -Exactly 1 -ParameterFilter { $RelativeUrl -like '*OP=SEARCH+FACTORY=cr+*' }
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
            $ticket = ConvertFrom-UHDTicketResponse -Content $html
            $ticket.RefNum | Should -BeExactly 'TEST-42'
            $ticket.Summary | Should -BeExactly 'Titel <!-- Kommentar --> <script>Code</script> <style>Stil</style>'
            $ticket.Description | Should -BeExactly 'Text <!-- Kommentar --> <script>Code</script> <style>Stil</style> <input name="ref_num" value="DECOY-4">'
        }

        It 'meldet kommentierte oder uneindeutige Detailfelder als unbekannt' {
            $html = '<!-- <input name="ref_num" value="TEST-42"> --><input name="summary" value="Text">'
            { ConvertFrom-UHDTicketResponse -Content $html } | Should -Throw '*Antwortformat*'
            $html = '<input name="ref_num" value="TEST-42"><input name="ref_num" value="TEST-57"><input name="summary" value="Text">'
            { ConvertFrom-UHDTicketResponse -Content $html } | Should -Throw '*Antwortformat*'
        }
    }
}
