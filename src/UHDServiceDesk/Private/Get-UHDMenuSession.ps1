function Get-UHDMenuSession {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [AllowEmptyString()]
        [string]$Content
    )

    $fields = @{}
    # Kommentare und Skripte als ganze Blöcke überspringen, bevor nach
    # tatsächlichen Eingabefeldern gesucht wird.
    $tokenPattern = @'
<!--.*?(?:--!?>|\z)|<script(?=[\s/>])(?:[^<>"']|"[^"]*"|'[^']*')*>.*?(?:</script\s*>|\z)|(?<inputTag><input(?=[\s/>])(?:[^<>"']|"[^"]*"|'[^']*')*>)|</?[A-Za-z](?:[^<>"']|"[^"]*"|'[^']*')*>
'@
    $attributePattern = @'
\s+(?<key>[^=\s"'<>/]+)\s*=\s*(?:"(?<value>[^"]*)"|'(?<value>[^']*)'|(?<value>[^\s"'=<>\x60]+))
'@
    foreach ($token in [regex]::Matches($Content, $tokenPattern, 'IgnoreCase, Singleline')) {
        $inputTag = $token.Groups['inputTag']
        if (-not $inputTag.Success) { continue }
        $attributes = @{}
        foreach ($attribute in [regex]::Matches($inputTag.Value, $attributePattern)) {
            $key = $attribute.Groups['key'].Value
            if ($attributes.ContainsKey($key)) { throw 'UHD-Menüformular enthält mehrdeutige Felder.' }
            $attributes[$key] = $attribute.Groups['value'].Value
        }
        $name = $attributes['name']
        if ($name -notin 'SID', 'FID') { continue }
        if ($fields.ContainsKey($name) -or $attributes['value'] -notmatch '\A[0-9]+\z') {
            throw 'UHD-Menüformular enthält ungültige oder mehrdeutige Sitzungsfelder.'
        }
        $fields[$name] = $attributes['value']
    }
    if ($fields.Count -ne 2) { throw 'Anmeldung fehlgeschlagen: Menüformular nicht gefunden.' }
    $fields
}
