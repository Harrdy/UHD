function Get-UHDGroup {
    <#
    .SYNOPSIS
        Gruppensuche ist noch nicht implementiert.
    .DESCRIPTION
        Die Operationen zur Gruppenzuordnung sind bekannt, ihre Eingabefelder
        und Antwortformate jedoch nicht vollständig belegt.
    #>
    [CmdletBinding()]
    param()

    throw [System.NotSupportedException]::new('Gruppensuche noch nicht implementiert: Parameter und Antwortformate der Zuordnungsabfragen sind offen.')
}
