function Invoke-UHDRequest {
    <#
    .SYNOPSIS
        Zentrale HTTP-Kommunikation mit dem Ticketsystem.
    .DESCRIPTION
        Nur ausdrücklich lesende GET-Aufrufe dürfen wiederholt werden.
        Weiterleitungen und automatische HTTP-Wiederholungen sind deaktiviert.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Session,

        [Parameter(Mandatory)]
        [ValidateSet('GET', 'POST')]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$RelativeUrl,

        [hashtable]$Form,

        [switch]$IsWrite,

        [switch]$ReadOnly,

        [ValidateRange(5, 600)]
        [int]$TimeoutSec = $Session.TimeoutSec,

        [ValidateRange(0, 10)]
        [int]$RetryCount = 0,

        [ValidateRange(0, 60)]
        [int]$RetryDelaySec = 2
    )

    if ($TimeoutSec -lt 5 -or $TimeoutSec -gt 600) { throw 'UHD-Timeout muss zwischen 5 und 600 Sekunden liegen.' }
    $baseUri = ConvertTo-UHDBaseUri -BaseUrl $Session.BaseUrl
    if ($RelativeUrl -notmatch '\Apdmweb[23]?\.exe(?:\?[^#\p{C}]*)?\z') {
        throw 'Ungültiger relativer UHD-Endpunkt.'
    }
    $uri = [uri]($baseUri.AbsoluteUri + $RelativeUrl)
    $protectedOperation = $RelativeUrl -match '(?:[?+&]OP=(?:UPDATE|LOGOUT|REPLACE_LOGIN|CREATE_NEW)(?:[+&]|$)|[?+&]ENDSESSION=)'
    $maxAttempts = if ($ReadOnly -and -not $IsWrite -and $Method -eq 'GET' -and -not $protectedOperation) { $RetryCount + 1 } else { 1 }
    $params = @{
        Uri                = $uri
        Method             = $Method
        UseBasicParsing    = $true
        MaximumRedirection = 0
        MaximumRetryCount  = 0
        SkipHttpErrorCheck = $true
        ErrorAction        = 'Stop'
        Verbose            = $false
        Debug              = $false
    }
    $webParameters = (Get-Command Microsoft.PowerShell.Utility\Invoke-WebRequest).Parameters
    if ($webParameters.ContainsKey('OperationTimeoutSeconds') -and $webParameters.ContainsKey('ConnectionTimeoutSeconds')) {
        $params.ConnectionTimeoutSeconds = $TimeoutSec
        $params.OperationTimeoutSeconds = $TimeoutSec
    }
    else {
        $params.TimeoutSec = $TimeoutSec
    }
    if ($Method -eq 'POST') {
        $params.Body = $Form
        $params.ContentType = 'application/x-www-form-urlencoded'
    }

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        Write-Verbose ('{0} {1}' -f $Method, (ConvertTo-UHDMaskedUrl -Url $uri))
        $response = Invoke-UHDWebRequest -Parameters $params
        if ($null -ne $response) {
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
                if ($Session.IsConnected -and $response.Content -match '\bname\s*=\s*["'']login["'']') {
                    $Session.IsConnected = $false
                    throw 'UHD-Sitzung ist abgelaufen oder ungültig. Bitte erneut mit Connect-UHD anmelden.'
                }
                return $response
            }
            if ($response.StatusCode -ge 300 -and $response.StatusCode -lt 400) {
                throw 'Unerwartete HTTP-Weiterleitung des UHD-Endpunkts; der Zielpfad wurde nicht aufgerufen.'
            }
        }
        if ($attempt -eq $maxAttempts) { throw 'UHD-Anfrage fehlgeschlagen; es liegt keine erfolgreiche HTTP-Antwort vor.' }
        Write-Verbose ('Versuch {0} fehlgeschlagen; erneuter Versuch in {1} s.' -f $attempt, $RetryDelaySec)
        Start-Sleep -Seconds $RetryDelaySec
    }
}
