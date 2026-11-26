function Get-UHDAuxiliaryQuery {
    <#
    .SYNOPSIS
        Liefert ausschließlich in docs/endpoints.md belegte Abfrageparameter.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('CREATE_NEW', 'UPDATE', 'VALID_TRANSITIONS', 'GET_REQUIRED_FIELDS', 'SPEC_HAND', 'GET_SVC_CONTRACT', 'GET_PRI_CAL', 'GROUP_IN_AGT', 'AGT_IN_GROUP')]
        [string]$Operation,

        [ValidatePattern('\A[A-Za-z0-9_-]{1,128}\z')]
        [string]$Id,

        [ValidatePattern('\A[A-Z][A-Z0-9]{0,31}\z')]
        [string]$Status,

        [ValidatePattern('\A[0-9A-Fa-f]{32}\z')]
        [string]$TenantId
    )

    if ($Operation -in 'UPDATE', 'VALID_TRANSITIONS') {
        if ($Id -notmatch '\A[0-9]{1,30}\z') { throw 'Eine numerische interne Ticket-ID ist erforderlich.' }
    }
    if ($Operation -in 'SPEC_HAND', 'GET_SVC_CONTRACT' -and -not $Id) {
        throw 'Eine interne Kontakt-ID ist erforderlich.'
    }
    if ($Operation -in 'VALID_TRANSITIONS', 'GET_REQUIRED_FIELDS' -and -not $Status) {
        throw 'Ein Kurzcode für den Status ist erforderlich.'
    }

    if ($TenantId -and $Operation -ne 'VALID_TRANSITIONS') {
        throw 'Eine Mandantenkennung ist bei diesem Aufruf nur für Statusübergänge belegt.'
    }

    switch ($Operation.ToUpperInvariant()) {
        'CREATE_NEW'          { [ordered]@{ OP = 'CREATE_NEW'; FACTORY = 'cr'; PRESET = 'type:I' } }
        'UPDATE'              { [ordered]@{ OP = 'UPDATE'; FACTORY = 'cr'; 'SET.id' = $Id } }
        'VALID_TRANSITIONS' {
            $query = [ordered]@{ OP = 'VALID_TRANSITIONS'; FACTORY = 'cr'; STATUS_FACTORY = 'crs'; STATUS = $Status; PERSID = "cr:${Id}" }
            if ($TenantId) { $query.TENANT = $TenantId }
            $query.TYPE = 'I'
            $query
        }
        'GET_REQUIRED_FIELDS' { [ordered]@{ OP = 'GET_REQUIRED_FIELDS'; FACTORY = 'cr'; status = $Status } }
        'SPEC_HAND'           { [ordered]@{ OP = 'SPEC_HAND'; FACTORY = 'cnt'; PERSID = "cnt:${Id}" } }
        'GET_SVC_CONTRACT'    { [ordered]@{ OP = 'GET_SVC_CONTRACT'; new_customer = "cnt:${Id}" } }
        'GET_PRI_CAL'         { [ordered]@{ OP = 'GET_PRI_CAL'; FACTORY = 'in' } }

        # Für die beiden Gruppenzuordnungen ist bislang nur OP belegt.
        'GROUP_IN_AGT'        { [ordered]@{ OP = 'GROUP_IN_AGT' } }
        'AGT_IN_GROUP'        { [ordered]@{ OP = 'AGT_IN_GROUP' } }
    }
}
