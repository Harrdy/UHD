Import-Module (Join-Path $PSScriptRoot '../src/UHDServiceDesk/UHDServiceDesk.psd1') -Force

Describe 'UHD-Aktivitätsliste' {
    InModuleScope UHDServiceDesk {
        BeforeAll {
            $script:activityRow = @'
recordData = new Object();
recordData["persid"] = "alg:77";
listcall_req_id = "cr:123";
listtypecode = "TEST";
var analyst_persid = "cnt:ABCDEF0123456789ABCDEF0123456789";
rs.data('456');
recordData["call_req_id"] = celldatatowrite;
showUser("Testperson");
recordData["analyst"] = celldatatowrite;
rs.data(date_to_string('1234567890'));
recordData["time_stamp"] = celldatatowrite;
fmtType("Beispieltyp");
recordData["type"] = celldatatowrite;
UnEscapeDesc("Erster%20Wert");
recordData["description"] = celldatatowrite;
UnEscapeDesc("Sichtbarer%20Text%20%26%20mehr");
recordData["description"] = celldatatowrite;
rs.addRow(recordData["rownum"], recordData, styleData, imageData);
'@
        }

        BeforeEach {
            $script:UHDSession = [pscustomobject]@{ Servlet = 'pdmweb2.exe'; SID = '21'; FID = '43'; IsConnected = $true }
            Mock Invoke-UHDRequest { [pscustomobject]@{ Content = "<script>`n$script:activityRow`n</script>" } }
        }

        AfterEach {
            $script:UHDSession = $null
        }

        It 'gibt bestätigte interne und sichtbare Kennungen getrennt aus' {
            $activity = Get-UHDTicketActivity -Id 123
            $activity.Id | Should -BeExactly '77'
            $activity.TicketId | Should -BeExactly '123'
            $activity.RefNum | Should -BeExactly '456'
            $activity.Analyst | Should -BeExactly 'Testperson'
            $activity.AnalystId | Should -BeExactly 'ABCDEF0123456789ABCDEF0123456789'
            $activity.Timestamp | Should -Be ([DateTimeOffset]::FromUnixTimeSeconds(1234567890))
            $activity.Type | Should -BeExactly 'Beispieltyp'
            $activity.TypeCode | Should -BeExactly 'TEST'
            $activity.Description | Should -BeExactly 'Sichtbarer Text & mehr'
            Should -Invoke Invoke-UHDRequest -Exactly 1 -ParameterFilter {
                $Method -eq 'GET' -and $ReadOnly -and
                $RelativeUrl -ceq 'pdmweb2.exe?SID=21+FID=43+OP=SEARCH+FACTORY=alg+QBE.EQ.call_req_id=cr%3A123'
            }
        }

        It 'weist einen fremden Folgedatensatz ohne Ausgabe ab' {
            $other = $script:activityRow.Replace('alg:77', 'alg:78').Replace('cr:123', 'cr:999')
            Mock Invoke-UHDRequest { [pscustomobject]@{ Content = "<script>`n$script:activityRow`n$other`n</script>" } }
            $seen = [System.Collections.Generic.List[object]]::new()
            { Get-UHDTicketActivity -Id 123 | ForEach-Object { $seen.Add($_) } } | Should -Throw '*Antwortformat*'
            $seen.Count | Should -Be 0
        }

        It 'wertet keinen Kommentar und keine nicht belegte leere Seite als Ergebnis' {
            { ConvertFrom-UHDCapturedSearch -Content "<!--<script>`n$script:activityRow`n</script>-->" -ActivityTicketId 123 } |
                Should -Throw '*Antwortformat*'
        }
    }
}
