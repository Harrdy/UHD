function Disconnect-UHD {
    <#
    .SYNOPSIS
        Beendet die aktuelle Sitzung am Ticketsystem.
    .DESCRIPTION
        Verwendet den Request, den der Browser beim Schließen des Fensters sendet
        (Aufzeichnung e479aea8-url_aufgerufen.har): GET pdmweb3.exe?SID=…+FID=0+ENDSESSION=1.
        STATUS: ungetestet gegen das Live-System.
    #>
    [CmdletBinding()]
    param()

    if (-not ($script:UHDSession -and $script:UHDSession.IsConnected)) {
        Write-Verbose 'Keine aktive Sitzung.'
        return
    }

    try {
        $null = Invoke-UHDRequest -Session $script:UHDSession -Method GET -RelativeUrl "pdmweb3.exe?SID=$($script:UHDSession.SID)+FID=0+ENDSESSION=1" -TimeoutSec 15
    }
    finally {
        $script:UHDSession.IsConnected = $false
        $script:UHDSession = $null
        Write-Verbose 'Sitzung im Modul verworfen.'
    }
}
