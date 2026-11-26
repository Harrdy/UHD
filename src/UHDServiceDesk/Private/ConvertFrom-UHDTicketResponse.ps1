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
    if ($Content.Length -gt 1MB) { throw $unsupported }
    $native = ConvertFrom-UHDNativeDetailScript -Scripts (Get-UHDSearchMarkup -Content $Content).Scripts
    $nativeFields = @('SET.customer', 'SET.assignee', 'SET.group', 'SET.priority', 'SET.urgency', 'SET.impact',
        'SET.change', 'SET.affected_resource', 'SET.summary', 'SET.description',
        'customer_combo_name', 'assignee_combo_name', 'group_combo_name')
    # Erst HTML-Elemente im Zusammenhang lesen. Sequenzen in Attributwerten
    # und Textareas sind Nutzdaten, keine Kommentare oder Skriptblöcke.
    $attributes = '(?<attrs>(?:[^>"'']|"[^"]*"|''[^'']*'')*)'
    $boundary = '(?=[\s/>])'
    $htmlPattern = '(?is)<!--.*?(?:-->|\z)' +
        '|<script' + $boundary + $attributes + '>.*?(?:</script\s*>|\z)' +
        '|<plaintext' + $boundary + $attributes + '>.*\z' +
        '|<(?<raw>style|title|xmp|iframe|noembed|noframes|noscript)' + $boundary + $attributes + '>.*?(?:</\k<raw>\s*>|\z)' +
        '|<(?<tag>textarea)' + $boundary + $attributes + '>(?<body>.*?)(?<bodyEnd></textarea\s*>|\z)' +
        '|<(?<tag>input)' + $boundary + $attributes + '>' +
        '|<(?<template>/?)template' + $boundary + $attributes + '>' +
        '|</?[a-z][a-z0-9:_-]*' + $boundary + $attributes + '>'
    $elements = [regex]::Matches($Content, $htmlPattern)
    # Nur explizit benannte, zitierte Formularfelder des Details lesen.
    $record = @{}
    $attributePattern = '(?i)(?:\A|\s)(?<key>[\w.:-]+)\s*=\s*(?:"(?<value>[^"]*)"|''(?<value>[^'']*)'')'
    $templateDepth = 0
    foreach ($control in $elements) {
        if ($control.Groups['template'].Success) {
            if ($control.Groups['template'].Value -eq '') { $templateDepth++ }
            elseif ($templateDepth -gt 0) { $templateDepth-- }
            continue
        }
        if ($templateDepth -gt 0) { continue }
        $tag = $control.Groups['tag'].Value
        if (-not $tag) { continue }
        $attrs = @{}
        $duplicateIdentityAttribute = $false
        foreach ($attribute in [regex]::Matches($control.Groups['attrs'].Value, $attributePattern)) {
            $key = $attribute.Groups['key'].Value
            if ($key -in 'name', 'value' -and $attrs.ContainsKey($key)) { $duplicateIdentityAttribute = $true }
            $attrs[$key] = $attribute.Groups['value'].Value
        }
        $name = $attrs['name']
        if ($name -notin $fields.Values -and $name -notin $nativeFields) { continue }
        if ($duplicateIdentityAttribute -or $record.ContainsKey($name)) { throw $unsupported }
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
    $hasNative = $native.Count -gt 0 -or @($record.Keys | Where-Object { $_ -in $nativeFields }).Count -gt 0
    if ($hasNative) {
        if ($native['argRefNum'] -notmatch '\A[0-9]{1,30}\z' -or
            $native['argPersistentID'] -notmatch '\Acr:[0-9]{1,30}\z' -or
            -not $record.ContainsKey('SET.summary') -or
            @($record.Keys | Where-Object { $_ -in $fields.Values }).Count -gt 0) { throw $unsupported }

        $detail = [ordered]@{
            Id = $native['argPersistentID'].Substring(3); RefNum = $native['argRefNum']
            Status = $native['status']; Summary = $record['SET.summary']; Description = $record['SET.description']
            Assignee = $record['assignee_combo_name']; Group = $record['group_combo_name']; Category = $null
            Priority = $record['SET.priority']; Urgency = $record['SET.urgency']; Impact = $record['SET.impact']
            Customer = $record['customer_combo_name']; Parent = $null
            AssigneeId = $record['SET.assignee']; GroupId = $record['SET.group']; CustomerId = $record['SET.customer']
            Change = $record['SET.change']; AffectedResource = $record['SET.affected_resource']
        }
        $dates = [ordered]@{ OpenedAt = 'open_date'; LastModified = 'last_mod_dt'; ResolvedAt = 'resolve_date'; ClosedAt = 'close_date' }
        foreach ($date in $dates.GetEnumerator()) {
            $seconds = [long]$native[$date.Value]
            $detail[$date.Key] = if ($seconds -gt 0) { [DateTimeOffset]::FromUnixTimeSeconds($seconds) } else { $null }
        }
        return [pscustomobject]$detail
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
