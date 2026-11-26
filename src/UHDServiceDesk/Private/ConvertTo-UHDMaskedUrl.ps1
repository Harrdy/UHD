function ConvertTo-UHDMaskedUrl {
    <#
    .SYNOPSIS
        Entfernt Query, Fragment und Benutzerinformationen vor der Protokollierung.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Url
    )

    $uri = $null
    if (-not [uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
        return '[URL maskiert]'
    }
    $masked = '{0}://{1}{2}' -f $uri.Scheme, $uri.Authority, $uri.AbsolutePath
    if ($uri.Query) { $masked += '?***' }
    $masked
}
