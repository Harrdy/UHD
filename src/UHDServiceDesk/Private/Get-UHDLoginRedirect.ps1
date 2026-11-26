function Get-UHDLoginRedirect {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory)]
        [uri]$BaseUri
    )

    # Es wird nur der belegte, in Anführungszeichen stehende Zielpfad übernommen;
    # kein JavaScript wird ausgeführt.
    $pattern = @'
["'](?<target>[^"'<>\s]*pdmweb[23]?\.exe\?SID=[0-9]+\+FID=[0-9]+\+OP=REPLACE_LOGIN\+HTMPL=post_menu\.htmpl)["']
'@
    # Ein nur in einem HTML-Kommentar genanntes Ziel löst keine Weiterleitung aus.
    $visibleContent = [regex]::Replace($Content, '<!--.*?(?:--!?>|\z)', ' ', 'Singleline')
    $matchesFound = [regex]::Matches($visibleContent, $pattern, 'IgnoreCase')
    if ($matchesFound.Count -ne 1) { return }

    $match = $matchesFound[0]
    $target = $null
    if (-not [uri]::TryCreate($BaseUri, $match.Groups['target'].Value, [ref]$target) -or
        $target.Scheme -ne $BaseUri.Scheme -or $target.Authority -ne $BaseUri.Authority -or
        $target.UserInfo) {
        throw 'Unerwarteter Zielpfad für die UHD-Sitzungsweiterleitung.'
    }
    $servlet = $target.Segments[-1]
    if ($target.AbsolutePath -cne "$($BaseUri.AbsolutePath)$servlet" -or
        $servlet -notmatch '\Apdmweb[23]?\.exe\z') {
        throw 'Unerwarteter Zielpfad für die UHD-Sitzungsweiterleitung.'
    }

    [pscustomobject]@{
        Servlet     = $servlet
        RelativeUrl = $servlet + $target.Query
    }
}
