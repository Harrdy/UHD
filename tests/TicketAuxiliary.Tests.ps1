Import-Module (Join-Path $PSScriptRoot '../src/UHDServiceDesk/UHDServiceDesk.psd1') -Force

Describe 'UHD-Hilfsoperationen und Schreibgrenze' {
    InModuleScope UHDServiceDesk {
        BeforeEach {
            $script:UHDSession = [pscustomobject]@{
                BaseUrl = 'https://uhd.invalid/CAisd/'
                Servlet = 'pdmweb2.exe'
                SID = '21'
                FID = '43'
                TimeoutSec = 60
                IsConnected = $true
            }
            Mock Invoke-UHDRequest { [pscustomobject]@{ Content = 'WIP@In%20Bearbeitung' } }
        }

        AfterEach {
            $script:UHDSession = $null
        }

        It 'sendet genau den belegten Request für <Operation>' -ForEach @(
            @{ Operation = 'CREATE_NEW'; Arguments = @{}; Query = 'OP=CREATE_NEW+FACTORY=cr+PRESET=type%3AI'; IsReadOnly = $false }
            @{ Operation = 'GET_REQUIRED_FIELDS'; Arguments = @{ Status = 'WIP' }; Query = 'OP=GET_REQUIRED_FIELDS+FACTORY=cr+status=WIP'; IsReadOnly = $true }
            @{ Operation = 'SPEC_HAND'; Arguments = @{ Id = 'test-kontakt' }; Query = 'OP=SPEC_HAND+FACTORY=cnt+PERSID=cnt%3Atest-kontakt'; IsReadOnly = $true }
            @{ Operation = 'GET_SVC_CONTRACT'; Arguments = @{ Id = 'test-kontakt' }; Query = 'OP=GET_SVC_CONTRACT+new_customer=cnt%3Atest-kontakt'; IsReadOnly = $true }
            @{ Operation = 'GET_PRI_CAL'; Arguments = @{}; Query = 'OP=GET_PRI_CAL+FACTORY=in'; IsReadOnly = $true }
        ) {
            $null = Invoke-UHDAuxiliaryRequest -Operation $Operation @Arguments
            Should -Invoke Invoke-UHDRequest -Exactly 1 -ParameterFilter {
                $Method -eq 'GET' -and $RelativeUrl -ceq "pdmweb2.exe?SID=21+FID=43+$Query" -and [bool]$ReadOnly -eq $IsReadOnly
            }
            Should -Invoke Invoke-UHDRequest -Exactly 1
        }

        It 'liefert einen strukturierten und dekodierten Statusübergang' {
            $result = Get-UHDStatus -Id 123 -Status OP
            $result.Code | Should -Be 'WIP'
            $result.Label | Should -Be 'In Bearbeitung'
            Should -Invoke Invoke-UHDRequest -Exactly 1 -ParameterFilter {
                $Method -eq 'GET' -and $ReadOnly -and
                $RelativeUrl -ceq 'pdmweb2.exe?SID=21+FID=43+OP=VALID_TRANSITIONS+FACTORY=cr+STATUS_FACTORY=crs+STATUS=OP+PERSID=cr%3A123+TYPE=I'
            }
        }

        It 'weist ein unbelegtes Antwortformat mit kontrolliertem Fehler ab: <Name>' -ForEach @(
            @{ Name = 'unbekannte Hülle'; Reply = '<script>SECRET-WIP@In%20Bearbeitung</script>' }
            @{ Name = 'mehrere Einträge'; Reply = 'WIP@In%20Bearbeitung,CL@Geschlossen' }
            @{ Name = 'kein Eintrag'; Reply = '' }
            @{ Name = 'ungültige Kodierung'; Reply = 'WIP@Ung%C3%G4ltig' }
            @{ Name = 'ungueltiges UTF-8'; Reply = 'WIP@%FF' }
            @{ Name = 'kodiertes Steuerzeichen'; Reply = 'WIP@Label%0A' }
        ) {
            Mock Invoke-UHDRequest { [pscustomobject]@{ Content = $Reply } }
            { Get-UHDStatus -Id 123 -Status OP } | Should -Throw '*Antwortformat der Statusübergänge ist noch offen*'
            Should -Invoke Invoke-UHDRequest -Exactly 1
        }

        It 'bereitet das Bearbeitungsöffnen vor, sendet es aber nicht' {
            $query = Get-UHDAuxiliaryQuery -Operation UPDATE -Id 123
            ($query.Keys -join ',') | Should -BeExactly 'OP,FACTORY,SET.id'
            $query.OP | Should -Be 'UPDATE'
            $query.FACTORY | Should -Be 'cr'
            $query['SET.id'] | Should -Be '123'
            { Invoke-UHDAuxiliaryRequest -Operation UPDATE -Id 123 } | Should -Throw
            Should -Invoke Invoke-UHDRequest -Exactly 0
        }

        It 'bereitet nur den bekannten OP-Wert für <Operation> vor' -ForEach @(
            @{ Operation = 'GROUP_IN_AGT' }
            @{ Operation = 'AGT_IN_GROUP' }
        ) {
            $query = Get-UHDAuxiliaryQuery -Operation $Operation
            $query.Count | Should -Be 1
            $query.OP | Should -Be $Operation
            { Invoke-UHDAuxiliaryRequest -Operation $Operation } | Should -Throw
            Should -Invoke Invoke-UHDRequest -Exactly 0
        }

        It 'sendet keine Requests für unvollständige oder ungültige Argumente' {
            { Invoke-UHDAuxiliaryRequest -Operation SPEC_HAND } | Should -Throw '*Kontakt-ID*'
            { Invoke-UHDAuxiliaryRequest -Operation GET_REQUIRED_FIELDS } | Should -Throw '*Kurzcode*'
            { Get-UHDStatus -Id '123+OP=UPDATE' -Status OP } | Should -Throw
            { Get-UHDStatus -Id 123 -Status 'OP+OP=UPDATE' } | Should -Throw
            Should -Invoke Invoke-UHDRequest -Exactly 0
        }

        It 'sendet weder Save noch Formularabruf für blockierte Schreibpfade' {
            { New-UHDTicket -Confirm:$false } | Should -Throw '*vollständige Speicherformular*'
            { Set-UHDTicket -Confirm:$false } | Should -Throw '*Sperrverhalten*'
            { New-UHDTicket -WhatIf } | Should -Not -Throw
            { Set-UHDTicket -WhatIf } | Should -Not -Throw
            { Close-UHDTicket } | Should -Throw
            { Add-UHDTicketComment } | Should -Throw
            { Add-UHDTicketAttachment } | Should -Throw
            Should -Invoke Invoke-UHDRequest -Exactly 0
        }

        It 'sendet keine Ersatzabfragen für nicht belegte öffentliche Listen' {
            { Get-UHDUser } | Should -Throw '*Antwortformat ist offen*'
            { Get-UHDGroup } | Should -Throw '*Parameter und Antwortformate*'
            { Get-UHDPriority } | Should -Throw '*Prioritätsberechnung*'
            Should -Invoke Invoke-UHDRequest -Exactly 0
        }
    }
}
