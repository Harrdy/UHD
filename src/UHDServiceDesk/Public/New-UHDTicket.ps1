function New-UHDTicket {
    <#
    .SYNOPSIS
        Legt in dieser Version kein Ticket an.
    .DESCRIPTION
        Die vollständigen Felder des Anlegeformulars und die eindeutige
        Bestätigung nach dem Speichern sind nicht belegt. Es wird kein Request
        gesendet, auch kein Formularabruf.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess('UHD Service Desk', 'Ticket anlegen')) {
        throw [System.NotSupportedException]::new('Ticket kann nicht angelegt werden: Das vollständige Speicherformular und seine Verifikation sind noch nicht belegt. Kein Request gesendet.')
    }
}
