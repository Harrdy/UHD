function Get-UHDConfig {
    <#
    .SYNOPSIS
        Liest die Modulkonfiguration aus einer JSON-Datei.
    .DESCRIPTION
        Reihenfolge für den Pfad der Konfigurationsdatei:
        1. Parameter -ConfigPath
        2. Umgebungsvariable UHD_CONFIG_PATH
        3. %APPDATA%\UHDServiceDesk\config.json
        Relative Pfade in der Konfiguration (CredentialPath) werden gegen den Ordner
        der Konfigurationsdatei aufgelöst.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$ConfigPath
    )

    if (-not $ConfigPath) { $ConfigPath = $env:UHD_CONFIG_PATH }
    if (-not $ConfigPath) {
        $ConfigPath = Join-Path -Path ([Environment]::GetFolderPath('ApplicationData')) -ChildPath 'UHDServiceDesk\config.json'
    }
    $ConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)

    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "Konfigurationsdatei nicht gefunden: $ConfigPath. Vorlage: config.example.json."
    }

    $raw = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
    try {
        $cfg = $raw | ConvertFrom-Json
    }
    catch {
        throw "Konfigurationsdatei ist kein gültiges JSON: $ConfigPath"
    }

    $configDir = Split-Path -Parent $ConfigPath

    $credentialPath = if ($cfg.PSObject.Properties['CredentialPath'] -and $cfg.CredentialPath) {
        if ([System.IO.Path]::IsPathRooted($cfg.CredentialPath)) {
            [System.IO.Path]::GetFullPath($cfg.CredentialPath)
        }
        else {
            [System.IO.Path]::GetFullPath((Join-Path -Path $configDir -ChildPath $cfg.CredentialPath))
        }
    }
    else {
        Join-Path -Path $configDir -ChildPath 'uhd.credential.xml'
    }

    $timeout = if ($cfg.PSObject.Properties['TimeoutSec'] -and $cfg.TimeoutSec) { [int]$cfg.TimeoutSec } else { 60 }

    [pscustomobject]@{
        ConfigPath     = $ConfigPath
        BaseUrl        = [string]$cfg.BaseUrl
        CredentialPath = $credentialPath
        TimeoutSec     = $timeout
    }
}
