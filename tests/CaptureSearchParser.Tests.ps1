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
rs.data("Testbearbeiter");
recordData["assignee"] = celldatatowrite;
rs.data(date_to_string('1234567890'));
recordData["last_mod_dt"] = celldatatowrite;
rs.data(date_to_string("1234567890"));
recordData["last_mod_dt"] = celldatatowrite;
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
            $results[0].Assignee | Should -BeExactly 'Testbearbeiter'
            $results[0].LastModified | Should -Be ([DateTimeOffset]::FromUnixTimeSeconds(1234567890))
            $results[0].LastModified.Offset | Should -Be ([TimeSpan]::Zero)
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

        It 'verwirft Treffer in nicht ausführbaren oder mehrdeutigen Skript-Typen: <Type>' -ForEach @(
            @{ Type = 'type="text/html"' }
            @{ Type = 'type="text/javascript" type="text/html"' }
        ) {
            { ConvertFrom-UHDCapturedSearch -Content "<script $Type>`n$script:rowFixture`n</script>" } | Should -Throw '*Antwortformat*'
        }

        It 'akzeptiert den belegten Typ text/javascript' {
            @(ConvertFrom-UHDCapturedSearch -Content "<script type='text/javascript'>`n$script:rowFixture`n</script>").Count | Should -Be 1
        }

        It 'wertet bei externen Skripten keine eingebetteten Treffer aus: <Source>' -ForEach @(
            @{ Source = 'src="/dummy.js"' }
            @{ Source = 'src=""' }
            @{ Source = 'SRC' }
            @{ Source = 'src="/dummy.js" src="/other.js"' }
        ) {
            $external = "<script $Source>`n$script:rowFixture`n</script>"
            { ConvertFrom-UHDCapturedSearch -Content $external } | Should -Throw '*Antwortformat*'

            $real = $script:rowFixture.Replace('cr:42', 'cr:57').Replace('EX-42', 'EX-57')
            $results = @(ConvertFrom-UHDCapturedSearch -Content "$external`n<script>`n$real`n</script>")
            $results.Count | Should -Be 1
            $results[0].Id | Should -BeExactly '57'
        }

        It 'gibt bei defektem Folgedatensatz keine Teilergebnisse aus: <Mode>' -ForEach @(
            @{ Mode = 'keine Zeilengrenze'; Old = 'rs.addRow'; New = '// rs.addRow' }
            @{ Mode = 'unbekannte Formatmischung'; Old = 'new Object()'; New = '{"ref_num":"EX-57"}' }
            @{ Mode = 'berechneter Wert'; Old = 'writeIcon("EX-42",ref_num_style)'; New = 'writeIcon(executeSynthetic(),ref_num_style)' }
            @{ Mode = 'veralteter Zellwert'; Old = 'recordData["priority"] ='; New = "otherCall();`nrecordData[`"priority`"] =" }
            @{ Mode = 'unbekannter Escape'; Old = 'noch Text'; New = 'noch \ZText' }
            @{ Mode = 'widersprüchliche Wiederholung'; Old = "rs.data('Beispiel"; New = "rs.data('Konflikt" }
            @{ Mode = 'berechneter Zeitstempel'; Old = "date_to_string('1234567890')"; New = 'date_to_string(executeSynthetic())' }
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
