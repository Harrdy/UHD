Import-Module (Join-Path $PSScriptRoot '../src/UHDServiceDesk/UHDServiceDesk.psd1') -Force

Describe 'Leere UHD-Unterticket- und Anhanglisten' {
    InModuleScope UHDServiceDesk {
        BeforeAll {
            $script:listFixture = @'
<script>
var propFactory = "attmnt";
var propFormName = "list_attmnt_sd.htmpl";
</script>
<script>
var cfgTotal = '0';
var cfgRecordCount = '0';
</script>
<script>
rs.startList();
rs.drawGrid();
</script>
'@
        }

        BeforeEach {
            $script:UHDSession = [pscustomobject]@{
                IsConnected = $true
                SID = '215'
                FID = '589'
                Servlet = 'pdmweb.exe'
            }
            Mock Invoke-UHDWebRequest { throw 'Netzwerkzugriff im Test verboten.' }
        }

        AfterEach {
            $script:UHDSession = $null
        }

        It 'gibt bei bestätigter leerer Anhangliste keine Objekte aus' {
            Mock Invoke-UHDRequest { [pscustomobject]@{ Content = $script:listFixture } }
            @(Get-UHDTicketAttachment -Id 42).Count | Should -Be 0
            Should -Invoke Invoke-UHDRequest -Exactly 1 -ParameterFilter {
                $Method -eq 'GET' -and $ReadOnly -and
                $RelativeUrl -ceq 'pdmweb.exe?SID=215+FID=589+OP=SEARCH+FACTORY=attmnt+HTMPL=list_attmnt_sd.htmpl+KEEP.ticketFac=cr+QBE.EQ.requests.cr.persistent_id=cr%3A42'
            }
            Should -Invoke Invoke-UHDWebRequest -Exactly 0
        }

        It 'gibt bei bestätigter leerer Unterticketliste keine Objekte aus' {
            Mock Invoke-UHDRequest {
                [pscustomobject]@{ Content = $script:listFixture.Replace('"attmnt"', '"in"').Replace('list_attmnt_sd.htmpl', 'list_in.htmpl') }
            }
            @(Get-UHDTicket -Id 42 -Children).Count | Should -Be 0
            Should -Invoke Invoke-UHDRequest -Exactly 1 -ParameterFilter {
                $Method -eq 'GET' -and $ReadOnly -and
                $RelativeUrl -ceq 'pdmweb.exe?SID=215+FID=589+OP=SEARCH+FACTORY=in+QBE.EQ.parent.id=42+KEEP.forInChildList=1'
            }
            Should -Invoke Invoke-UHDWebRequest -Exactly 0
        }

        It 'missdeutet keine widersprüchlichen oder unvollständigen Antworten: <Case>' -ForEach @(
            @{ Case = 'positiver Zähler'; Old = "cfgTotal = '0'"; New = "cfgTotal = '1'" }
            @{ Case = 'mehrdeutiger Zähler'; Old = "cfgRecordCount = '0';"; New = "cfgRecordCount = '0';`nvar cfgRecordCount = '1';" }
            @{ Case = 'neu zugewiesener Zähler'; Old = "cfgRecordCount = '0';"; New = "cfgRecordCount = '0';`ncfgRecordCount = '2';" }
            @{ Case = 'berechneter Zähler'; Old = "cfgRecordCount = '0';"; New = "cfgRecordCount = readCount();" }
            @{ Case = 'Zeilen vorhanden'; Old = 'rs.startList();'; New = "rs.startList();`nrs.addRow(undef);" }
            @{ Case = 'Zeilensignal mit Leerzeichen'; Old = 'rs.startList();'; New = "rs.startList();`nrs . addRow (item);" }
            @{ Case = 'mehrzeiliges Zeilensignal'; Old = 'rs.startList();'; New = "rs.startList();`nrs`n .`naddRow`n(item);" }
            @{ Case = 'Zeilensignal mit Kommentarzwischenraum'; Old = 'rs.startList();'; New = "rs.startList();`nrs /* Kommentar */ . addRow(item);" }
            @{ Case = 'falsches Template'; Old = 'list_attmnt_sd.htmpl'; New = 'list_in.htmpl' }
            @{ Case = 'auskommentierter Zähler'; Old = "var cfgTotal = '0'"; New = "// var cfgTotal = '0'" }
            @{ Case = 'Zähler im String'; Old = "var cfgTotal = '0';"; New = "const text = ``var cfgTotal = '0';``;" }
        ) {
            $html = $script:listFixture.Replace($Old, $New)
            { ConvertFrom-UHDEmptyList -Content $html -Factory attmnt } | Should -Throw '*Antwortformat der Anhangliste*'
        }

        It 'erkennt keine Listenmarkierungen aus einem HTML-Kommentar oder Textfeld' {
            { ConvertFrom-UHDEmptyList -Content "<!--${script:listFixture}-->" -Factory attmnt } | Should -Throw '*Antwortformat*'
            { ConvertFrom-UHDEmptyList -Content "<textarea>${script:listFixture}</textarea>" -Factory attmnt } | Should -Throw '*Antwortformat*'
        }

        It 'ignoriert vorgetäuschte Zeilensignale in Kommentaren und Zeichenketten' {
            $html = $script:listFixture.Replace('rs.startList();', @'
rs . startList ();
const decoy = "rs . addRow(item)";
// rs . addRow(item);
/* rs . addRow(item); */
'@)
            @(ConvertFrom-UHDEmptyList -Content $html -Factory attmnt).Count | Should -Be 0
        }

        It 'verwirft ein nicht geschlossenes Skript' {
            $html = $script:listFixture.Substring(0, $script:listFixture.LastIndexOf('</script>'))
            { ConvertFrom-UHDEmptyList -Content $html -Factory attmnt } | Should -Throw '*Antwortformat*'
        }
    }
}
