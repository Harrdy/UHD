function Get-UHDTicketAttachment {
    <#
    .SYNOPSIS
        Fragt den dokumentierten Endpunkt für die Anhangliste eines Tickets ab.
    .DESCRIPTION
        Das Antwortformat der Liste ist noch offen; die Abfrage endet derzeit mit
        einem kontrollierten Fehler. Dieses Cmdlet lädt keine Dateien herunter.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('\A[0-9]{1,30}\z')]
        [string]$Id
    )

    $session = Get-UHDSession
    $url = ConvertTo-UHDOperationUrl -Session $session -Query ([ordered]@{
        OP = 'SEARCH'
        FACTORY = 'attmnt'
        'QBE.EQ.requests.cr.persistent_id' = "cr:${Id}"
    })
    $null = Invoke-UHDRequest -Session $session -Method GET -RelativeUrl $url -ReadOnly
    throw 'Das Antwortformat der Anhangliste ist noch offen; die Liste konnte nicht ausgewertet werden.'
}
