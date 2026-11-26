function ConvertFrom-UHDStatusResponse {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content
    )

    $unsupported = 'Das Antwortformat der Statusübergänge ist noch offen oder ungültig.'
    $entry = [regex]::Replace($Content, '(?:\r?\n)?\x00?\z', '')
    $codePattern = '\A[A-Z][A-Z0-9]{0,31}\z'
    $fields = $entry.Split('@')

    # Die bisher unterstützte Kurzform enthält keine Angaben zum Standard
    # oder zum Kommentar.
    if ($fields.Length -eq 2) {
        $short = [regex]::Match($entry.Trim(), '\A(?<code>[A-Z][A-Z0-9]{0,31})@(?<label>(?:[A-Za-z0-9._~-]|%[0-9A-Fa-f]{2})+)\z')
        if (-not $short.Success) { throw $unsupported }
        $defaultLabel = [uri]::UnescapeDataString($short.Groups['label'].Value).Replace('%27', "'")
        if ([string]::IsNullOrWhiteSpace($defaultLabel) -or $defaultLabel -match '[\p{C}]|%[0-9A-Fa-f]{2}') { throw $unsupported }
        return [pscustomobject]@{ Code = $short.Groups['code'].Value; Label = $defaultLabel; IsDefault = $null; CommentRequired = $null }
    }

    # Die Browserauswertung überspringt das dritte Feld und liest danach
    # die Zielcodes mit ihren jeweiligen Kommentarflags.
    if ($fields.Length -lt 6 -or $fields.Length % 2 -ne 0 -or $fields[-1] -cne '' -or $fields[2] -cnotin 'N', 'Y') {
        throw $unsupported
    }

    $defaultCode = $fields[0]
    $defaultLabel = $null
    if ($defaultCode) {
        if ($defaultCode -cnotmatch $codePattern -or $fields[1] -match '%(?![0-9A-Fa-f]{2})') { throw $unsupported }
        $defaultLabel = [uri]::UnescapeDataString($fields[1]).Replace('%27', "'")
        if ([string]::IsNullOrWhiteSpace($defaultLabel) -or $defaultLabel -match '[\p{C}]|%[0-9A-Fa-f]{2}') { throw $unsupported }
    }
    elseif ($fields[1]) {
        throw $unsupported
    }

    $codes = [System.Collections.Generic.HashSet[string]]::new()
    $results = @(
        for ($index = 3; $index -lt $fields.Length - 1; $index += 2) {
            $code = $fields[$index]
            $comment = $fields[$index + 1]
            if ($code -cnotmatch $codePattern -or $comment -cnotin 'N', 'Y' -or -not $codes.Add($code)) { throw $unsupported }
            $isDefault = $code -ceq $defaultCode
            [pscustomobject]@{
                Code            = $code
                Label           = if ($isDefault) { $defaultLabel } else { $null }
                IsDefault       = $isDefault
                CommentRequired = $comment -ceq 'Y'
            }
        }
    )
    if ($defaultCode -and -not $codes.Contains($defaultCode)) { throw $unsupported }
    foreach ($result in $results) { [pscustomobject]$result }
}
