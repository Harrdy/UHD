function Invoke-UHDAuxiliaryRequest {
    <#
    .SYNOPSIS
        Führt die belegten Hilfsabfragen und den Anlegeformularabruf aus.
    .DESCRIPTION
        UPDATE zum Bearbeitungsöffnen kann möglicherweise sperren. Für
        GROUP_IN_AGT und AGT_IN_GROUP sind die nötigen Argumente offen.
        Diese drei Operationen werden hier daher nicht gesendet.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('CREATE_NEW', 'VALID_TRANSITIONS', 'GET_REQUIRED_FIELDS', 'SPEC_HAND', 'GET_SVC_CONTRACT', 'GET_PRI_CAL')]
        [string]$Operation,

        [string]$Id,

        [string]$Status
    )

    $query = Get-UHDAuxiliaryQuery @PSBoundParameters
    $session = Get-UHDSession
    $url = ConvertTo-UHDOperationUrl -Session $session -Query $query
    Invoke-UHDRequest -Session $session -Method GET -RelativeUrl $url -ReadOnly:($Operation -ne 'CREATE_NEW')
}
