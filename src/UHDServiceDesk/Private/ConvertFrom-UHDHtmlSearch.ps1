function ConvertFrom-UHDHtmlSearch {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content
    )

    $unsupported = 'Antwortformat der UHD-Ticketsuche nicht erkannt; es wurden keine Treffer ausgegeben.'
    if ($Content.Length -gt 1MB) { throw $unsupported }

    $html = [regex]::Replace($Content, '(?s)<!--.*?(?:-->|\z)', '')
    $tables = [regex]::Matches($html, '(?is)<table\s[^>]*?(?<=\s)summary\s*=\s*["'']Request-Liste["''](?=[\s>])[^>]*>(?<rows>.*?)</table\s*>')
    if ($tables.Count -ne 1) { throw $unsupported }

    # Die beobachtete Liste trennt Treffer per Linie. Ein unbekannter oder
    # unvollständiger Treffer verhindert die Ausgabe der gesamten Seite.
    $rows = [regex]::Split($tables[0].Groups['rows'].Value, '(?i)<tr>\s*<td\s+colspan\s*=\s*2\s*>\s*<hr\s*>\s*</td>\s*</tr>')
    if ($rows.Length -lt 2 -or -not [string]::IsNullOrWhiteSpace($rows[0])) { throw $unsupported }

    $ticketLink = '<a\s+href=/CAisd/pdmweb[23]?\.exe\?SID=[0-9]+\+FID=[0-9]+\+OP=DTL\+ROW=(?<row>[0-9]+)\s*>\s*<span[^>]*>\s*<b>\s*(?<ref>[0-9]+)\s*</b>\s*</span>\s*</a>'
    $pattern = '(?is)\A\s*<tr>\s*<th[^>]*>\s*Request-Nummer:\s*</th>\s*<td[^>]*>\s*' + $ticketLink + '\s*</td>\s*</tr>\s*'
    $fields = [ordered]@{ Customer = 'Endanwender'; Status = 'Status'; Priority = 'Priorität' }
    foreach ($field in $fields.GetEnumerator()) {
        $pattern += '<tr>\s*<th[^>]*>\s*{0}:\s*</th>\s*<td[^>]*>(?<{1}>[^<]*)</td>\s*</tr>\s*' -f $field.Value, $field.Key
    }
    $pattern += '<tr>\s*<th[^>]*>\s*Zusammenfassung:\s*</th>\s*(?:</tr>\s*)?<tr>\s*<td[^>]*>(?<Summary>[^<]*)</td>\s*</tr>\s*\z'
    $rowPattern = [regex]$pattern
    $numbers = [System.Collections.Generic.HashSet[string]]::new()

    $output = @(
        for ($index = 1; $index -lt $rows.Length; $index++) {
            $row = $rowPattern.Match($rows[$index])
            if (-not $row.Success -or $row.Groups['row'].Value -cne [string]($index - 1) -or -not $numbers.Add($row.Groups['ref'].Value)) {
                throw $unsupported
            }

            # Der Link enthält nur eine Zeilenposition, keine persistente Ticket-ID.
            [pscustomobject][ordered]@{
                Id = $null
                RefNum = $row.Groups['ref'].Value
                Status = [System.Net.WebUtility]::HtmlDecode($row.Groups['Status'].Value.Trim())
                Summary = [System.Net.WebUtility]::HtmlDecode($row.Groups['Summary'].Value.Trim())
                Description = $null
                Assignee = $null
                Group = $null
                Category = $null
                Priority = [System.Net.WebUtility]::HtmlDecode($row.Groups['Priority'].Value.Trim())
                Urgency = $null
                Impact = $null
                Customer = [System.Net.WebUtility]::HtmlDecode($row.Groups['Customer'].Value.Trim())
                Parent = $null
                GroupId = $null
                LastModified = $null
            }
        }
    )
    foreach ($ticket in $output) { [pscustomobject]$ticket }
}
