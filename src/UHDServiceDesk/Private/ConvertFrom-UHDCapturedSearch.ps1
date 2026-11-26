function ConvertFrom-UHDCapturedSearch {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content
    )

    $unsupported = 'Antwortformat der UHD-Ticketsuche nicht erkannt; es wurden keine Treffer ausgegeben.'
    # Begrenzung für den Offline-PoC; die beobachteten Listenseiten bleiben deutlich darunter.
    if ($Content.Length -gt 1MB) { throw $unsupported }

    $fields = [ordered]@{
        RefNum = 'ref_num'; Status = 'status'; Summary = 'summary'; Description = 'description'
        Assignee = 'assignee'; Group = 'group'; Category = 'category'; Priority = 'priority'
        Urgency = 'urgency'; Impact = 'impact'; Customer = 'customer.combo_name'; Parent = 'parent'
    }
    $allowed = @($fields.Values) + 'persid', 'group.id', 'last_mod_dt'
    # Kontext beachten: HTML-Kommentare und Script-ähnliche Daten in Attributen
    # oder Textfeldern sind keine Skriptblöcke.
    $attributes = '(?>[^>"'']|"[^"]*"|''[^'']*'')*'
    $htmlPattern = '(?is)<!--.*?(?:-->|\z)' +
        '|<script(?=[\s/>])' + $attributes + '>(?<script>.*?)(?<end></script\s*>|\z)' +
        '|<(?<text>style|title|textarea)(?=[\s/>])' + $attributes + '>.*?(?:</\k<text>\s*>|\z)' +
        '|</?[a-z][a-z0-9:_-]*(?=[\s/>])' + $attributes + '>'

    $literal = '"(?:\\[^\r\n]|[^"\\\r\n])*"|''(?:\\[^\r\n]|[^''\\\r\n])*'''
    $jsTokens = '(?:' + $literal + ')|`(?:\\[\s\S]|[^`\\])*`|(?://|<!--)[^\r\n]*|/\*[\s\S]*?(?:\*/|\z)'
    $eventsPattern = '(?<![\w$.])(?:' +
        '(?<open>recordData)\s*=(?!=|>)|' +
        '(?<field>recordData)\s*(?:\[[^\]\r\n]*\]|\.\s*[\w$]+)\s*=(?!=|>)|' +
        '(?<close>rs\s*\.\s*addRow)\s*\(\s*recordData(?=\W)|' +
        '(?<helper>rs\s*\.\s*data|writeIcon|colorPrios)\s*\()'

    $literalGroup = '(?<value>(?:' + $literal + '))'
    $recordPattern = [regex]'(?m)\GrecordData[ \t]*=[ \t]*new[ \t]+Object\(\);'
    $fieldPattern = [regex]('(?m)\GrecordData[ \t]*\[[ \t]*"(?<key>[A-Za-z0-9._-]+)"[ \t]*\][ \t]*=[ \t]*' +
        '(?<right>(?:' + $literal + ')|celldatatowrite|-?[0-9]+);[ \t]*(?=\r?$|//)')
    $endPattern = [regex]'\Grs\.addRow\(recordData\["rownum"\],[ \t]*recordData,[ \t]*styleData,[ \t]*imageData\);'
    $epochLiteral = '(?<epochQuote>["''])(?<epoch>[0-9]{1,10})\k<epochQuote>'
    $parseHelper = [regex]('\G(?:rs\.data\(date_to_string\(' + $epochLiteral + '\)\)' +
        '|rs\.data\([ \t]*' + $literalGroup +
        '[ \t]*\)|writeIcon\([ \t]*' + $literalGroup + '[ \t]*,[ \t]*ref_num_style[ \t]*\)' +
        '|colorPrios\([ \t]*' + $literalGroup + '[ \t]*\));')
    $directPattern = [regex]('\A' + $literalGroup + '\z')
    $escapes = @{ '"' = '"'; "'" = "'"; '\' = '\'; '/' = '/'; 'n' = "`n"; 'r' = "`r"; 't' = "`t"; 'b' = "`b"; 'f' = "`f" }

    $results = [System.Collections.Generic.List[pscustomobject]]::new()
    $ids = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($element in [regex]::Matches($Content, $htmlPattern)) {
        if (-not $element.Groups['script'].Success) { continue }
        $scriptText = $element.Groups['script'].Value
        # Zeichenketten und Kommentare positionsgetreu ausblenden. Es wird
        # nie JavaScript ausgeführt; Literale werden unten separat gelesen.
        $code = [regex]::Replace($scriptText, $jsTokens, {
            param($token)
            [regex]::Replace($token.Value, '[^\r\n]', ' ')
        })
        $row = $null
        $lastHelper = $null
        foreach ($statement in [regex]::Matches($code, $eventsPattern)) {
            if ($statement.Groups['helper'].Success) {
                $lastHelper = $statement
                continue
            }
            if (-not $element.Groups['end'].Length) { throw $unsupported }
            $at = $statement.Index
            $lineStart = $scriptText.LastIndexOf("`n", $at) + 1
            if (-not [string]::IsNullOrWhiteSpace($scriptText.Substring($lineStart, $at - $lineStart))) { throw $unsupported }
            if ($statement.Groups['open'].Success) {
                if ($null -ne $row -or -not $recordPattern.Match($scriptText, $at).Success) { throw $unsupported }
                $row = @{}
                $lastHelper = $null
                continue
            }
            if ($null -eq $row) { throw $unsupported }
            if ($statement.Groups['close'].Success) {
                if (-not $endPattern.Match($scriptText, $at).Success -or
                    [string]::IsNullOrWhiteSpace($row['ref_num']) -or -not $row.ContainsKey('summary') -or
                    $row['persid'] -cnotmatch '\Acr:[0-9]{1,30}\z') { throw $unsupported }
                $id = $row['persid'].Substring(3)
                if (-not $ids.Add($id)) { throw $unsupported }
                $ticket = [ordered]@{ Id = $id }
                foreach ($property in $fields.Keys) { $ticket[$property] = $row[$fields[$property]] }
                $ticket['GroupId'] = $row['group.id']
                $ticket['LastModified'] = if ([long]$row['last_mod_dt'] -gt 0) {
                    [DateTimeOffset]::FromUnixTimeSeconds([long]$row['last_mod_dt'])
                }
                else { $null }
                $results.Add([pscustomobject]$ticket)
                $row = $null
                continue
            }
            $assignment = $fieldPattern.Match($scriptText, $at)
            if (-not $assignment.Success) { throw $unsupported }
            $key = $assignment.Groups['key'].Value
            if ($key -cnotin $allowed) { $lastHelper = $null; continue }
            $right = $assignment.Groups['right'].Value
            $isDate = $key -ceq 'last_mod_dt'
            if ($right -ceq 'celldatatowrite') {
                if ($null -eq $lastHelper) { throw $unsupported }
                $helper = $parseHelper.Match($scriptText, $lastHelper.Index)
                $helperEnd = $helper.Index + $helper.Length
                if (-not $helper.Success -or $helperEnd -gt $at -or
                    -not [string]::IsNullOrWhiteSpace($code.Substring($helperEnd, $at - $helperEnd))) { throw $unsupported }
                if ($helper.Groups['epoch'].Success -ne $isDate) { throw $unsupported }
                $value = if ($isDate) { $helper.Groups['epoch'].Value } else { $helper.Groups['value'].Value }
            }
            else {
                $direct = $directPattern.Match($right)
                if ($isDate -or -not $direct.Success) { throw $unsupported }
                $value = $direct.Groups['value'].Value
            }
            $lastHelper = $null
            if (-not $isDate) {
                $value = $value.Substring(1, $value.Length - 2)
                # Nur einfache JavaScript-String-Escapes lesen; kein Eval.
                if (-not [regex]::IsMatch($value, '\A(?:[^\\]|\\["''\\/nrtbf])*\z')) { throw $unsupported }
                $value = [regex]::Replace($value, '\\(.)', { param($escape) $escapes[$escape.Groups[1].Value] })
            }
            if ($key -ceq 'group.id' -and $value -and $value -notmatch '\A[0-9a-fA-F]{32}\z') { throw $unsupported }
            if ($row.ContainsKey($key) -and $row[$key] -cne $value) { throw $unsupported }
            $row[$key] = $value
        }
        if ($null -ne $row) { throw $unsupported }
    }
    if ($results.Count -eq 0) { throw $unsupported }
    foreach ($result in $results) { $result }
}
