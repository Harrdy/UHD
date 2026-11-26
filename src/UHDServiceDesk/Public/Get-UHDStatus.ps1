function Get-UHDStatus {
    <#
    .SYNOPSIS
        Liest die Statusübergänge eines vorhandenen Tickets.
    .DESCRIPTION
        Gibt die Ziele mit Standardkennzeichnung und Kommentarpflicht aus,
        soweit sie im belegten Antwortformat enthalten sind. Die Bezeichnung
        wird nur ausgegeben, wenn sie in der Antwort vorhanden ist.
    .PARAMETER Id
        Numerische interne Ticket-ID, nicht die sichtbare Ticketnummer.
    .PARAMETER Status
        Aktueller Status als Kurzcode, zum Beispiel WIP.
    .PARAMETER TenantId
        Optionale 32-stellige Hex-Kennung des Ticketmandanten. Sie wird nicht
        automatisch ermittelt.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('\A[0-9]{1,30}\z')]
        [string]$Id,

        [Parameter(Mandatory)]
        [ValidatePattern('\A[A-Z][A-Z0-9]{0,31}\z')]
        [string]$Status,

        [ValidatePattern('\A[0-9A-Fa-f]{32}\z')]
        [string]$TenantId
    )

    $arguments = @{ Operation = 'VALID_TRANSITIONS'; Id = $Id; Status = $Status }
    if ($PSBoundParameters.ContainsKey('TenantId')) { $arguments.TenantId = $TenantId }
    $response = Invoke-UHDAuxiliaryRequest @arguments
    ConvertFrom-UHDStatusResponse -Content ([string]$response.Content)
}
