function Invoke-UHDRequest {
    <#
    .SYNOPSIS
        Zentrale HTTP-Kommunikation mit dem Ticketsystem.
    .DESCRIPTION
        Lesende Requests (GET) werden bei Fehlern wiederholt. Schreibende Requests (POST
        oder GET mit OP=UPDATE) werden NIE automatisch wiederholt, weil das Ergebnis
        unklar sein kann und sonst Dubletten entstehen.
        Erkennt eine Weiterleitung auf die Anmeldeseite als abgelaufene Sitzung.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Session,

        [Parameter(Mandatory)]
        [ValidateSet('GET', 'POST')]
        [string]$Method,

        # Relativer Pfad inkl. Query, z. B. 'pdmweb3.exe?SID=…+FID=…+OP=…'.
        # Das Zeichen '+' wird bewusst NICHT als Leerzeichen kodiert, weil das Ticketsystem es als Trenner nutzt.
        [Parameter(Mandatory)]
        [string]$RelativeUrl,

        [hashtable]$Form,

        [switch]$IsWrite,

        [ValidateRange(5, 600)]
        [int]$TimeoutSec = 60,

        [ValidateRange(0, 10)]
        [int]$RetryCount = 0,

        [ValidateRange(0, 60)]
        [int]$RetryDelaySec = 2
    )

    $uri = $Session.BaseUrl.TrimEnd('/') + '/' + $RelativeUrl.TrimStart('/')
    $maxAttempts = if ($IsWrite -or $Method -eq 'POST') { 1 } else { $RetryCount + 1 }

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $params = @{
                Uri             = $uri
                Method          = $Method
                TimeoutSec      = $TimeoutSec
                UseBasicParsing = $true
                ErrorAction     = 'Stop'
            }
            if ($Method -eq 'POST') {
                $params.Body = $Form
                $params.ContentType = 'application/x-www-form-urlencoded'
            }

            Write-Verbose ('{0} {1}' -f $Method, (ConvertTo-UHDMaskedUrl -Url $uri))
            $response = Invoke-WebRequest @params

            # Weiterleitung auf die Anmeldeseite = Sitzung abgelaufen oder nie gültig.
            if ($response.Content -match 'name="login"') {
                throw [System.InvalidOperationException]::new('UHD-Sitzung ist abgelaufen oder ungültig. Bitte erneut mit Connect-UHD anmelden.')
            }
            return $response
        }
        catch {
            $isLast = ($attempt -ge $maxAttempts)
            if ($isLast) { throw }
            Write-Verbose ("Versuch {0} fehlgeschlagen, neuer Versuch in {1} s: {2}" -f $attempt, $RetryDelaySec, $_.Exception.Message)
            Start-Sleep -Seconds $RetryDelaySec
        }
    }
}
