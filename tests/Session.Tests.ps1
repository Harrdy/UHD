Import-Module (Join-Path $PSScriptRoot '../src/UHDServiceDesk/UHDServiceDesk.psd1') -Force

Describe 'UHD-Sitzung und Transport' {
    InModuleScope UHDServiceDesk {
        BeforeEach {
            $script:UHDSession = $null
            $config = Join-Path $TestDrive 'config.json'
            '{"BaseUrl":"https://uhd.invalid/CAisd/","TimeoutSec":27}' | Set-Content -LiteralPath $config
            $credential = [pscredential]::new('synthetisch', (ConvertTo-SecureString 'TEST-PIN' -AsPlainText -Force))
            Mock Invoke-UHDWebRequest { return }
            Mock Invoke-UHDWebRequest {
                [pscustomobject]@{
                    StatusCode = 200
                    Content = '<script>window.location="/CAisd/pdmweb2.exe?SID=191+FID=82+OP=REPLACE_LOGIN+HTMPL=post_menu.htmpl";</script>'
                }
            } -ParameterFilter { $Parameters.Method -eq 'POST' -and $Parameters.Body.OP -eq 'LOGIN' -and $Parameters.Uri.AbsolutePath -eq '/CAisd/pdmweb3.exe' }
            Mock Invoke-UHDWebRequest {
                [pscustomobject]@{ StatusCode = 200; Content = '<!-- <input NAME="SID" value="11"> --><script>const s = ''<input NAME="FID" value="22">'';</script><input value="459" NAME="SID"><input NAME="FID" value="982">' }
            } -ParameterFilter { $Parameters.Method -eq 'GET' -and $Parameters.Uri.Query -like '*SID=191+FID=82+OP=REPLACE_LOGIN+HTMPL=post_menu.htmpl' }
            Mock Invoke-UHDWebRequest {
                [pscustomobject]@{ StatusCode = 200; Content = '<title>Menü</title>' }
            } -ParameterFilter { $Parameters.Method -eq 'POST' -and $Parameters.Body.OP -eq 'MENU' }
        }

        AfterEach {
            $script:UHDSession = $null
        }

        It 'übernimmt nach dem Login das bestätigte Servlet, trennt SID und FID und gibt sie nicht aus' {
            $messages = @(Connect-UHD -ConfigPath $config -Credential $credential -Verbose 4>&1)
            $result = $messages[-1]
            $result.IsConnected | Should -BeTrue
            ($result.PSObject.Properties.Name -join ',') | Should -Be 'IsConnected,ConnectedAt'
            $messages -join ' ' | Should -Not -Match '191|459|982|TEST-PIN'
            (Get-UHDSession).Servlet | Should -Be 'pdmweb2.exe'
            Should -Invoke Invoke-UHDWebRequest -Exactly 3
            Should -Invoke Invoke-UHDWebRequest -Exactly 3 -ParameterFilter {
                $timeoutConfigured = if ((Get-Command Microsoft.PowerShell.Utility\Invoke-WebRequest).Parameters.ContainsKey('OperationTimeoutSeconds')) {
                    $Parameters.ConnectionTimeoutSeconds -eq 27 -and $Parameters.OperationTimeoutSeconds -eq 27
                }
                else {
                    $Parameters.TimeoutSec -eq 27
                }
                $timeoutConfigured -and $Parameters.MaximumRedirection -eq 0 -and $Parameters.MaximumRetryCount -eq 0 -and -not $Parameters.ContainsKey('SkipCertificateCheck')
            }
            Should -Invoke Invoke-UHDWebRequest -Exactly 1 -ParameterFilter {
                $Parameters.Uri.AbsolutePath -eq '/CAisd/pdmweb2.exe' -and $Parameters.Method -eq 'POST' -and
                $Parameters.Body.OP -eq 'MENU' -and $Parameters.Body.POST_MENU -eq '1' -and $Parameters.Body.SID -eq '459' -and $Parameters.Body.FID -eq '982'
            }
        }

        It 'weist bei aktiver Sitzung die explizite Verbindungsoption <ParameterName> ab' -ForEach @(
            @{ ParameterName = 'BaseUrl'; Value = 'https://zweite-umgebung.invalid/CAisd/' }
            @{ ParameterName = 'ConfigPath'; Value = 'andere-konfiguration.json' }
            @{ ParameterName = 'Credential'; Value = [pscredential]::new('anderer-benutzer', (ConvertTo-SecureString 'ANDERER-TEST-PIN' -AsPlainText -Force)) }
            @{ ParameterName = 'ResetCredential'; Value = $true }
            @{ ParameterName = 'TimeoutSec'; Value = 48 }
        ) {
            $connection = Connect-UHD -ConfigPath $config -Credential $credential
            $original = Get-UHDSession
            $arguments = @{ $ParameterName = $Value }

            { Connect-UHD @arguments } | Should -Throw '*zuerst mit Disconnect-UHD*'
            [object]::ReferenceEquals((Get-UHDSession), $original) | Should -BeTrue
            (Get-UHDSession).BaseUrl | Should -Be 'https://uhd.invalid/CAisd/'
            (Connect-UHD).ConnectedAt | Should -Be $connection.ConnectedAt
            (Connect-UHD -Verbose:$false -ErrorAction Stop).ConnectedAt | Should -Be $connection.ConnectedAt

            Should -Invoke Invoke-UHDWebRequest -Exactly 3
            Should -Invoke Invoke-UHDWebRequest -Exactly 0 -ParameterFilter {
                $Parameters.Uri.Host -eq 'zweite-umgebung.invalid'
            }
        }

        It 'verwirft eine Weiterleitung auf einen fremden Host' {
            Mock Invoke-UHDWebRequest {
                [pscustomobject]@{
                    StatusCode = 200
                    Content = '<script>window.location="https://fremd.invalid/CAisd/pdmweb2.exe?SID=191+FID=82+OP=REPLACE_LOGIN+HTMPL=post_menu.htmpl";</script>'
                }
            } -ParameterFilter { $Parameters.Method -eq 'POST' -and $Parameters.Body.OP -eq 'LOGIN' -and $Parameters.Uri.AbsolutePath -eq '/CAisd/pdmweb3.exe' }
            { Connect-UHD -ConfigPath $config -Credential $credential } | Should -Throw '*Unerwarteter Zielpfad*'
            Should -Invoke Invoke-UHDWebRequest -Exactly 1
            { Get-UHDSession } | Should -Throw '*Keine aktive UHD-Sitzung*'
        }

        It 'verwirft eine nur in einem HTML-Kommentar enthaltene Weiterleitung' {
            Mock Invoke-UHDWebRequest {
                [pscustomobject]@{
                    StatusCode = 200
                    Content = '<!-- <script>window.location="/CAisd/pdmweb2.exe?SID=191+FID=82+OP=REPLACE_LOGIN+HTMPL=post_menu.htmpl";</script> -->'
                }
            } -ParameterFilter { $Parameters.Method -eq 'POST' -and $Parameters.Body.OP -eq 'LOGIN' -and $Parameters.Uri.AbsolutePath -eq '/CAisd/pdmweb3.exe' }
            { Connect-UHD -ConfigPath $config -Credential $credential } | Should -Throw '*keine eindeutige Sitzungsweiterleitung*'
            Should -Invoke Invoke-UHDWebRequest -Exactly 1
            Should -Invoke Invoke-UHDWebRequest -Exactly 0 -ParameterFilter { $Parameters.Method -eq 'GET' }
            { Get-UHDSession } | Should -Throw '*Keine aktive UHD-Sitzung*'
        }

        It 'verwirft ein unvollständiges Menüformular' {
            Mock Invoke-UHDWebRequest {
                [pscustomobject]@{ StatusCode = 200; Content = '<input NAME="SID" value="459">' }
            } -ParameterFilter { $Parameters.Method -eq 'GET' -and $Parameters.Uri.Query -like '*OP=REPLACE_LOGIN*' }
            { Connect-UHD -ConfigPath $config -Credential $credential } | Should -Throw '*Menüformular nicht gefunden*'
            Should -Invoke Invoke-UHDWebRequest -Exactly 2
            { Get-UHDSession } | Should -Throw '*Keine aktive UHD-Sitzung*'
        }

        It 'verwirft scheinbare Menüfelder in <Context> ohne Menü-POST' -ForEach @(
            @{ Context = 'HTML-Kommentaren'; Reply = '<!-- <input NAME="SID" value="459"><input NAME="FID" value="982"> -->' }
            @{ Context = 'Skriptinhalt'; Reply = '<script>const s = ''<input NAME="SID" value="459"><input NAME="FID" value="982">'';</script>' }
        ) {
            Mock Invoke-UHDWebRequest {
                [pscustomobject]@{ StatusCode = 200; Content = $Reply }
            } -ParameterFilter { $Parameters.Method -eq 'GET' -and $Parameters.Uri.Query -like '*OP=REPLACE_LOGIN*' }
            { Connect-UHD -ConfigPath $config -Credential $credential } | Should -Throw '*Menüformular nicht gefunden*'
            Should -Invoke Invoke-UHDWebRequest -Exactly 0 -ParameterFilter { $Parameters.Method -eq 'POST' -and $Parameters.Body.OP -eq 'MENU' }
            { Get-UHDSession } | Should -Throw '*Keine aktive UHD-Sitzung*'
        }

        It 'verwendet beim Abmelden den dokumentierten Modus: <Mode>' -ForEach @(
            @{ Mode = 'Fenster schließen'; UseMenu = $false; ExpectedPath = '/CAisd/pdmweb2.exe'; ExpectedQuery = '?SID=459+FID=0+ENDSESSION=1' }
            @{ Mode = 'Menü'; UseMenu = $true; ExpectedPath = '/CAisd/pdmweb.exe'; ExpectedQuery = '?SID=459+FID=982+OP=LOGOUT' }
        ) {
            $null = Connect-UHD -ConfigPath $config -Credential $credential
            Mock Invoke-UHDWebRequest { [pscustomobject]@{ StatusCode = 200; Content = 'OK' } } -ParameterFilter {
                $Parameters.Method -eq 'GET' -and $Parameters.Uri.Query -match 'ENDSESSION|OP=LOGOUT'
            }
            (Disconnect-UHD -MenuLogout:$UseMenu).RequestSent | Should -BeTrue
            Should -Invoke Invoke-UHDWebRequest -Exactly 1 -ParameterFilter {
                $Parameters.Method -eq 'GET' -and $Parameters.Uri.AbsolutePath -eq $ExpectedPath -and $Parameters.Uri.Query -eq $ExpectedQuery
            }
            { Get-UHDSession } | Should -Throw '*Keine aktive UHD-Sitzung*'
            (Disconnect-UHD).RequestSent | Should -BeFalse
            Should -Invoke Invoke-UHDWebRequest -Exactly 4
        }

        It 'verwirft die lokale Sitzung auch bei fehlgeschlagenem Abmelden' {
            $null = Connect-UHD -ConfigPath $config -Credential $credential
            { Disconnect-UHD } | Should -Throw '*UHD-Anfrage fehlgeschlagen*'
            { Get-UHDSession } | Should -Throw '*Keine aktive UHD-Sitzung*'
            Should -Invoke Invoke-UHDWebRequest -Exactly 4
        }

        It 'kodiert Daten abhängig vom Trennzeichen und schützt Sitzungsfelder vor Überschreiben' {
            $null = Connect-UHD -ConfigPath $config -Credential $credential
            $session = Get-UHDSession
            $query = [ordered]@{ OP = 'SEARCH'; 'KEEP.where_clause' = 'a + é&b' }
            ConvertTo-UHDOperationUrl -Session $session -Query $query |
                Should -Be 'pdmweb2.exe?SID=459+FID=982+OP=SEARCH+KEEP.where_clause=a%20%2B%20%C3%A9%26b'
            ConvertTo-UHDOperationUrl -Session $session -Query $query -Separator '&' |
                Should -Be 'pdmweb2.exe?SID=459&FID=982&OP=SEARCH&KEEP.where_clause=a%20%2B%20%C3%A9%26b'
            { ConvertTo-UHDOperationUrl -Session $session -Query @{ SID = 'neuer Wert' } } | Should -Throw '*Parametername*'
        }

        It 'wiederholt geschützte Requests nicht und veröffentlicht keine Rohfehler: <Failure>' -ForEach @(
            @{ Failure = 'Timeout' }
            @{ Failure = 'Redirect' }
            @{ Failure = 'HTTP 500' }
        ) {
            $null = Connect-UHD -ConfigPath $config -Credential $credential
            Mock Invoke-UHDWebRequest {
                if ($Failure -eq 'Timeout') { return }
                $status = if ($Failure -eq 'Redirect') { 302 } else { 500 }
                [pscustomobject]@{ StatusCode = $status; Content = 'TEST-FORMULAR' }
            } -ParameterFilter { $Parameters.Uri.Query -like '*OP=UPDATE*' }
            $lines = & {
                try {
                    Invoke-UHDRequest -Session (Get-UHDSession) -Method GET -RelativeUrl 'pdmweb2.exe?SID=459&OP=UPDATE&SET.description=TEST-FORMULAR' -ReadOnly -RetryCount 3 -RetryDelaySec 0 -Verbose
                }
                catch {
                    $_.Exception.Message
                }
            } 4>&1
            $lines -join ' ' | Should -Match 'UHD-Anfrage fehlgeschlagen|HTTP-Weiterleitung'
            $lines -join ' ' | Should -Not -Match '459|TEST-PIN|TEST-FORMULAR'
            Should -Invoke Invoke-UHDWebRequest -Exactly 1 -ParameterFilter {
                $Parameters.Uri.Query -like '*OP=UPDATE*' -and $Parameters.MaximumRedirection -eq 0 -and $Parameters.MaximumRetryCount -eq 0
            }
            Should -Invoke Invoke-UHDWebRequest -Exactly 4
        }

        It 'verwirft eine nicht mehr gültige Sitzung ohne Wiederholung' {
            $null = Connect-UHD -ConfigPath $config -Credential $credential
            Mock Invoke-UHDWebRequest {
                [pscustomobject]@{ StatusCode = 200; Content = '<form name="login"></form>' }
            } -ParameterFilter { $Parameters.Uri.Query -eq '?OP=SEARCH' }
            $request = @{ Session = (Get-UHDSession); Method = 'GET'; RelativeUrl = 'pdmweb2.exe?OP=SEARCH'; RetryCount = 2; RetryDelaySec = 0 }
            { Invoke-UHDRequest @request -ReadOnly } | Should -Throw '*Sitzung ist abgelaufen*'
            { Get-UHDSession } | Should -Throw '*Keine aktive UHD-Sitzung*'
            Should -Invoke Invoke-UHDWebRequest -Exactly 1 -ParameterFilter { $Parameters.Uri.Query -eq '?OP=SEARCH' }
        }

        It 'erlaubt Wiederholung nur bei ausdrücklich lesender Operation' {
            $null = Connect-UHD -ConfigPath $config -Credential $credential
            $request = @{ Session = (Get-UHDSession); Method = 'GET'; RelativeUrl = 'pdmweb2.exe?OP=SEARCH'; RetryCount = 2; RetryDelaySec = 0 }
            { Invoke-UHDRequest @request } | Should -Throw
            Should -Invoke Invoke-UHDWebRequest -Exactly 1 -ParameterFilter { $Parameters.Uri.Query -eq '?OP=SEARCH' }
            { Invoke-UHDRequest @request -ReadOnly } | Should -Throw
            Should -Invoke Invoke-UHDWebRequest -Exactly 4 -ParameterFilter { $Parameters.Uri.Query -eq '?OP=SEARCH' }
        }
    }
}

Describe 'Isolierte HTTP-Fehlergrenze' {
    It 'gibt bei echter Loopback-Verbindungsverweigerung kein HTTP-Requestobjekt an den Aufrufer' {
        # Den Port reservieren, aber absichtlich nicht listen: kein HTTPS-Server,
        # keine Zertifikatsänderung und kein Zugriff auf das UHD-Ticketsystem.
        $socket = [System.Net.Sockets.Socket]::new(
            [System.Net.Sockets.AddressFamily]::InterNetwork,
            [System.Net.Sockets.SocketType]::Stream,
            [System.Net.Sockets.ProtocolType]::Tcp
        )
        try {
            $socket.Bind([System.Net.IPEndPoint]::new([System.Net.IPAddress]::Loopback, 0))
            $baseUrl = 'https://127.0.0.1:{0}/CAisd/' -f $socket.LocalEndPoint.Port
            if (-not [System.Net.Http.HttpClient]::DefaultProxy.IsBypassed([uri]$baseUrl)) {
                Set-ItResult -Skipped -Because 'Die Umgebung führt Loopback über einen Proxy.'
                return
            }
            $config = Join-Path $TestDrive 'refused.json'
            @{ BaseUrl = $baseUrl; TimeoutSec = 5 } | ConvertTo-Json | Set-Content -LiteralPath $config
            $credential = [pscredential]::new('synthetisch', (ConvertTo-SecureString 'LOOPBACK-TEST-PIN' -AsPlainText -Force))
            $previousError = 'Fehler vor dem UHD-Aufruf.'
            Write-Error $previousError -ErrorAction SilentlyContinue
            $historyStart = $Error.Count
            $observed = @()
            $message = try {
                Connect-UHD -ConfigPath $config -Credential $credential -ErrorVariable +observed
            }
            catch {
                $_.Exception.Message
            }
            $message | Should -BeLike '*keine erfolgreiche HTTP-Antwort*'
            @($observed).Count | Should -BeGreaterThan 0
            $history = @($Error | Select-Object -First ($Error.Count - $historyStart))
            $history.Count | Should -BeGreaterThan 0
            $records = @($observed) + $history
            $records | ForEach-Object {
                if ($_ -is [System.Management.Automation.ErrorRecord]) {
                    $_.TargetObject -is [System.Net.Http.HttpRequestMessage] | Should -BeFalse
                }
            }
            ($records -join ' ') | Should -Not -Match 'LOOPBACK-TEST-PIN|127\.0\.0\.1|HttpRequestException'
            ($Error -join ' ') | Should -Match ([regex]::Escape($previousError))
        }
        finally {
            $socket.Dispose()
        }
    }
}
