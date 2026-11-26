function Set-UHDTicket {
    <#
    .SYNOPSIS
        Ändert in dieser Version kein Ticket.
    .DESCRIPTION
        Die für ein vollständiges Update zu übernehmenden Formularfelder und
        das Sperrverhalten beim Öffnen sind nicht ausreichend belegt. Weder
        Bearbeitungsformular noch Speicherrequest werden aufgerufen.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess('UHD Service Desk', 'Ticket ändern')) {
        throw [System.NotSupportedException]::new('Ticket kann nicht geändert werden: Speicherformular und Sperrverhalten sind noch nicht belegt. Kein Request gesendet.')
    }
}
