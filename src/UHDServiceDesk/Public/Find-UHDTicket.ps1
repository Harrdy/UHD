function Find-UHDTicket {
    <#
    .SYNOPSIS
        Sucht die erste Seite nach Mitgliedschaft in den Ticketgruppen.
    .DESCRIPTION
        Verwendet den dokumentierten Gruppenmitgliedschaftsfilter mit numerischen
        Mitgliedskennungen. Kein Freitextfilter und keine automatische Pagination.
        Die Beobachtung in der Analyse entspricht höchstens 50 Treffern pro Seite.
        Das unterstützte Antwortlayout wurde mit synthetischen Daten offline geprüft.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('\A[0-9]{1,30}\z')]
        [string[]]$GroupMemberId
    )

    $session = Get-UHDSession
    $condition = 'group.[group]group_list.member IN ({0})' -f ($GroupMemberId -join ',')
    $url = ConvertTo-UHDOperationUrl -Session $session -Query ([ordered]@{
        OP = 'SEARCH'
        FACTORY = 'cr'
        'KEEP.where_clause' = $condition
    })
    $response = Invoke-UHDRequest -Session $session -Method GET -RelativeUrl $url -ReadOnly
    ConvertFrom-UHDTicketResponse -Content ([string]$response.Content) -Layout Search
}
