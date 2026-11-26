function Get-UHDReadEvidenceShape {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content
    )

    # Nur feste Merkmale und Namen aus der eigenen Liste ausgeben, niemals Trefferwerte.
    $characters = $Content.Length
    $inspected = $characters -le 1MB
    if (-not $inspected) { $Content = '' }

    $recordNames = @('persid', 'rownum', 'ref_num', 'status', 'summary', 'description', 'assignee', 'group',
        'group.id', 'category', 'priority', 'urgency', 'impact', 'customer.combo_name', 'parent', 'last_mod_dt',
        'call_req_id', 'analyst', 'time_stamp', 'type', 'orig_file_name', 'file_size', 'status_code')
    $controlNames = @('ref_num', 'status', 'summary', 'description', 'SET.assignee', 'SET.customer', 'SET.group',
        'SET.summary', 'SET.description', 'SET.priority', 'SET.urgency', 'SET.impact', 'SET.change',
        'SET.affected_resource', 'assignee_combo_name', 'customer_combo_name', 'group_combo_name')
    $knownRecords = @(
        foreach ($name in $recordNames) {
            $pattern = '\brecordData\s*\[\s*["'']' + [regex]::Escape($name) + '["'']\s*\]\s*='
            if ($Content -cmatch $pattern) { $name }
        }
    )
    $knownControls = @(
        foreach ($name in $controlNames) {
            $pattern = '(?i)\bname\s*=\s*(?:"{0}"|''{0}''|{0}(?=[\s/>]))' -f [regex]::Escape($name)
            if ($Content -match $pattern) { $name }
        }
    )

    # Nur Zuweisungsmuster zählen. Solche Marker können auch zu UI-Gerüstcode
    # gehören und belegen für sich allein keinen tatsächlich vorhandenen Anhang.
    $attachmentNames = @('orig_file_name', 'file_size', 'description', 'status', 'status_code', 'id')
    $attachmentAssignment = '(?m)^[ \t]*attmntdata[ \t]*\.[ \t]*(?<name>[A-Za-z_$][A-Za-z0-9_$]*)[ \t]*=(?![=>])[ \t]*(?<rhs>[^\r\n]*);[ \t]*\r?$'
    $attachmentKinds = @{}
    $unknownAttachmentCount = 0
    foreach ($assignment in [regex]::Matches($Content, $attachmentAssignment)) {
        $fieldName = $assignment.Groups['name'].Value
        if ($fieldName -cnotin $attachmentNames) { $unknownAttachmentCount++; continue }

        $kind = switch -CaseSensitive -Regex ($assignment.Groups['rhs'].Value.Trim()) {
            '\A(?:"(?:\\[^\r\n]|[^"\\])*"|''(?:\\[^\r\n]|[^''\\])*'')\z' { 'String'; break }
            '\A-?[0-9]+\z' { 'Integer'; break }
            '\A(?:true|false)\z' { 'Boolean'; break }
            '\Anull\z' { 'Null'; break }
            default { 'Expression' }
        }
        if (-not $attachmentKinds.ContainsKey($fieldName)) {
            $attachmentKinds[$fieldName] = [System.Collections.Generic.HashSet[string]]::new()
        }
        $null = $attachmentKinds[$fieldName].Add($kind)
    }
    $knownAttachments = @(
        foreach ($name in $attachmentNames) {
            if ($attachmentKinds.ContainsKey($name)) {
                [pscustomobject]@{ Name = $name; ValueKinds = @($attachmentKinds[$name] | Sort-Object) }
            }
        }
    )

    [pscustomobject]@{
        Characters = $characters
        Inspected = $inspected
        Html = $Content -match '<html\b'
        Script = $Content -match '<script\b'
        RequestTableMarker = $Content -match '<table\b[^>]*\bsummary\s*=\s*["'']Request-Liste["'']'
        RecordDataRows = [regex]::Matches($Content, '\brs\s*\.\s*addRow\s*\(').Count
        KnownRecordFields = $knownRecords
        KnownControls = $knownControls
        DetailLinkMarkers = [regex]::Matches($Content, '(?i)\bOP=DTL(?=[+&])').Count
        PageLinkMarkers = [regex]::Matches($Content, '(?i)\bOP=PG(?=[+&])').Count
        AttachmentMarkers = [regex]::Matches($Content, '\battmntdata\s*\.').Count
        KnownAttachmentFields = $knownAttachments
        UnknownAttachmentAssignmentCount = $unknownAttachmentCount
        AttachmentListAssignmentMarkers = [regex]::Matches($Content, '(?m)^[ \t]*(?:var[ \t]+)?attListData(?:[ \t]*\[[^\]\r\n]*\])?[ \t]*=(?![=>])').Count
        ZeroTotalMarker = $Content -match '\bcfgTotal\s*=\s*["'']0["'']'
        ZeroRecordCountMarker = $Content -match '\bcfgRecordCount\s*=\s*["'']0["'']'
        AtSeparators = [regex]::Matches($Content, '@').Count
    }
}
