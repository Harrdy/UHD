BeforeAll {
    $manifest = Join-Path $PSScriptRoot '..\src\UHDServiceDesk\UHDServiceDesk.psd1'
    Import-Module $manifest -Force
}

Describe 'Modul UHDServiceDesk' {
    It 'exportiert die geplanten 15 Cmdlets' {
        (Get-Command -Module UHDServiceDesk -CommandType Function).Count | Should -Be 15
    }

    It 'Platzhalter werfen NotImplementedException' {
        { Get-UHDUser } | Should -Throw -ExpectedMessage '*noch nicht implementiert*'
    }
}

Describe 'ConvertTo-UHDMaskedUrl' {
    It 'maskiert SID und PIN' {
        InModuleScope UHDServiceDesk {
            ConvertTo-UHDMaskedUrl -Url 'https://x/pdmweb3.exe?SID=123456+FID=5+OP=UPDATE' | Should -Be 'https://x/pdmweb3.exe?SID=***+FID=5+OP=UPDATE'
        }
    }
}
