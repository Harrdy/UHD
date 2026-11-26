function Connect-UHD {
    <#
    .SYNOPSIS
        Meldet sich am UHD Service Desk an und legt eine Sitzung im Modul ab.
    .DESCRIPTION
        Werte kommen aus der Konfigurationsdatei (siehe Get-UHDConfig), sofern nicht
        als Parameter angegeben. Fehlen gespeicherte Zugangsdaten, öffnet sich ein
        Login-Fenster und die Daten werden für die nächsten Anmeldungen gespeichert.

        Ablauf laut Aufzeichnung cd241174-login.har (formularbasiert, keine Cookies):
        1. POST pdmweb3.exe mit USERNAME, PIN, OP=LOGIN
        2. Antwort enthält eine Weiterleitung mit SID und FID (OP=REPLACE_LOGIN)
        3. GET auf diese Weiterleitung, liefert ein Formular mit SID und FID
        4. POST mit OP=MENU und POST_MENU=1 öffnet das Hauptmenü
        Eine aktive Sitzung wird nur ohne explizite Verbindungsoptionen
        wiederverwendet. Für Änderungen zuerst Disconnect-UHD ausführen.
        STATUS: ungetestet gegen das Live-System. Die Parser basieren auf den Aufzeichnungen.
    .PARAMETER ConfigPath
        Pfad zur Konfigurationsdatei. Standard: Umgebungsvariable UHD_CONFIG_PATH oder %APPDATA%\UHDServiceDesk\config.json
    .PARAMETER BaseUrl
        Überschreibt BaseUrl aus der Konfiguration, z. B. https://host/CAisd/
    .PARAMETER Credential
        Explizite Zugangsdaten. Dann werden keine gespeicherten Daten verwendet und nichts gespeichert.
    .PARAMETER ResetCredential
        Ignoriert gespeicherte Zugangsdaten und fragt erneut per Login-Fenster ab, z. B. nach Kennwortänderung.
    .EXAMPLE
        Connect-UHD
    .EXAMPLE
        Connect-UHD -ResetCredential -Verbose
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string]$ConfigPath,

        [string]$BaseUrl,

        [pscredential]$Credential,

        [switch]$ResetCredential,

        [ValidateRange(5, 600)]
        [int]$TimeoutSec
    )

    if ($script:UHDSession -and $script:UHDSession.IsConnected) {
        foreach ($option in 'BaseUrl', 'ConfigPath', 'Credential', 'ResetCredential', 'TimeoutSec') {
            if ($PSBoundParameters.ContainsKey($option)) {
                throw 'Eine UHD-Sitzung ist bereits aktiv. Bitte zuerst mit Disconnect-UHD abmelden, bevor Verbindungsoptionen angegeben werden.'
            }
        }
        Write-Verbose 'Bestehende Sitzung wird wiederverwendet.'
        return [pscustomobject]@{ IsConnected = $true; ConnectedAt = $script:UHDSession.ConnectedAt }
    }

    $cfg = Get-UHDConfig -ConfigPath $ConfigPath

    if (-not $BaseUrl) { $BaseUrl = $cfg.BaseUrl }
    if (-not $BaseUrl) { throw "Keine BaseUrl gesetzt. Bitte in $($cfg.ConfigPath) eintragen oder -BaseUrl angeben." }
    $baseUri = ConvertTo-UHDBaseUri -BaseUrl $BaseUrl
    if (-not $PSBoundParameters.ContainsKey('TimeoutSec')) { $TimeoutSec = $cfg.TimeoutSec }
    if ($TimeoutSec -lt 5 -or $TimeoutSec -gt 600) { throw 'UHD-Timeout muss zwischen 5 und 600 Sekunden liegen.' }

    $usesStoredCredential = -not $PSBoundParameters.ContainsKey('Credential')
    if ($usesStoredCredential) {
        $Credential = Get-UHDStoredCredential -Path $cfg.CredentialPath -Reset:$ResetCredential
    }

    $session = [pscustomobject]@{
        BaseUrl     = $baseUri.AbsoluteUri
        Servlet     = 'pdmweb3.exe'
        TimeoutSec  = $TimeoutSec
        SID         = $null
        FID         = $null
        IsConnected = $false
        ConnectedAt = $null
    }

    # Schritt 1: Login-POST
    $loginForm = @{
        PortalSession = ''
        USERNAME      = $Credential.UserName
        PIN           = $Credential.GetNetworkCredential().Password
        PDA           = 'No'
        OP            = 'LOGIN'
        INITIAL_LOAD  = 'PortalSession=+OP=LOGIN'
    }
    try {
        $step1 = Invoke-UHDRequest -Session $session -Method POST -RelativeUrl $session.Servlet -Form $loginForm
    }
    finally {
        $loginForm.Clear()
    }

    $redirect = Get-UHDLoginRedirect -Content $step1.Content -BaseUri $baseUri
    if ($null -eq $redirect) {
        $hint = if ($usesStoredCredential) { ' Falls sich das Kennwort geändert hat: Connect-UHD -ResetCredential.' } else { '' }
        throw "Anmeldung fehlgeschlagen: keine eindeutige Sitzungsweiterleitung erhalten.$hint"
    }
    $session.Servlet = $redirect.Servlet
    $step2 = Invoke-UHDRequest -Session $session -Method GET -RelativeUrl $redirect.RelativeUrl

    $fields = Get-UHDMenuSession -Content $step2.Content
    $session.SID = $fields.SID
    $session.FID = $fields.FID
    $menuForm = @{ SID = $session.SID; FID = $session.FID; OP = 'MENU'; POST_MENU = '1' }
    $menu = Invoke-UHDRequest -Session $session -Method POST -RelativeUrl $session.Servlet -Form $menuForm
    if ($menu.Content -match '\bname\s*=\s*["'']login["'']') {
        throw 'Anmeldung fehlgeschlagen: erneute Anmeldeseite statt UHD-Menü erhalten.'
    }

    $session.IsConnected = $true
    $session.ConnectedAt = Get-Date
    $script:UHDSession = $session

    Write-Verbose 'Mit dem UHD Service Desk verbunden.'
    [pscustomobject]@{ IsConnected = $true; ConnectedAt = $session.ConnectedAt }
}
