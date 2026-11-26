function ConvertFrom-UHDNativeDetailScript {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [pscustomobject[]]$Scripts
    )

    $unsupported = 'Antwortformat für UHD-Tickets nicht erkannt; das Ergebnis konnte nicht ausgewertet werden.'
    $literal = '"(?:\\[^\r\n]|[^"\\\r\n])*"|''(?:\\[^\r\n]|[^''\\\r\n])*'''
    $mask = '(?:' + $literal + ')|`(?:\\[\s\S]|[^`\\])*`|(?://|<!--)[^\r\n]*|/\*[\s\S]*?(?:\*/|\z)'
    $tokens = '(?m)^[ \t]*(?<key>var\s+argRefNum|var\s+argPersistentID|detailDateReadonly|detailDropdown)(?=\s*[=(])'
    $identityPattern = [regex]'\G[ \t]*var\s+(?<field>argRefNum|argPersistentID)[ \t]*=[ \t]*"(?<value>(?:cr:)?[0-9]{1,30})"[ \t]*;'
    $datePattern = [regex]('\G[ \t]*detailDateReadonly\(\s*(?:' + $literal + '),\s*"(?<field>open_date|last_mod_dt|resolve_date|close_date)",\s*[0-9]+,\s*(?:' +
        $literal + '),\s*"(?<value>[0-9]{0,10})",\s*""\s*\)\s*;')
    $statusPattern = [regex]('\G[ \t]*detailDropdown\(\s*(?:' + $literal + ')\s*,\s*"status"\s*,\s*(?:' + $literal +
        '),\s*[0-9]+,\s*[0-9]+,\s*(?:' + $literal + '|[0-9]+|true|false)\s*,\s*"(?<value>crs:[0-9]{1,30})"\s*,')
    $statusStart = [regex]('\G[ \t]*detailDropdown\(\s*(?:' + $literal + ')\s*,\s*"status"\s*,')
    $dateStart = [regex]('\G[ \t]*detailDateReadonly\(\s*(?:' + $literal + '),\s*"(?:open_date|last_mod_dt|resolve_date|close_date)"\s*,')
    $result = @{}
    foreach ($scriptBlock in $Scripts) {
        $source = $scriptBlock.Text
        $code = [regex]::Replace($source, $mask, { param($m) [regex]::Replace($m.Value, '[^\r\n]', ' ') })
        foreach ($item in [regex]::Matches($code, $tokens)) {
            $kind = $item.Groups['key'].Value
            if ($kind -match '^var') {
                $parsed = $identityPattern.Match($source, $item.Index)
                $name = $parsed.Groups['field'].Value
            }
            elseif ($kind -ceq 'detailDateReadonly') {
                if (-not $dateStart.Match($source, $item.Index).Success) { continue }
                $parsed = $datePattern.Match($source, $item.Index)
                $name = $parsed.Groups['field'].Value
            }
            else {
                if (-not $statusStart.Match($source, $item.Index).Success) { continue }
                $parsed = $statusPattern.Match($source, $item.Index)
                $name = 'status'
            }
            if (-not $scriptBlock.IsClosed -or -not $parsed.Success -or $result.ContainsKey($name)) { throw $unsupported }
            $result[$name] = $parsed.Groups['value'].Value
        }
    }
    $result
}
