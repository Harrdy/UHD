function Get-UHDUser {
    <#
    .SYNOPSIS
        Benutzersuche ist noch nicht implementiert.
    .DESCRIPTION
        Nur der Kontaktabruf nach interner ID ist belegt. Suchparameter und
        Antwortlayout reichen für eine öffentliche Benutzersuche nicht aus.
    #>
    [CmdletBinding()]
    param()

    throw [System.NotSupportedException]::new('Benutzersuche noch nicht implementiert: Nur der Kontaktabruf nach ID ist belegt; das Antwortformat ist offen.')
}
