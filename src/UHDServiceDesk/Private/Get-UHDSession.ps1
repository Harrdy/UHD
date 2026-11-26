function Get-UHDSession {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    if (-not ($script:UHDSession -and $script:UHDSession.IsConnected)) {
        throw 'Keine aktive UHD-Sitzung. Bitte zuerst mit Connect-UHD anmelden.'
    }
    $script:UHDSession
}
