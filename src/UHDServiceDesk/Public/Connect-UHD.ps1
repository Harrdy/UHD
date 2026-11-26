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
    param(
        [string]$ConfigPath,

        [ValidatePattern('^https://')]
        [string]$BaseUrl,

        [pscredential]$Credential,

        [switch]$ResetCredential,

        [ValidateRange(5, 600)]
        [int]$TimeoutSec
    )

    if ($script:UHDSession -and $script:UHDSession.IsConnected) {
        Write-Verbose 'Bestehende Sitzung wird wiederverwendet.'
        return $script:UHDSession
    }

    $cfg = Get-UHDConfig -ConfigPath $ConfigPath

    if (-not $BaseUrl) { $BaseUrl = $cfg.BaseUrl }
    if (-not $BaseUrl) { throw "Keine BaseUrl gesetzt. Bitte in $($cfg.ConfigPath) eintragen oder -BaseUrl angeben." }
    if ($BaseUrl -notmatch '^https://') { throw 'BaseUrl muss mit https:// beginnen.' }
    if (-not $PSBoundParameters.ContainsKey('TimeoutSec')) { $TimeoutSec = $cfg.TimeoutSec }

    $usesStoredCredential = -not $PSBoundParameters.ContainsKey('Credential')
    if ($usesStoredCredential) {
        $Credential = Get-UHDStoredCredential -Path $cfg.CredentialPath -Reset:$ResetCredential
    }

    $session = [pscustomobject]@{
        BaseUrl     = $BaseUrl
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
    $step1 = Invoke-UHDRequest -Session $session -Method POST -RelativeUrl 'pdmweb3.exe' -Form $loginForm -TimeoutSec $TimeoutSec
    $loginForm.Clear()

    # Schritt 2: Weiterleitung auf REPLACE_LOGIN auswerten
    if ($step1.Content -notmatch 'SID=(\d+)\+FID=(\d+)\+OP=REPLACE_LOGIN') {
        $hint = if ($usesStoredCredential) { ' Falls sich das Kennwort geändert hat: Connect-UHD -ResetCredential.' } else { '' }
        throw "Anmeldung fehlgeschlagen: keine Sitzungsweiterleitung erhalten. Zugangsdaten prüfen.$hint"
    }
    $session.SID = $Matches[1]
    $session.FID = $Matches[2]

    $step2 = Invoke-UHDRequest -Session $session -Method GET -RelativeUrl "pdmweb3.exe?SID=$($session.SID)+FID=$($session.FID)+OP=REPLACE_LOGIN+HTMPL=post_menu.htmpl" -TimeoutSec $TimeoutSec

    # Schritt 3: Formular mit SID/FID aus der Antwort übernehmen, dann Menü öffnen
    if ($step2.Content -notmatch 'NAME="SID" VALUE="(\d+)"' -or $step2.Content -notmatch 'NAME="FID" VALUE="(\d+)"') {
        throw 'Anmeldung fehlgeschlagen: Menüformular nicht gefunden.'
    }
    $session.SID = $Matches[1]
    $session.FID = $Matches[2]

    $menuForm = @{ SID = $session.SID; FID = $session.FID; OP = 'MENU'; POST_MENU = '1' }
    $null = Invoke-UHDRequest -Session $session -Method POST -RelativeUrl 'pdmweb3.exe' -Form $menuForm -TimeoutSec $TimeoutSec

    $session.IsConnected = $true
    $session.ConnectedAt = Get-Date
    $script:UHDSession = $session

    Write-Verbose ('Verbunden. Sitzung: SID={0}***' -f $session.SID.Substring(0, [Math]::Min(3, $session.SID.Length)))
    $session
}
