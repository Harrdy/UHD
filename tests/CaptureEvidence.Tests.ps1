BeforeAll {
    $script:measure = Join-Path $PSScriptRoot '../examples/Measure-UHDReadCapture.ps1'
}

Describe 'Offline-HAR-Strukturbericht' {
    BeforeEach {
        $script:capture = Join-Path $TestDrive 'local-probe.har'
        $query = 'SID=101+FID=202+OP=SEARCH+FACTORY=attmnt+QBE.EQ.requests.cr.persistent_id=cr%3A303+KEEP.ticketFac=cr'
        $body = @'
<html><script>
recordData["ref_num"] = "PERSOENLICHE-PROBE";
recordData["NICHT-BERICHTEN"] = "PERSOENLICHE-PROBE";
rs.addRow(recordData);
attmntdata.orig_file_name = "PERSOENLICHE-PROBE";
attmntdata.orig_file_name = chooseName(PERSOENLICHE_PROBE);
attmntdata.file_size = 4242;
attmntdata.NICHT_BERICHTEN = "PERSOENLICHE-PROBE";
attListData = new Array();
attListData[0] = attmntdata;
</script></html>
'@
        $base = 'https://INTERNE-PROBE.invalid/CAisd/pdmweb2.exe?'
        $reportable = @{
            request = @{ method = 'GET'; url = $base + $query + '+NICHT-BERICHTEN=PERSOENLICHE-PROBE' }
            response = @{ status = 200; content = @{ text = $body } }
        }
        $post = @{
            request = @{ method = 'POST'; url = $base + $query }
            response = @{ status = 201; content = @{ text = 'PERSOENLICHE-PROBE' } }
        }
        $mutations = foreach ($op in 'UPDATE', 'CREATE_NEW', 'UNBEKANNT') {
            @{
                request = @{ method = 'GET'; url = $base + $query.Replace('OP=SEARCH', "OP=$op") }
                response = @{ status = 299; content = @{ text = 'PERSOENLICHE-PROBE' } }
            }
        }
        @{
            log = @{ entries = @($post) + @($mutations) + @($reportable, $reportable) }
        } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $script:capture
    }

    It 'liefert nur bekannte Strukturen und begrenzt die Anzahl nach Szenario' {
        $r = @(& $script:measure -HarPath $script:capture -Scenario Attachments -MaxReports 1)
        $r.Count | Should -Be 1
        $r[0].Method | Should -BeExactly 'GET'
        $r[0].Operation | Should -BeExactly 'SEARCH'
        $r[0].Factory | Should -BeExactly 'attmnt'
        $r[0].StatusCode | Should -Be 200
        $r[0].TextBodyAvailable | Should -BeTrue
        $r[0].ParameterNames | Should -Contain 'QBE.EQ.requests.cr.persistent_id'
        $r[0].ParameterNames | Should -Not -Contain 'SID'
        $r[0].UnknownParameterCount | Should -Be 1
        $r[0].ResponseShape.RecordDataRows | Should -Be 1
        $r[0].ResponseShape.KnownRecordFields | Should -Be 'ref_num'
        $r[0].ResponseShape.AttachmentMarkers | Should -Be 4
        $r[0].ResponseShape.KnownAttachmentFields.Name | Should -Be @('orig_file_name', 'file_size')
        $r[0].ResponseShape.KnownAttachmentFields[0].ValueKinds | Should -Be @('Expression', 'String')
        $r[0].ResponseShape.KnownAttachmentFields[1].ValueKinds | Should -Be @('Integer')
        $r[0].ResponseShape.UnknownAttachmentAssignmentCount | Should -Be 1
        $r[0].ResponseShape.AttachmentListAssignmentMarkers | Should -Be 2
        ($r | ConvertTo-Json -Depth 8) | Should -Not -Match 'INTERNE-PROBE|PERSOENLICHE[-_]PROBE|NICHT[-_]BERICHTEN|local-probe|cr:303|<script>|UPDATE|CREATE_NEW|4242|chooseName'
        @(& $script:measure -HarPath $script:capture -Scenario Detail).Count | Should -Be 0
    }

    It 'zählt POST, schreibende GETs und nicht bekannte Vorgänge nicht mit' {
        $r = @(& $script:measure -HarPath $script:capture -Scenario Attachments)
        $r.Count | Should -Be 2
        @($r | Where-Object StatusCode -ne 200).Count | Should -Be 0
    }

    It 'veröffentlicht bei einer beschädigten HAR-Datei keine Originalwerte in Fehlern' {
        '{"log":{"entries": [ "PERSOENLICHE-PROBE' | Set-Content -LiteralPath $script:capture
        $firstError = @{}
        & {
            try { & $script:measure -HarPath $script:capture -Scenario Search }
            catch { $firstError['Text'] = $_.Exception.Message }
        }
        $firstError['Text'] | Should -BeExactly 'Die lokale HAR-Datei konnte nicht sicher ausgewertet werden.'
        ($Error | ForEach-Object { $_.Exception.Message }) -join ' ' | Should -Not -Match 'PERSOENLICHE-PROBE'
    }

    It 'kennzeichnet kodierte Antwortdaten ohne sie auszuwerten' {
        $har = Get-Content -LiteralPath $script:capture -Raw | ConvertFrom-Json -AsHashtable
        $har.log.entries[-1].response.content.encoding = 'base64'
        $har | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $script:capture
        $r = @(& $script:measure -HarPath $script:capture -Scenario Attachments)
        $r[-1].TextBodyAvailable | Should -BeFalse
        $r[-1].ResponseShape.RecordDataRows | Should -Be 0
    }

    It 'enthält keine direkten Netzwerk- oder Schreibbefehle' {
        $scriptText = Get-Content -LiteralPath $script:measure -Raw
        $scriptText | Should -Not -Match 'Invoke-WebRequest|Invoke-RestMethod|Invoke-UHDRequest|Set-Content|Export-Clixml|WriteAllText|Start-Process'
    }
}
