function ConvertFrom-UHDEmptyList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory)]
        [ValidateSet('attmnt', 'in')]
        [string]$Factory
    )

    $template = if ($Factory -eq 'attmnt') { 'list_attmnt_sd.htmpl' } else { 'list_in.htmpl' }
    $listName = if ($Factory -eq 'attmnt') { 'Anhangliste' } else { 'Unterticketliste' }
    $unsupported = "Das Antwortformat der ${listName} ist noch offen; nur eindeutig leere Listen werden unterstützt."
    if ($Content.Length -gt 1MB) { throw $unsupported }

    # Nur tatsächlichen Skripttext prüfen. Zeichenketten und Kommentare
    # werden als ganze Tokens übersprungen, damit sie keine Zähler vortäuschen.
    $markup = Get-UHDSearchMarkup -Content $Content
    $tokens = @'
(?x)
    "(?:\\[\s\S]|[^"\\])*" | '(?:\\[\s\S]|[^'\\])*' | `(?:\\[\s\S]|[^`\\])*`
    | (?://|<!--)[^\r\n]* | /\*[\s\S]*?(?:\*/|\z)
    | (?<![\w$.])(?:var[ \t]+(?<key>propFactory|propFormName)|(?:var[ \t]+)?(?<key>cfgTotal|cfgRecordCount))
      [ \t]*=(?!=|>)[ \t]*(?:(?<quote>["'])(?<value>[A-Za-z0-9_.]+)\k<quote>[ \t]*;)?
'@
    $gap = '(?:(?>\s+)|/\*[\s\S]*?\*/|//[^\r\n]*)*'
    $tokens += '|(?<![\w$.])rs' + $gap + '\.' + $gap + '(?<method>startList|drawGrid|addRow)' + $gap + '\('
    $fields = @{}
    $hasStart = $false
    $hasDraw = $false

    foreach ($script in $markup.Scripts) {
        if (-not $script.IsClosed) { throw $unsupported }
        foreach ($token in [regex]::Matches($script.Text, $tokens)) {
            if ($token.Groups['key'].Success) {
                $key = $token.Groups['key'].Value
                if (-not $token.Groups['value'].Success -or $fields.ContainsKey($key)) { throw $unsupported }
                $fields[$key] = $token.Groups['value'].Value
            }
            switch -CaseSensitive ($token.Groups['method'].Value) {
                'startList' { $hasStart = $true }
                'drawGrid' { $hasDraw = $true }
                'addRow' { throw $unsupported }
            }
        }
    }

    if ($fields['propFactory'] -cne $Factory.ToLowerInvariant() -or
        $fields['propFormName'] -cne $template -or
        $fields['cfgTotal'] -cne '0' -or $fields['cfgRecordCount'] -cne '0' -or
        -not $hasStart -or -not $hasDraw) {
        throw $unsupported
    }
}
