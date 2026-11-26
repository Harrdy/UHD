function Get-UHDTicketActivity {
    <#
    .SYNOPSIS
        Liest die Aktivitäten eines Tickets.
    .PARAMETER Id
        Interne numerische Ticket-ID, nicht die sichtbare Ticketnummer.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('\A[0-9]{1,30}\z')]
        [string]$Id
    )

    $session = Get-UHDSession
    $url = ConvertTo-UHDOperationUrl -Session $session -Query ([ordered]@{
        OP = 'SEARCH'; FACTORY = 'alg'; 'QBE.EQ.call_req_id' = "cr:${Id}"
    })
    $response = Invoke-UHDRequest -Session $session -Method GET -RelativeUrl $url -ReadOnly
    ConvertFrom-UHDCapturedSearch -Content ([string]$response.Content) -ActivityTicketId $Id
}
