function Get-UHDStatus {
    <#
    .SYNOPSIS
        Liest einen belegten Statusübergang für ein vorhandenes Ticket ab.
    .DESCRIPTION
        Unterstützt Antworten, die genau aus einem CODE@Bezeichnung-Eintrag
        bestehen. Die Bezeichnung ist URL-kodiert. Das äußere Format für mehrere
        Einträge oder eine leere Liste ist nicht belegt. Andere Antworten werden
        deshalb nicht als gültige Übergangsliste interpretiert.
    .PARAMETER Id
        Numerische interne Ticket-ID, nicht die sichtbare Ticketnummer.
    .PARAMETER Status
        Aktueller Status als Kurzcode, zum Beispiel WIP.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('\A[0-9]{1,30}\z')]
        [string]$Id,

        [Parameter(Mandatory)]
        [ValidatePattern('\A[A-Z][A-Z0-9]{0,31}\z')]
        [string]$Status
    )

    $response = Invoke-UHDAuxiliaryRequest -Operation VALID_TRANSITIONS -Id $Id -Status $Status
    $entry = ([string]$response.Content).Trim()
    $match = [regex]::Match($entry, '\A(?<code>[A-Z][A-Z0-9]{0,31})@(?<label>(?:[A-Za-z0-9._~-]|%[0-9A-Fa-f]{2})+)\z')
    if ($match.Success) {
        $label = [uri]::UnescapeDataString($match.Groups['label'].Value)
        if (-not [string]::IsNullOrWhiteSpace($label) -and $label -notmatch '[\p{C}]|%[0-9A-Fa-f]{2}') {
            return [pscustomobject]@{ Code = $match.Groups['code'].Value; Label = $label }
        }
    }
    throw 'Das Antwortformat der Statusübergänge ist noch offen; erwartet wird genau ein belegter CODE@Bezeichnung-Eintrag.'
}
