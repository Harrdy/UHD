function ConvertTo-UHDMaskedUrl {
    <#
    .SYNOPSIS
        Maskiert SID und FID in einer URL, bevor sie geloggt wird.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Url
    )

    $Url -replace 'SID=\d+', 'SID=***' -replace 'PIN=[^&+]*', 'PIN=***'
}
