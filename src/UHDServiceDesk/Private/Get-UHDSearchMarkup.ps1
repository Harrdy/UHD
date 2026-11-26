function Get-UHDSearchMarkup {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content
    )

    $unsupported = 'Antwortformat der UHD-Ticketsuche nicht erkannt; es wurden keine Treffer ausgegeben.'
    if ($Content.Length -gt 1MB) { throw $unsupported }

    # Kontextgrenzen der beiden beobachteten Formate; kein HTML- oder Skriptcode wird ausgeführt.
    $attributes = '(?>[^>"'']|"[^"]*"|''[^'']*'')*'
    $pattern = '(?is)(?<comment><!--.*?(?:--!?>|\z))' +
        '|<script(?=[\s/>])(?<scriptAttributes>' + $attributes + ')>(?<script>.*?)(?<scriptEnd></script\s*>|\z)' +
        '|<plaintext(?=[\s/>])' + $attributes + '>.*\z' +
        '|<(?<text>style|title|textarea|xmp|iframe|noembed|noframes|noscript)(?=[\s/>])' +
        $attributes + '>.*?(?:</\k<text>\s*>|\z)' +
        '|<(?<closing>/)?(?<tag>[a-z][a-z0-9:_-]*)(?=[\s/>])(?<attributes>' + $attributes + ')>'
    $attributePattern = '(?<name>[^\s=/<>"'']+)(?:\s*=\s*(?:"(?<value>[^"]*)"|''(?<value>[^'']*)''|(?<value>[^\s>]+)))?'
    $scripts = [System.Collections.Generic.List[pscustomobject]]::new()
    $tables = [System.Collections.Generic.List[string]]::new()
    $templateDepth = 0
    $tableDepth = 0
    $tableBodyStart = 0
    $tableCount = 0
    $tableComments = [System.Collections.Generic.List[System.Text.RegularExpressions.Match]]::new()

    foreach ($token in [regex]::Matches($Content, $pattern)) {
        if ($token.Groups['comment'].Success -and $tableDepth -gt 0 -and $templateDepth -eq 0) {
            $tableComments.Add($token)
        }
        $tag = $token.Groups['tag'].Value
        $closing = $token.Groups['closing'].Success
        if ($tag -eq 'template') {
            if (-not $closing) { $templateDepth++ }
            elseif ($templateDepth -gt 0) { $templateDepth-- }
            continue
        }
        if ($templateDepth -gt 0) { continue }
        if ($token.Groups['script'].Success) {
            $hasSource = $false
            # Ein Daten-Skript (z. B. eine HTML-Vorlage) besitzt keine belegte
            # JavaScript-Nutzlast. Nur der Standardtyp und das beobachtete MIME
            # werden als mögliche Quellen für die Antwortdaten berücksichtigt.
            $types = @(
                foreach ($attribute in [regex]::Matches($token.Groups['scriptAttributes'].Value, $attributePattern)) {
                    $name = $attribute.Groups['name'].Value
                    if ($name -ieq 'src') {
                        $hasSource = $true
                        break
                    }
                    if ($name -ieq 'type') {
                        [System.Net.WebUtility]::HtmlDecode($attribute.Groups['value'].Value).Trim()
                    }
                }
            )
            # Ein src-Attribut verdrängt den Inline-Inhalt. Externe Skripte
            # werden niemals geladen, auch nicht bei leerem src.
            if ($hasSource) { continue }
            if ($types.Count -gt 1) { throw $unsupported }
            if ($types.Count -eq 1 -and $types[0] -notin '', 'text/javascript') { continue }
            $scripts.Add([pscustomobject]@{
                Text = $token.Groups['script'].Value
                IsClosed = $token.Groups['scriptEnd'].Length -gt 0
            })
            continue
        }
        if ($tag -ne 'table') { continue }

        if ($closing) {
            if ($tableDepth -gt 0) {
                $tableDepth--
                if ($tableDepth -eq 0) {
                    $body = [System.Text.StringBuilder]::new($Content.Substring($tableBodyStart, $token.Index - $tableBodyStart))
                    for ($i = $tableComments.Count - 1; $i -ge 0; $i--) {
                        $comment = $tableComments[$i]
                        $null = $body.Remove($comment.Index - $tableBodyStart, $comment.Length)
                    }
                    $tables.Add($body.ToString())
                }
            }
            continue
        }

        $summary = @(
            foreach ($attribute in [regex]::Matches($token.Groups['attributes'].Value, $attributePattern)) {
                if ($attribute.Groups['name'].Value -ieq 'summary') { $attribute.Groups['value'].Value }
            }
        )
        $isRequestTable = 'Request-Liste' -iin $summary
        if ($isRequestTable) {
            $tableCount++
            if ($summary.Count -ne 1) { throw $unsupported }
        }

        if ($tableDepth -gt 0) {
            $tableDepth++
        }
        elseif ($isRequestTable) {
            $tableDepth = 1
            $tableBodyStart = $token.Index + $token.Length
            $tableComments.Clear()
        }
    }

    [pscustomobject]@{
        Scripts = $scripts.ToArray()
        RequestTables = $tables.ToArray()
        RequestTableCount = $tableCount
    }
}
