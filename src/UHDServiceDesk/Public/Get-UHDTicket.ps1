function Get-UHDTicket {
    <#
    .SYNOPSIS
        Ruft die Details eines Tickets oder die Liste seiner Untertickets ab.
    .DESCRIPTION
        RequestedId gibt die angefragte ID wieder, nicht eine unabhängig aus
        der Antwort bestätigte Kennung. Das unterstützte Detaillayout wurde
        mit synthetischen Daten offline geprüft.
    .PARAMETER Id
        Numerische interne Ticket-ID, nicht die sichtbare Ticketnummer.
    .PARAMETER Children
        Fragt den dokumentierten Unterticket-Endpunkt ab. Das Antwortformat ist
        noch offen; derzeit endet die Abfrage daher mit einem kontrollierten Fehler.
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
        [ordered]@{ OP = 'SEARCH'; FACTORY = 'in'; 'QBE.EQ.parent.id' = $Id }
    }
    else {
        [ordered]@{ OP = 'SHOW_DETAIL'; FACTORY = 'cr'; PERSID = "cr:${Id}" }
    }
    $url = ConvertTo-UHDOperationUrl -Session $session -Query $query
    $response = Invoke-UHDRequest -Session $session -Method GET -RelativeUrl $url -ReadOnly
    if ($Children) {
        throw 'Das Antwortformat der Unterticketliste ist noch offen; die Liste konnte nicht ausgewertet werden.'
    }
    $ticket = ConvertFrom-UHDTicketResponse -Content ([string]$response.Content) -Layout Detail
    $ticket | Add-Member -NotePropertyName RequestedId -NotePropertyValue $Id -PassThru
}
