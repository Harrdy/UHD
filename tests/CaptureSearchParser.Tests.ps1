Import-Module (Join-Path $PSScriptRoot '../src/UHDServiceDesk/UHDServiceDesk.psd1') -Force

Describe 'UHD-Suchantwort im Browserformat' {
    InModuleScope UHDServiceDesk {
        BeforeAll {
            # Ausschließlich synthetische Werte, keine HAR-Antworten.
            $script:rowFixture = @'
recordData = new Object();
recordData["persid"] = "cr:42";
recordData["rownum"] = "1";
recordData["nicht-ausgeben"] = "Andere Daten";
writeIcon("EX-42",ref_num_style);
recordData["ref_num"] = celldatatowrite;
rs.data("Beispiel \"Zitat\"; // noch Text \\Ordner");
recordData["summary"] = celldatatowrite;
rs.data('Beispiel \"Zitat\"; // noch Text \\Ordner');
recordData["summary"] = celldatatowrite;
rs.data("Gruppe Beispiel");
recordData["group"] = celldatatowrite;
rs.data("ABCDEF0123456789ABCDEF0123456789");
recordData["group.id"] = celldatatowrite;
rs.data("");
recordData["assignee"] = celldatatowrite;
colorPrios("3");
recordData["priority"] = celldatatowrite;
rs.addRow(recordData["rownum"], recordData, styleData, imageData);
'@
        }

        It 'extrahiert die Suchtreffer, Kennungen und Literale in Zeilenreihenfolge' {
            $second = $script:rowFixture.Replace('cr:42', 'cr:57').Replace('EX-42', 'EX-57')
            $results = @(ConvertFrom-UHDCapturedSearch -Content "<script>`n$script:rowFixture`n$second`n</script>")
            $results.Id | Should -Be @('42', '57')
            $results.RefNum | Should -Be @('EX-42', 'EX-57')
            $results[0].Summary | Should -BeExactly 'Beispiel "Zitat"; // noch Text \Ordner'
            $results[0].Group | Should -BeExactly 'Gruppe Beispiel'
            $results[0].GroupId | Should -BeExactly 'ABCDEF0123456789ABCDEF0123456789'
            $results[0].Priority | Should -BeExactly '3'
            $results[0].Assignee | Should -BeExactly ''
            $results[0].Description | Should -BeNullOrEmpty
            $results[0].PSObject.Properties.Name | Should -Not -Contain 'nicht-ausgeben'
        }

        It 'ignoriert HTML-Kommentare, Textbereiche und JS-Kommentare oder String-Attrappen' {
            $html = @"
<!--<script>`n$script:rowFixture`n</script>-->
<textarea><script>`n$script:rowFixture`n</script></textarea>
<script>
// recordData = unsupported();
const text = 'recordData["summary"] = unsupported();';
/* recordData = unsupported(); */
$script:rowFixture
</script>
"@
            @(ConvertFrom-UHDCapturedSearch -Content $html).Count | Should -Be 1
        }

        It 'gibt bei defektem Folgedatensatz keine Teilergebnisse aus: <Mode>' -ForEach @(
            @{ Mode = 'keine Zeilengrenze'; Old = 'rs.addRow'; New = '// rs.addRow' }
            @{ Mode = 'unbekannte Formatmischung'; Old = 'new Object()'; New = '{"ref_num":"EX-57"}' }
            @{ Mode = 'berechneter Wert'; Old = 'writeIcon("EX-42",ref_num_style)'; New = 'writeIcon(executeSynthetic(),ref_num_style)' }
            @{ Mode = 'veralteter Zellwert'; Old = 'recordData["priority"] ='; New = "otherCall();`nrecordData[`"priority`"] =" }
            @{ Mode = 'unbekannter Escape'; Old = 'noch Text'; New = 'noch \ZText' }
            @{ Mode = 'widersprüchliche Wiederholung'; Old = "rs.data('Beispiel"; New = "rs.data('Konflikt" }
        ) {
            $corrupt = $script:rowFixture.Replace($Old, $New).Replace('cr:42', 'cr:57')
            $emitted = [System.Collections.Generic.List[object]]::new()
            { ConvertFrom-UHDCapturedSearch -Content "<script>`n$script:rowFixture`n$corrupt`n</script>" |
                ForEach-Object { $emitted.Add($_) } } | Should -Throw '*Antwortformat der UHD-Ticketsuche*'
            $emitted.Count | Should -Be 0
        }

        It 'wertet eine nicht belegte leere oder abgeschnittene Seite nicht als Erfolg' {
            { ConvertFrom-UHDCapturedSearch -Content '<script>const noData = true;</script>' } | Should -Throw '*Antwortformat*'
            { ConvertFrom-UHDCapturedSearch -Content "<script>`n$script:rowFixture" } | Should -Throw '*Antwortformat*'
        }
    }
}
