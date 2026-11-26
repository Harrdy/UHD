function Get-UHDTicketAttachment {
    <#
    .SYNOPSIS
        Fragt den dokumentierten Endpunkt für die Anhangliste eines Tickets ab.
    .DESCRIPTION
        Eindeutig leere Listen geben keine Objekte aus. Nicht leere oder
        unbekannte Formate werden noch nicht unterstützt. Das Cmdlet lädt
        keine Dateien herunter.
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
        HTMPL = 'list_attmnt_sd.htmpl'
        'KEEP.ticketFac' = 'cr'
        'QBE.EQ.requests.cr.persistent_id' = "cr:${Id}"
    })
    $response = Invoke-UHDRequest -Session $session -Method GET -RelativeUrl $url -ReadOnly
    ConvertFrom-UHDEmptyList -Content ([string]$response.Content) -Factory attmnt
}
