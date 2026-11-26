function ConvertFrom-UHDTicketResponse {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyString()]
        [Parameter(Mandatory)]
        [string]$Content
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
        '|<script' + $boundary + $attributes + '>.*?(?:</script\s*>|\z)' +
        '|<(?<raw>style|title)' + $boundary + $attributes + '>.*?(?:</\k<raw>\s*>|\z)' +
        '|<(?<tag>textarea)' + $boundary + $attributes + '>(?<body>.*?)(?<bodyEnd></textarea\s*>|\z)' +
        '|<(?<tag>input)' + $boundary + $attributes + '>' +
        '|</?[a-z][a-z0-9:_-]*' + $boundary + $attributes + '>'
    $elements = [regex]::Matches($Content, $htmlPattern)
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
    if ([string]::IsNullOrWhiteSpace($record['ref_num']) -or -not $record.ContainsKey('summary')) {
        throw $unsupported
    }
    $ticket = [ordered]@{}
    foreach ($property in $fields.Keys) {
        $ticket[$property] = $record[$fields[$property]]
    }
    [pscustomobject]$ticket
}
