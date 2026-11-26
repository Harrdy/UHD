function ConvertTo-UHDOperationUrl {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Session,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Query,

        [ValidateSet('+', '&')]
        [string]$Separator = '+'
    )

    $fields = foreach ($key in $Query.Keys) {
        if ($key -notmatch '\A[A-Za-z][A-Za-z0-9_.]*\z' -or $key -in 'SID', 'FID') {
            throw 'Ungültiger Parametername für die UHD-Abfrage.'
        }
        '{0}={1}' -f $key, [uri]::EscapeDataString([string]$Query[$key])
    }
    $pairs = @(
        "SID=$([uri]::EscapeDataString([string]$Session.SID))"
        "FID=$([uri]::EscapeDataString([string]$Session.FID))"
        $fields
    )
    '{0}?{1}' -f $Session.Servlet, ($pairs -join $Separator)
}
