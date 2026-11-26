function Get-UHDPriority {
    <#
    .SYNOPSIS
        Prioritätsliste ist noch nicht implementiert.
    .DESCRIPTION
        Die bestätigte Operation zur Prioritätsberechnung liefert keinen belegten
        Prioritätskatalog.
    #>
    [CmdletBinding()]
    param()

    throw [System.NotSupportedException]::new('Prioritätsliste noch nicht implementiert: Nur die Route zur Prioritätsberechnung ist belegt.')
}
