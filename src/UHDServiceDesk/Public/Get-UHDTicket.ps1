function Get-UHDTicket {
    <#
    .SYNOPSIS
        Ruft die Details eines Tickets oder die Liste seiner Untertickets ab.
    .DESCRIPTION
        RequestedId ist die angefragte Kennung. Im bestätigten Browserformat
        ist Id zusätzlich aus der Antwort belegt; abweichende IDs werden
        abgelehnt. Bekannte Detailzeitpunkte werden in UTC ausgegeben.
    .PARAMETER Id
        Numerische interne Ticket-ID, nicht die sichtbare Ticketnummer.
    .PARAMETER Children
        Fragt den dokumentierten Unterticket-Endpunkt ab. Eine bestätigte
        leere Liste liefert keine Objekte; andere Listenformate bleiben offen.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('\A[0-9]{1,30}\z')]
        [string]$Id,

        [switch]$Children
    )

    $session = Get-UHDSession
    $query = if ($Children) {
        [ordered]@{ OP = 'SEARCH'; FACTORY = 'in'; 'QBE.EQ.parent.id' = $Id; 'KEEP.forInChildList' = '1' }
    }
    else {
        [ordered]@{ OP = 'SHOW_DETAIL'; FACTORY = 'cr'; PERSID = "cr:${Id}" }
    }
    $requestFid = if ($Children) { Get-UHDRequestFid } else { $session.FID }
    $url = ConvertTo-UHDOperationUrl -Session $session -RequestFid $requestFid -Query $query
    $response = Invoke-UHDRequest -Session $session -Method GET -RelativeUrl $url -ReadOnly
    if ($Children) {
        return ConvertFrom-UHDEmptyList -Content ([string]$response.Content) -Factory in
    }
    $ticket = ConvertFrom-UHDTicketResponse -Content ([string]$response.Content)
    if ($ticket.PSObject.Properties['Id'] -and $ticket.Id -cne $Id) {
        throw 'Die UHD-Ticketantwort gehört nicht zur angefragten internen Ticket-ID.'
    }
    $ticket | Add-Member -NotePropertyName RequestedId -NotePropertyValue $Id -PassThru
}
