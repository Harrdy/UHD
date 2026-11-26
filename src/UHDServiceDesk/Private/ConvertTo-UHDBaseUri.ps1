function ConvertTo-UHDBaseUri {
    [CmdletBinding()]
    [OutputType([uri])]
    param(
        [AllowEmptyString()]
        [string]$BaseUrl
    )

    $uri = $null
    if (-not [uri]::TryCreate($BaseUrl, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or
        $uri.AbsolutePath -notmatch '/CAisd/?\z') {
        throw 'BaseUrl muss eine HTTPS-Basis-URL bis /CAisd/ ohne Benutzerdaten, Query oder Fragment sein.'
    }
    [uri]($uri.AbsoluteUri.TrimEnd('/') + '/')
}
