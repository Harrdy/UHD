Import-Module (Join-Path $PSScriptRoot '../src/UHDServiceDesk/UHDServiceDesk.psd1') -Force

Describe 'UHD-Statusübergänge im Beobachtungsformat' {
    InModuleScope UHDServiceDesk {
        BeforeEach {
            Mock Invoke-UHDRequest { throw 'Nicht erwarteter Request im Offline-Test.' }
            $script:UHDSession = [pscustomobject]@{
                BaseUrl = 'https://uhd.invalid/CAisd/'
                Servlet = 'pdmweb2.exe'
                SID = '21'
                FID = '43'
                IsConnected = $true
            }
        }

        AfterEach {
            $script:UHDSession = $null
        }

        It 'liest Standard und Kommentarflag ohne frei erfundene Bezeichnungen' {
            Mock Invoke-UHDRequest { [pscustomobject]@{ Content = "QA@Gepr%C3%BCft@N@WAIT@Y@QA@N@`r`n`0" } }
            $rows = @(Get-UHDStatus -Id 123 -Status OPEN -TenantId 'ABCDEF0123456789ABCDEF0123456789')

            $rows.Code | Should -Be @('WAIT', 'QA')
            $rows[0].Label | Should -BeNullOrEmpty
            $rows[0].IsDefault | Should -BeFalse
            $rows[0].CommentRequired | Should -BeTrue
            $rows[1].Label | Should -BeExactly 'Geprüft'
            $rows[1].IsDefault | Should -BeTrue
            $rows[1].CommentRequired | Should -BeFalse
            Should -Invoke Invoke-UHDRequest -Exactly 1 -ParameterFilter {
                $Method -eq 'GET' -and $ReadOnly -and
                $RelativeUrl -ceq 'pdmweb2.exe?SID=21+FID=43+OP=VALID_TRANSITIONS+FACTORY=cr+STATUS_FACTORY=crs+STATUS=OPEN+PERSID=cr%3A123+TENANT=ABCDEF0123456789ABCDEF0123456789+TYPE=I'
            }
        }

        It 'liefert Ziele ohne Standard' {
            Mock Invoke-UHDRequest { [pscustomobject]@{ Content = "@@N@WAIT@N@QA@N@`r`n`0" } }
            $rows = @(Get-UHDStatus -Id 123 -Status OPEN)
            $rows.Code | Should -Be @('WAIT', 'QA')
            $rows[0].Label | Should -BeNullOrEmpty
            $rows[0].IsDefault | Should -BeFalse
            $rows[1].IsDefault | Should -BeFalse
        }

        It 'verwirft die gesamte Antwort bei <Name>' -ForEach @(
            @{ Name = 'abgeschnittenem Ende'; Reply = 'QA@Geprüft@N@QA@N@WAIT' }
            @{ Name = 'unbekanntem Kommentarflag'; Reply = 'QA@Geprüft@N@QA@N@WAIT@Z@' }
            @{ Name = 'doppeltem Ziel'; Reply = 'QA@Geprüft@N@QA@N@QA@Y@' }
            @{ Name = 'widersprüchlichem Standard'; Reply = 'QA@Geprüft@N@WAIT@N@' }
            @{ Name = 'Steuerzeichen im Text'; Reply = 'QA@Gepr%C3%BCft%00@N@QA@N@' }
            @{ Name = 'mehrdeutigem Leerformat'; Reply = '@@N@' }
        ) {
            Mock Invoke-UHDRequest { [pscustomobject]@{ Content = $Reply } }
            $seen = [System.Collections.Generic.List[object]]::new()
            { Get-UHDStatus -Id 123 -Status OPEN | ForEach-Object { $seen.Add($_) } } | Should -Throw '*Antwortformat der Statusübergänge ist noch offen*'
            $seen.Count | Should -Be 0
        }

        It 'sendet bei ungültigem Mandantenargument nichts' {
            { Get-UHDStatus -Id 123 -Status OPEN -TenantId 'ungültig' } | Should -Throw
            Should -Invoke Invoke-UHDRequest -Exactly 0
        }
    }
}
