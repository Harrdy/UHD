BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\src\UHDServiceDesk\UHDServiceDesk.psd1') -Force
}

Describe 'Get-UHDConfig' {
    BeforeEach {
        $script:dir = Join-Path ([System.IO.Path]::GetTempPath()) ('uhd-test-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:dir | Out-Null
        $script:cfgPath = Join-Path $script:dir 'config.json'
    }

    AfterEach {
        Remove-Item -LiteralPath $script:dir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'liest BaseUrl und Standard-Timeout' {
        @{ BaseUrl = 'https://x/CAisd/' } | ConvertTo-Json | Set-Content -LiteralPath $script:cfgPath
        InModuleScope UHDServiceDesk -Parameters @{ Path = $script:cfgPath } {
            param($Path)
            $cfg = Get-UHDConfig -ConfigPath $Path
            $cfg.BaseUrl | Should -Be 'https://x/CAisd/'
            $cfg.TimeoutSec | Should -Be 60
        }
    }

    It 'löst relativen CredentialPath gegen den Konfigurationsordner auf' {
        @{ BaseUrl = 'https://x/CAisd/'; CredentialPath = 'sub\cred.xml' } | ConvertTo-Json | Set-Content -LiteralPath $script:cfgPath
        InModuleScope UHDServiceDesk -Parameters @{ Path = $script:cfgPath } {
            param($Path)
            $cfg = Get-UHDConfig -ConfigPath $Path
            $cfg.CredentialPath | Should -BeLike '*sub*cred.xml'
            $cfg.CredentialPath.StartsWith((Split-Path -Parent $Path)) | Should -BeTrue
        }
    }

    It 'verwendet den Standardnamen, wenn CredentialPath fehlt' {
        @{ BaseUrl = 'https://x/CAisd/' } | ConvertTo-Json | Set-Content -LiteralPath $script:cfgPath
        InModuleScope UHDServiceDesk -Parameters @{ Path = $script:cfgPath } {
            param($Path)
            (Get-UHDConfig -ConfigPath $Path).CredentialPath | Should -BeLike '*uhd.credential.xml'
        }
    }

    It 'meldet fehlende Konfigurationsdatei verständlich' {
        InModuleScope UHDServiceDesk -Parameters @{ Path = (Join-Path $script:dir 'fehlt.json') } {
            param($Path)
            { Get-UHDConfig -ConfigPath $Path } | Should -Throw -ExpectedMessage '*nicht gefunden*'
        }
    }
}
