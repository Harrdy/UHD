<#
.SYNOPSIS
    Prüft eine lokale HAR-Datei offline und gibt nur Strukturmerkmale aus.
.DESCRIPTION
    Filtert einen ausgewählten Lesevorgang. Es werden keine Netzwerkaufrufe
    ausgeführt und keine neuen Dateien angelegt. Das Original enthält
    möglicherweise Geheimnisse und bleibt lokal. Nur den Strukturbericht teilen.
#>
[CmdletBinding()]
[OutputType([pscustomobject])]
param(
    [Parameter(Mandatory)]
    [string]$HarPath,

    [Parameter(Mandatory)]
    [ValidateSet('Search', 'Detail', 'Children', 'Attachments', 'Activities', 'Transitions', 'Page',
        'ListDetail', 'RequiredFields', 'Contact', 'ServiceContract', 'PriorityCalculation',
        'AgentGroups', 'GroupAgents')]
    [string]$Scenario,

    [ValidateRange(1, 20)]
    [int]$MaxReports = 5
)

# HAR- und Pfadfehler können Originalwerte enthalten. Der separate Runspace
# lässt weder diese Fehler noch die gespeicherten HTTP-Daten nach außen gelangen.
$reader = [powershell]::Create()
try {
    $null = $reader.AddScript({
        param($Path, $Root, $Case, $Limit, $ShapeScript)
        $ErrorActionPreference = 'Stop'
        $VerbosePreference = 'SilentlyContinue'
        Set-StrictMode -Version Latest
        . $ShapeScript

        $file = [IO.Path]::GetFullPath($Path, $Root)
        if ($file.StartsWith('\\') -or $file.StartsWith('//') -or
            [IO.Path]::GetExtension($file) -ine '.har' -or -not [IO.File]::Exists($file)) {
            throw 'Keine lokale HAR-Datei.'
        }
        if ([IO.FileInfo]::new($file).Length -gt 32MB) { throw 'HAR-Datei ist zu groß.' }
        $har = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($file)) -AsHashtable
        if ($har -isnot [System.Collections.IDictionary] -or
            $har['log'] -isnot [System.Collections.IDictionary] -or
            $har['log']['entries'] -isnot [array] -or $har['log']['entries'].Count -gt 15000) {
            throw 'HAR-Struktur konnte nicht verarbeitet werden.'
        }

        # Reportfähige Namen sind pro bestätigter Operation festgelegt.
        $readCase = switch ($Case) {
            'Search' { @{ Op = 'SEARCH'; Factory = 'cr'; Required = @('KEEP.where_clause'); Extra = @() } }
            'Detail' { @{ Op = 'SHOW_DETAIL'; Factory = 'cr'; Required = @('PERSID'); Extra = @() } }
            'Children' { @{ Op = 'SEARCH'; Factory = 'in'; Required = @('QBE.EQ.parent.id'); Extra = @('KEEP.forInChildList') } }
            'Attachments' { @{ Op = 'SEARCH'; Factory = 'attmnt'; Required = @('QBE.EQ.requests.cr.persistent_id'); Extra = @('HTMPL', 'KEEP.ticketFac', 'KEEP.forSavedAttmnts') } }
            'Activities' { @{ Op = 'SEARCH'; Factory = 'alg'; Required = @('QBE.EQ.call_req_id'); Extra = @() } }
            'Transitions' { @{ Op = 'VALID_TRANSITIONS'; Factory = ''; Required = @('STATUS', 'PERSID', 'TYPE'); Extra = @('FACTORY', 'STATUS_FACTORY', 'TENANT') } }
            'Page' { @{ Op = 'PG'; Factory = ''; Required = @('PG'); Extra = @() } }
            'ListDetail' { @{ Op = 'DTL'; Factory = ''; Required = @('ROW'); Extra = @() } }
            'RequiredFields' { @{ Op = 'GET_REQUIRED_FIELDS'; Factory = 'cr'; Required = @('status'); Extra = @('PROP_REF', 'TENANT') } }
            'Contact' { @{ Op = 'SPEC_HAND'; Factory = 'cnt'; Required = @('PERSID'); Extra = @() } }
            'ServiceContract' { @{ Op = 'GET_SVC_CONTRACT'; Factory = ''; Required = @('new_customer'); Extra = @('FUNC') } }
            'PriorityCalculation' { @{ Op = 'GET_PRI_CAL'; Factory = 'in'; Required = @(); Extra = @('callback', 'tenant_id') } }
            'AgentGroups' { @{ Op = 'GROUP_IN_AGT'; Factory = ''; Required = @(); Extra = @('agt_id', 'agt_name', 'group_id', 'FUNC', 'PROP_REF') } }
            'GroupAgents' { @{ Op = 'AGT_IN_GROUP'; Factory = ''; Required = @(); Extra = @('agt_id', 'agt_name', 'group_id', 'FUNC', 'PROP_REF') } }
        }
        $keys = @('OP') + $readCase.Required + $readCase.Extra
        if ($readCase.Factory) { $keys += 'FACTORY' }

        $reports = 0
        foreach ($entry in $har['log']['entries']) {
            if ($entry -isnot [System.Collections.IDictionary] -or
                $entry['request'] -isnot [System.Collections.IDictionary] -or
                $entry['response'] -isnot [System.Collections.IDictionary]) { continue }
            $request = $entry['request']
            $uri = $null
            if ($request['method'] -cne 'GET' -or $request['url'] -isnot [string] -or
                -not [uri]::TryCreate($request['url'], [UriKind]::Absolute, [ref]$uri) -or
                $uri.Scheme -cne 'https' -or $uri.AbsolutePath -inotmatch '\A/CAisd/pdmweb[23]?\.exe\z') { continue }

            $pairs = @{}
            $query = $uri.Query.TrimStart('?')
            if ($query.Length -gt 8192) { continue }
            $ambiguous = $false
            foreach ($part in $query -split '[+&]') {
                $name, $value = $part -split '=', 2
                if (-not $name -or $null -eq $value) { continue }
                $name = [uri]::UnescapeDataString($name)
                if ($pairs.ContainsKey($name)) { $ambiguous = $true; break }
                $pairs[$name] = [uri]::UnescapeDataString($value)
            }
            if ($ambiguous -or $pairs['OP'] -cne $readCase.Op -or
                ($readCase.Factory -and $pairs['FACTORY'] -cne $readCase.Factory) -or
                $pairs.ContainsKey('JEDIT')) { continue }
            if ($Case -in 'Page', 'ListDetail' -and
                ($pairs['SID'] -cnotmatch '\A[0-9]+\z' -or $pairs['FID'] -cnotmatch '\A[0-9]+\z' -or
                    $pairs[$readCase.Required[0]] -cnotmatch '\A[0-9]+\z')) { continue }
            $missing = @($readCase.Required | Where-Object { -not $pairs.ContainsKey($_) })
            if ($missing.Count) { continue }

            $response = $entry['response']
            $hasBody = $response['content'] -is [System.Collections.IDictionary] -and
                $response['content']['text'] -is [string] -and -not $response['content']['encoding']
            $body = if ($hasBody) { $response['content']['text'] } else { '' }
            $status = if ($response['status'] -is [ValueType] -and $response['status'] -in 100..599) { [int]$response['status'] }
            [pscustomobject]@{
                Scenario = $Case
                Method = 'GET'
                Operation = $readCase.Op
                Factory = if ($readCase.Factory) { $readCase.Factory } elseif ($Case -eq 'Transitions' -and $pairs['FACTORY'] -ceq 'cr') { 'cr' }
                ParameterNames = @($keys | Where-Object { $pairs.ContainsKey($_) })
                UnknownParameterCount = @($pairs.Keys | Where-Object { $_ -notin $keys -and $_ -notin 'SID', 'FID' }).Count
                StatusCode = $status
                TextBodyAvailable = $hasBody
                ResponseShape = Get-UHDReadEvidenceShape -Content $body
            }
            $reports++
            if ($reports -ge $Limit) { break }
        }
    }.ToString()).AddArgument($HarPath).AddArgument($PWD.ProviderPath).AddArgument($Scenario).AddArgument($MaxReports).
        AddArgument((Join-Path $PSScriptRoot 'Private/Get-UHDReadEvidenceShape.ps1'))

    try { $results = $reader.Invoke() }
    catch { throw 'Die lokale HAR-Datei konnte nicht sicher ausgewertet werden.' }
    if ($reader.HadErrors) { throw 'Die lokale HAR-Datei konnte nicht sicher ausgewertet werden.' }

    foreach ($report in $results) { [pscustomobject]$report }
}
finally {
    $reader.Dispose()
}
