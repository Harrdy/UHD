function ConvertFrom-UHDCapturedSearch {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content,

        [pscustomobject]$Markup = (Get-UHDSearchMarkup -Content $Content),

        [ValidatePattern('\A[0-9]{1,30}\z')]
        [string]$ActivityTicketId
    )

    $unsupported = 'Antwortformat der UHD-Ticketsuche nicht erkannt; es wurden keine Treffer ausgegeben.'
    $fields = [ordered]@{
        RefNum = 'ref_num'; Status = 'status'; Summary = 'summary'; Description = 'description'
        Assignee = 'assignee'; Group = 'group'; Category = 'category'; Priority = 'priority'
        Urgency = 'urgency'; Impact = 'impact'; Customer = 'customer.combo_name'; Parent = 'parent'
    }
    $activity = [bool]$ActivityTicketId
    $allowed = if ($activity) { 'persid', 'call_req_id', 'analyst', 'time_stamp', 'type', 'description' }
    else { @($fields.Values) + 'persid', 'group.id', 'last_mod_dt' }
    $literal = '"(?:\\[^\r\n]|[^"\\\r\n])*"|''(?:\\[^\r\n]|[^''\\\r\n])*'''
    $jsTokens = '(?:' + $literal + ')|`(?:\\[\s\S]|[^`\\])*`|(?://|<!--)[^\r\n]*|/\*[\s\S]*?(?:\*/|\z)'
    $eventsPattern = '(?<![\w$.])(?:' +
        '(?<open>recordData)\s*=(?!=|>)|' +
        '(?<field>recordData)\s*(?:\[[^\]\r\n]*\]|\.\s*[\w$]+)\s*=(?!=|>)|' +
        '(?<close>rs\s*\.\s*addRow)\s*\(\s*recordData(?=\W)|' +
        '(?<helper>rs\s*\.\s*data|writeIcon|colorPrios|showUser|fmtType|UnEscapeDesc)\s*\()'

    if ($activity) {
        $eventsPattern += '|(?<![\w$.])(?<context>(?:var[ \t]+)?(?:listcall_req_id|listtypecode|analyst_persid))[ \t]*=(?!=|>)'
    }
    $activityContext = [regex]'\G(?:var[ \t]+)?(?<key>listcall_req_id|listtypecode|analyst_persid)[ \t]*=[ \t]*"(?<value>[A-Za-z0-9_:]+)";'
    $literalGroup = '(?<value>(?:' + $literal + '))'
    $recordPattern = [regex]'(?m)\GrecordData[ \t]*=[ \t]*new[ \t]+Object\(\);'
    $fieldPattern = [regex]('(?m)\GrecordData[ \t]*\[[ \t]*"(?<key>[A-Za-z0-9._-]+)"[ \t]*\][ \t]*=[ \t]*' +
        '(?<right>(?:' + $literal + ')|celldatatowrite|-?[0-9]+);[ \t]*(?=\r?$|//)')
    $endPattern = [regex]'\Grs\.addRow\(recordData\["rownum"\],[ \t]*recordData,[ \t]*styleData,[ \t]*imageData\);'
    $epochLiteral = '(?<epochQuote>["''])(?<epoch>[0-9]{1,10})\k<epochQuote>'
    $parseHelper = [regex]('\G(?:rs\.data\(date_to_string\(' + $epochLiteral + '\)\)' +
        '|rs\.data\([ \t]*' + $literalGroup +
        '[ \t]*\)|writeIcon\([ \t]*' + $literalGroup + '[ \t]*,[ \t]*ref_num_style[ \t]*\)' +
        '|colorPrios\([ \t]*' + $literalGroup + '[ \t]*\)' +
        '|(?<activityHelper>showUser|fmtType|UnEscapeDesc)\([ \t]*' + $literalGroup + '[ \t]*\));')
    $directPattern = [regex]('\A' + $literalGroup + '\z')
    $escapes = @{ '"' = '"'; "'" = "'"; '\' = '\'; '/' = '/'; 'n' = "`n"; 'r' = "`r"; 't' = "`t"; 'b' = "`b"; 'f' = "`f" }

    $results = [System.Collections.Generic.List[pscustomobject]]::new()
    $ids = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($scriptBlock in $Markup.Scripts) {
        $scriptText = $scriptBlock.Text
        # Zeichenketten und Kommentare positionsgetreu ausblenden. Es wird
        # nie JavaScript ausgeführt; Literale werden unten separat gelesen.
        $code = [regex]::Replace($scriptText, $jsTokens, {
            param($token)
            [regex]::Replace($token.Value, '[^\r\n]', ' ')
        })
        $row = $null
        $descriptions = 0
        $lastHelper = $null
        foreach ($statement in [regex]::Matches($code, $eventsPattern)) {
            if ($statement.Groups['helper'].Success) {
                $lastHelper = $statement
                continue
            }
            if (-not $scriptBlock.IsClosed) { throw $unsupported }
            $at = $statement.Index
            $lineStart = $scriptText.LastIndexOf("`n", $at) + 1
            if (-not [string]::IsNullOrWhiteSpace($scriptText.Substring($lineStart, $at - $lineStart))) { throw $unsupported }
            if ($statement.Groups['open'].Success) {
                if ($null -ne $row -or -not $recordPattern.Match($scriptText, $at).Success) { throw $unsupported }
                $row = @{}
                $descriptions = 0
                $lastHelper = $null
                continue
            }
            if ($null -eq $row) { throw $unsupported }
            if ($statement.Groups['close'].Success) {
                if (-not $endPattern.Match($scriptText, $at).Success) { throw $unsupported }
                if ($activity) {
                    if ($row['persid'] -cnotmatch '\Aalg:[0-9]{1,30}\z' -or
                        $row['listcall_req_id'] -cne "cr:${ActivityTicketId}" -or $row['call_req_id'] -cnotmatch '\A[0-9]{1,30}\z' -or
                        $row['listtypecode'] -cnotmatch '\A[A-Z][A-Z0-9_]{0,31}\z' -or
                        $row['analyst_persid'] -cnotmatch '\Acnt:[0-9a-fA-F]{32}\z' -or -not $row.ContainsKey('analyst') -or
                        -not $row.ContainsKey('time_stamp') -or [string]::IsNullOrWhiteSpace($row['type']) -or
                        $descriptions -ne 2) { throw $unsupported }
                    $id = $row['persid'].Substring(4)
                    if (-not $ids.Add($id)) { throw $unsupported }
                    $results.Add([pscustomobject]@{
                        Id          = $id
                        TicketId    = $ActivityTicketId
                        RefNum      = $row['call_req_id']
                        Analyst     = $row['analyst']
                        AnalystId   = $row['analyst_persid'].Substring(4)
                        Timestamp   = [DateTimeOffset]::FromUnixTimeSeconds([long]$row['time_stamp'])
                        Type        = $row['type']
                        TypeCode    = $row['listtypecode']
                        Description = $row['description']
                    })
                    $row = $null
                    continue
                }
                if ([string]::IsNullOrWhiteSpace($row['ref_num']) -or -not $row.ContainsKey('summary') -or
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
            if ($activity -and $statement.Groups['context'].Success) {
                $assignment = $activityContext.Match($scriptText, $at)
                if (-not $assignment.Success) { throw $unsupported }
                $contextKey = $assignment.Groups['key'].Value
                if ($row.ContainsKey($contextKey)) { throw $unsupported }
                $row[$contextKey] = $assignment.Groups['value'].Value
                $lastHelper = $null
                continue
            }
            $assignment = $fieldPattern.Match($scriptText, $at)
            if (-not $assignment.Success) { throw $unsupported }
            $key = $assignment.Groups['key'].Value
            if ($key -cnotin $allowed) { $lastHelper = $null; continue }
            $right = $assignment.Groups['right'].Value
            $isDate = $key -cin 'last_mod_dt', 'time_stamp'
            $expectedHelper = if ($activity) {
                switch -CaseSensitive ($key) {
                    'analyst'     { 'showUser' }
                    'type'        { 'fmtType' }
                    'description' { 'UnEscapeDesc' }
                }
            }
            if ($right -ceq 'celldatatowrite') {
                if ($null -eq $lastHelper) { throw $unsupported }
                $helper = $parseHelper.Match($scriptText, $lastHelper.Index)
                $helperEnd = $helper.Index + $helper.Length
                if (-not $helper.Success -or $helperEnd -gt $at -or
                    -not [string]::IsNullOrWhiteSpace($code.Substring($helperEnd, $at - $helperEnd))) { throw $unsupported }
                $activityHelper = $helper.Groups['activityHelper']
                if ($helper.Groups['epoch'].Success -ne $isDate -or
                    ($expectedHelper -and $activityHelper.Value -cne $expectedHelper) -or
                    (-not $expectedHelper -and $activityHelper.Success)) { throw $unsupported }
                $value = if ($isDate) { $helper.Groups['epoch'].Value } else { $helper.Groups['value'].Value }
            }
            else {
                $direct = $directPattern.Match($right)
                if ($isDate -or $expectedHelper -or -not $direct.Success) { throw $unsupported }
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
            if ($activity -and $key -ceq 'description') {
                $descriptions++
                if ($descriptions -gt 2) { throw $unsupported }
                # Die zweite Zuweisung ersetzt die erste in der Browserliste.
                $row[$key] = [uri]::UnescapeDataString($value).Replace('%27', "'")
                continue
            }
            if ($row.ContainsKey($key) -and $row[$key] -cne $value) { throw $unsupported }
            $row[$key] = $value
        }
        if ($null -ne $row) { throw $unsupported }
    }
    if ($results.Count -eq 0) { throw $unsupported }
    foreach ($result in $results) { $result }
}
