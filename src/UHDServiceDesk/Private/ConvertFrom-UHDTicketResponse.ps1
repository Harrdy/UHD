function ConvertFrom-UHDTicketResponse {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyString()]
        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [ValidateSet('Search', 'Detail')]
        [string]$Layout
    )

    # Nur benannte Ticketfelder übernehmen, niemals beliebige Skriptobjekte ausgeben.
    $fields = [ordered]@{
        RefNum = 'ref_num'; Status = 'status'; Summary = 'summary'
        Description = 'description'; Assignee = 'assignee'; Group = 'group'
        Category = 'category'; Priority = 'priority'; Urgency = 'urgency'
        Impact = 'impact'; Customer = 'customer'; Parent = 'parent'
    }
    $unsupported = 'Antwortformat für UHD-Tickets nicht erkannt; das Ergebnis konnte nicht ausgewertet werden.'
    # Erst HTML-Elemente im Zusammenhang lesen. Sequenzen in Attributwerten
    # und Textareas sind Nutzdaten, keine Kommentare oder Skriptblöcke.
    $attributes = '(?<attrs>(?:[^>"'']|"[^"]*"|''[^'']*'')*)'
    $boundary = '(?=[\s/>])'
    $htmlPattern = '(?is)<!--.*?(?:-->|\z)' +
        '|<script' + $boundary + $attributes + '>(?<script>.*?)(?<scriptEnd></script\s*>|\z)' +
        '|<(?<raw>style|title)' + $boundary + $attributes + '>.*?(?:</\k<raw>\s*>|\z)' +
        '|<(?<tag>textarea)' + $boundary + $attributes + '>(?<body>.*?)(?<bodyEnd></textarea\s*>|\z)' +
        '|<(?<tag>input)' + $boundary + $attributes + '>' +
        '|</?[a-z][a-z0-9:_-]*' + $boundary + $attributes + '>'
    $elements = [regex]::Matches($Content, $htmlPattern)
    if ($Layout -eq 'Search') {
        # Nur eigenständige recordData-Zuweisungen mit JSON-kompatiblen Daten
        # in Skriptblöcken lesen. Kein JavaScript auswerten oder umschreiben.
        $literals = @(
            foreach ($element in $elements) {
                if (-not $element.Groups['scriptEnd'].Length) { continue }
                $scriptText = $element.Groups['script'].Value
                $tokenPattern = '"(?:\\.|[^"\\])*"|''(?:\\.|[^''\\])*''|`(?:\\.|[^`\\])*`|(?://|<!--)[^\r\n]*|/\*[\s\S]*?(?:\*/|\z)'
                # Kommentare und Zeichenketten positionsgleich maskieren.
                # So bleiben echte Zuweisungen auch hinter anderem Code sichtbar.
                $code = [regex]::Replace($scriptText, $tokenPattern, {
                    param($token)
                    ' ' * $token.Length
                })
                $startPattern = '(?<member>\.\s*)?(?<![\p{L}\p{M}\p{N}\p{Pc}\p{Cf}$])(?<name>recordData)\s*=(?!=|>)'
                $literalPattern = [regex]'(?m)\G[\t ]*(?:(?:var|let|const)[\t ]+)?(?<name>recordData)[\t ]*=[\t ]*(?<data>[^\r\n]*?)[\t ]*;[\t ]*\r?$'
                foreach ($start in [regex]::Matches($code, $startPattern)) {
                    if ($start.Groups['member'].Success) { continue }
                    $offset = $start.Groups['name'].Index
                    $lineStart = $scriptText.LastIndexOf("`n", $offset) + 1
                    $candidate = $literalPattern.Match($scriptText, $lineStart)
                    if (-not $candidate.Success -or $candidate.Groups['name'].Index -ne $offset) { throw $unsupported }
                    $candidate.Groups['data'].Value
                }
            }
        )
        if ($literals.Count -eq 0) { throw $unsupported }
        # Parserfehler des Cmdlets dürfen keine Antwortdaten in -ErrorVariable
        # des Aufrufers schreiben. Alle Literale zusammen isoliert auswerten.
        $parser = [powershell]::Create()
        try {
            $null = $parser.AddScript({
                param([string[]]$Literals)

                try {
                    foreach ($literal in $Literals) {
                        $record = ConvertFrom-Json -InputObject $literal -AsHashtable -ErrorAction Stop
                        if ($record -isnot [System.Collections.IDictionary]) { return }
                        $record
                    }
                }
                catch {
                    return
                }
            }.ToString()).AddArgument($literals)
            $records = @($parser.Invoke())
        }
        finally {
            $parser.Dispose()
        }
        if ($records.Count -ne $literals.Count) { throw $unsupported }
    }
    else {
        # Nur explizit benannte, zitierte Formularfelder des Details lesen.
        $record = @{}
        $attributePattern = '(?i)(?:\A|\s)(?<key>[\w:-]+)\s*=\s*(?:"(?<value>[^"]*)"|''(?<value>[^'']*)'')'
        foreach ($control in $elements) {
            $tag = $control.Groups['tag'].Value
            if (-not $tag) { continue }
            $attrs = @{}
            foreach ($attribute in [regex]::Matches($control.Groups['attrs'].Value, $attributePattern)) {
                $attrs[$attribute.Groups['key'].Value] = $attribute.Groups['value'].Value
            }
            $name = $attrs['name']
            if ($name -notin $fields.Values) { continue }
            if ($record.ContainsKey($name)) { throw $unsupported }
            if ($tag -ieq 'textarea') {
                if (-not $control.Groups['bodyEnd'].Length) { throw $unsupported }
                $value = $control.Groups['body'].Value
            }
            elseif ($attrs.ContainsKey('value')) {
                $value = $attrs['value']
            }
            else { continue }
            $record[$name] = [System.Net.WebUtility]::HtmlDecode($value)
        }
        $records = @($record)
    }

    # Vollständig prüfen, bevor ein unvollständiges Seitenergebnis ausgegeben wird.
    $results = @(
        foreach ($record in $records) {
            if ($record['ref_num'] -isnot [string] -or [string]::IsNullOrWhiteSpace($record['ref_num']) -or
                $record['summary'] -isnot [string]) { throw $unsupported }
            $ticket = [ordered]@{}
            foreach ($property in $fields.Keys) {
                $value = $record[$fields[$property]]
                if ($null -ne $value -and $value -isnot [string] -and $value -isnot [ValueType]) { throw $unsupported }
                $ticket[$property] = $value
            }
            [pscustomobject]$ticket
        }
    )
    foreach ($result in $results) { [pscustomobject]$result }
}
