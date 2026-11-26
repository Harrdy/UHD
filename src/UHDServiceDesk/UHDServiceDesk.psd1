@{
    RootModule        = 'UHDServiceDesk.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'd91e36eb-f5ab-46c3-a02d-96851d03638f'
    Author            = 'UHDServiceDesk contributors'
    Description       = 'PowerShell 7 Schnittstelle für das Ticketsystem UHD Service Desk (Proof of Concept).'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Connect-UHD', 'Disconnect-UHD',
        'Get-UHDTicket', 'Find-UHDTicket', 'New-UHDTicket', 'Set-UHDTicket',
        'Add-UHDTicketComment', 'Close-UHDTicket',
        'Get-UHDUser', 'Get-UHDGroup', 'Get-UHDCategory', 'Get-UHDStatus', 'Get-UHDPriority',
        'Add-UHDTicketAttachment', 'Get-UHDTicketAttachment'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
