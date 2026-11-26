function Disconnect-UHD {
    <#
    .SYNOPSIS
        Beendet die aktuelle Sitzung am Ticketsystem.
    .PARAMETER MenuLogout
        Verwendet alternativ den dokumentierten Menü-Logout.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [switch]$MenuLogout
    )

    if (-not ($script:UHDSession -and $script:UHDSession.IsConnected)) {
        $script:UHDSession = $null
        Write-Verbose 'Keine aktive Sitzung.'
        return [pscustomobject]@{ IsConnected = $false; RequestSent = $false }
    }

    $session = $script:UHDSession
    try {
        $url = if ($MenuLogout) {
            "pdmweb.exe?SID=$($session.SID)+FID=$($session.FID)+OP=LOGOUT"
        }
        else {
            "$($session.Servlet)?SID=$($session.SID)+FID=0+ENDSESSION=1"
        }
        $null = Invoke-UHDRequest -Session $session -Method GET -RelativeUrl $url
        [pscustomobject]@{ IsConnected = $false; RequestSent = $true }
    }
    finally {
        $session.IsConnected = $false
        $script:UHDSession = $null
        Write-Verbose 'Sitzung im Modul verworfen.'
    }
}
