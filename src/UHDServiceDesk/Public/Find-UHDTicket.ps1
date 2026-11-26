function Find-UHDTicket {
    <#
    .SYNOPSIS
        Sucht die erste Seite aktiver Incidents mit einem belegten Filter.
    .DESCRIPTION
        Unterstützt die Suche über eine Gruppenmitgliedschaft oder die Suche
        ohne Gruppenfilter. Es gibt keinen Freitextfilter und keine Pagination.
    .PARAMETER GroupMemberId
        Interne Mitgliedskennung mit 32 Hex-Zeichen ohne Bindestriche.
        Keine Gruppen-ID. Schließt die Status EXTERL und EXTABG aus.
    .PARAMETER AllActiveIncidents
        Liefert die erste Seite aktiver, nicht als Vorlage gespeicherter
        Incidents ohne Gruppenfilter. Lädt keine Folgeseiten.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Member')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Member')]
        [ValidatePattern('\A[0-9A-Fa-f]{32}\z')]
        [string]$GroupMemberId,

        [Parameter(Mandatory, ParameterSetName = 'ActiveIncidents')]
        [switch]$AllActiveIncidents
    )

    $condition = if ($PSCmdlet.ParameterSetName -eq 'Member') {
        "(status <> 'EXTERL' AND status <> 'EXTABG') and active=1 AND type = 'I' AND group.[group]group_list.member IN (U'$GroupMemberId')"
    }
    else {
        if (-not $AllActiveIncidents) { throw 'Die Suche ohne Gruppenfilter muss ausdrücklich ausgewählt werden.' }
        "active=1 AND type = 'I' AND template_name is NULL"
    }

    $session = Get-UHDSession
    $url = ConvertTo-UHDOperationUrl -Session $session -Query ([ordered]@{
        OP = 'SEARCH'
        FACTORY = 'cr'
        'KEEP.where_clause' = $condition
    })
    $response = Invoke-UHDRequest -Session $session -Method GET -RelativeUrl $url -ReadOnly
    $content = [string]$response.Content
    if ($VerbosePreference -ne 'SilentlyContinue') {
        # Keine Antwortdaten oder Werte aus der Query protokollieren.
        Write-Verbose ('UHD-Suchantwort: HTTP={0}; Zeichen={1}; HTML={2}; Skript={3}; recordData={4}; addRow={5}' -f
            [int]$response.StatusCode, $content.Length,
            ($content -match '<html(?=[\s>])'), ($content -match '<script(?=[\s>])'),
            ($content -cmatch '\brecordData\b'), ($content -cmatch '\brs\s*\.\s*addRow\s*\('))
    }
    ConvertFrom-UHDCapturedSearch -Content $content
}
