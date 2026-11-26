Import-Module (Join-Path $PSScriptRoot '../src/UHDServiceDesk/UHDServiceDesk.psd1') -Force

Describe 'UHD-Leseprobenskript' {
    BeforeAll {
        $script:readProbePath = Join-Path $PSScriptRoot '../examples/Invoke-UHDReadProbe.ps1'
        $script:readProbeModule = Get-Module -Name UHDServiceDesk
    }

    BeforeEach {
        & $script:readProbeModule {
            $script:UHDSession = [pscustomobject]@{
                IsConnected = $true
                SID = '11'
                FID = '22'
                Servlet = 'pdmweb.exe'
            }
        }
        Mock Connect-UHD -ModuleName UHDServiceDesk { throw 'Keine automatische Anmeldung.' }
        Mock Disconnect-UHD -ModuleName UHDServiceDesk { throw 'Keine automatische Abmeldung.' }
        Mock Invoke-UHDWebRequest -ModuleName UHDServiceDesk { throw 'Netzwerkzugriff im Test verboten.' }
        Mock Get-Random -ModuleName UHDServiceDesk { 0.4321 }
        Mock Invoke-UHDRequest -ModuleName UHDServiceDesk {
            [pscustomobject]@{
                StatusCode = 200
                Content = '<html><title>VERTRAULICHER-SYNTHETISCHER-TITEL</title><form name="probe"><input name="summary" value="VERTRAULICHER-SYNTHETISCHER-WERT"><a href="/CAisd/pdmweb.exe?SID=11+FID=22+OP=PG+PG=1">Weiter</a></form></html>'
            }
        }
    }

    AfterEach {
        & $script:readProbeModule { $script:UHDSession = $null }
        Should -Invoke Connect-UHD -ModuleName UHDServiceDesk -Exactly 0
        Should -Invoke Disconnect-UHD -ModuleName UHDServiceDesk -Exactly 0
        Should -Invoke Invoke-UHDWebRequest -ModuleName UHDServiceDesk -Exactly 0
    }

    It 'verweigert unbestätigte oder ungültige Aufrufe vor jedem Request' {
        { & $script:readProbePath -Case Detail -TestTicketId 42 } | Should -Throw '*ausdrückliche Freigabe*'
        { & $script:readProbePath -Case Detail -TestTicketId 'SYNTHETISCH-UNGÜLTIG' -ApprovedLiveRead } | Should -Throw -ExpectedMessage 'Eine numerische interne Testticket-ID ist erforderlich.'
        { & $script:readProbePath -Case UPDATE -TestTicketId 42 -ApprovedLiveRead } | Should -Throw '*Zulässige Leseproben*'
        { & $script:readProbePath -Case Transitions -TestTicketId 42 -Status WIP -ApprovedLiveRead } | Should -Throw '*bekannte Hex-Mandantenkennung*'
        { & $script:readProbePath -Case Detail -TestTicketId 42 -Status WIP -ApprovedLiveRead } | Should -Throw '*nur für die Probe Transitions*'
        Should -Invoke Invoke-UHDRequest -ModuleName UHDServiceDesk -Exactly 0
    }

    It 'erfordert eine bestehende Sitzung ohne Anmeldung oder Request' {
        & $script:readProbeModule { $script:UHDSession = $null }
        { & $script:readProbePath -Case Detail -TestTicketId 42 -ApprovedLiveRead } | Should -Throw '*Keine aktive UHD-Sitzung*'
        Should -Invoke Invoke-UHDRequest -ModuleName UHDServiceDesk -Exactly 0
    }

    It 'sendet für <Name> genau den belegten GET und gibt nur Struktur aus' -ForEach @(
        @{ Name = 'Detail'; Query = 'OP=SHOW_DETAIL+FACTORY=cr+PERSID=cr%3A42'; Arguments = @{} }
        @{ Name = 'Children'; Query = 'OP=SEARCH+FACTORY=in+QBE.EQ.parent.id=42+KEEP.forInChildList=1'; Arguments = @{} }
        @{ Name = 'Attachments'; Query = 'OP=SEARCH+FACTORY=attmnt+HTMPL=list_attmnt_sd.htmpl+KEEP.ticketFac=cr+QBE.EQ.requests.cr.persistent_id=cr%3A42'; Arguments = @{} }
        @{ Name = 'Transitions'; Query = 'OP=VALID_TRANSITIONS+FACTORY=cr+STATUS_FACTORY=crs+STATUS=WIP+PERSID=cr%3A42+TENANT=00000000000000000000000000000000+TYPE=I'; Arguments = @{ Status = 'WIP'; TenantId = '00000000000000000000000000000000' } }
        @{ Name = 'Activities'; Query = 'OP=SEARCH+FACTORY=alg+QBE.EQ.call_req_id=cr%3A42'; Arguments = @{} }
    ) {
        $params = $Arguments
        $expectedFid = if ($Name -in 'Children', 'Attachments') { '4321' } else { '22' }
        $report = @(& $script:readProbePath -Case $Name -TestTicketId 42 -ApprovedLiveRead -Verbose @params 4>&1)
        $report.Count | Should -Be 1
        $report[0].Case | Should -BeExactly $Name
        $report[0].HttpStatus | Should -Be 200
        $report[0].Shape | Should -Not -BeNullOrEmpty
        ($report | ConvertTo-Json -Depth 10) | Should -Not -Match 'VERTRAULICHER|SID=|FID=|OP=PG|pdmweb|TicketId|TenantId'
        Should -Invoke Invoke-UHDRequest -ModuleName UHDServiceDesk -Exactly 1
        Should -Invoke Invoke-UHDRequest -ModuleName UHDServiceDesk -Exactly 1 -ParameterFilter {
            $Method -eq 'GET' -and $ReadOnly -and -not $IsWrite -and $RetryCount -eq 0 -and
            $RelativeUrl -ceq ('pdmweb.exe?SID=11+FID=' + $expectedFid + '+' + $Query)
        }
    }

    It 'gibt bei einem Fehler keinen Antworttext oder Request aus' {
        Mock Invoke-UHDRequest -ModuleName UHDServiceDesk { throw 'VERTRAULICHER-SYNTHETISCHER-FEHLER SID=11' }
        { & $script:readProbePath -Case Detail -TestTicketId 42 -ApprovedLiveRead } |
            Should -Throw -ExpectedMessage 'Die UHD-Leseprobe konnte nicht ausgewertet werden. Es werden keine Rohdaten ausgegeben.'
        Should -Invoke Invoke-UHDRequest -ModuleName UHDServiceDesk -Exactly 1
    }
}
