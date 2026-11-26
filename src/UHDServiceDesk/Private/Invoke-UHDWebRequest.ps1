function Invoke-UHDWebRequest {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Parameters
    )

    # Das Webcmdlet kann das HTTP-Requestobjekt auch bei einem abgefangenen
    # Fehler in -ErrorVariable und $Error ablegen. Ein eigener Runspace
    # trennt diese Fehleraufzeichnungen, ohne den Verlauf des Aufrufers zu ändern.
    $invocation = [powershell]::Create()
    try {
        $null = $invocation.AddScript({
            param([hashtable]$RequestParameters)

            try {
                $response = Invoke-WebRequest @RequestParameters
                [pscustomobject]@{ StatusCode = $response.StatusCode; Content = $response.Content }
            }
            catch {
                # Rohfehler und HTTP-Objekte bleiben im isolierten Runspace.
                return
            }
        }.ToString()).AddArgument($Parameters)
        $invocation.Invoke()
    }
    finally {
        $invocation.Dispose()
    }
}
