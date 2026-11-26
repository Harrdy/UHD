Import-Module (Join-Path $PSScriptRoot '../src/UHDServiceDesk/UHDServiceDesk.psd1') -Force

Describe 'UHD-Ticketdetails im bestätigten Browserformat' {
    InModuleScope UHDServiceDesk {
        BeforeAll {
            $script:mockDetail = @'
<html><script>
var argRefNum = "502";
var argPersistentID = "cr:41";
detailDropdown("Status", "status", "typ", 1, 20, "1", "crs:18", "status");
detailDropdown("Anderes Feld", "typ", "typ", 1, 20, "1", "x:20");
detailDateReadonly("Beginn","open_date",1,"Zeit","1234567890", "");
detailDateReadonly("Geändert","last_mod_dt",1,"Zeit","1234567899", "");
detailDateReadonly("Gelöst","resolve_date",1,"Zeit","", "");
detailDateReadonly("Geschlossen","close_date",1,"Zeit","", "");
</script>
<input type="hidden" name="SET.summary" value="Beispiel &amp; Probe">
<input type="hidden" name="SET.description" value="Beschreibung">
<input type="hidden" name="SET.assignee" value="BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB">
<input type="hidden" name="assignee_combo_name" value="Testperson">
<input type="hidden" name="SET.customer" value="CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC">
<input type="hidden" name="customer_combo_name" value="Testkunde">
<input type="hidden" name="SET.group" value="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA">
<input type="hidden" name="group_combo_name" value="Testgruppe">
<input type="hidden" name="SET.priority" value="4">
<input type="hidden" name="SET.urgency" value="2">
<input type="hidden" name="SET.impact" value="3">
<input type="hidden" name="SET.change" value="">
<input type="hidden" name="SET.affected_resource" value="">
<template><input name="SET.summary" value="Nicht ausgeben"></template>
</html>
'@
        }
        BeforeEach {
            Mock Get-UHDSession { [pscustomobject]@{ SID = '11'; FID = '20'; Servlet = 'pdmweb2.exe' } }
            Mock Invoke-UHDWebRequest { throw 'Keine Netzwerkverbindung in diesem Test erlaubt.' }
            Mock Invoke-UHDRequest { [pscustomobject]@{ StatusCode = 200; Content = $script:mockDetail } }
        }
        It 'liest die belegten Felder und hält Objektidentität, sichtbare Nummer und Displaywerte getrennt' {
            $t = Get-UHDTicket -Id 41
            $t.Id | Should -BeExactly '41'
            $t.RequestedId | Should -BeExactly '41'
            $t.RefNum | Should -BeExactly '502'
            $t.Status | Should -BeExactly 'crs:18'
            $t.Summary | Should -BeExactly 'Beispiel & Probe'
            $t.Description | Should -BeExactly 'Beschreibung'
            $t.Assignee | Should -BeExactly 'Testperson'
            $t.AssigneeId | Should -BeExactly 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'
            $t.Customer | Should -BeExactly 'Testkunde'
            $t.CustomerId | Should -BeExactly 'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC'
            $t.Group | Should -BeExactly 'Testgruppe'
            $t.GroupId | Should -BeExactly 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
            $t.Priority | Should -BeExactly '4'
            $t.Urgency | Should -BeExactly '2'
            $t.Impact | Should -BeExactly '3'
            $t.Change | Should -BeExactly ''
            $t.AffectedResource | Should -BeExactly ''
            $t.OpenedAt | Should -Be ([DateTimeOffset]::FromUnixTimeSeconds(1234567890))
            $t.LastModified | Should -Be ([DateTimeOffset]::FromUnixTimeSeconds(1234567899))
            $t.ResolvedAt | Should -BeNullOrEmpty
            $t.ClosedAt | Should -BeNullOrEmpty
            Should -Invoke Invoke-UHDRequest -Exactly 1 -ParameterFilter { $Method -eq 'GET' -and $ReadOnly -and $RelativeUrl -like '*OP=SHOW_DETAIL*' }
        }
        It 'lehnt eine andere Identität der Antwort ab' {
            { Get-UHDTicket -Id 42 } | Should -Throw '*gehört nicht zur angefragten*'
            Should -Invoke Invoke-UHDRequest -Exactly 1
        }
        It 'interpretiert weder ausgeblendete noch zusammengesetzte Scriptwerte' {
            $hidden = $script:mockDetail.Replace('var argRefNum = "502";', 'const decoy = "var argRefNum = 502;";')
            { ConvertFrom-UHDTicketResponse -Content $hidden } | Should -Throw '*Antwortformat*'
            $calculated = $script:mockDetail.Replace('"1234567899"', 'console.log("niemals ausführen")')
            { ConvertFrom-UHDTicketResponse -Content $calculated } | Should -Throw '*Antwortformat*'
            $mixed = $script:mockDetail + '<input name="summary" value="Nicht ausgeben">'
            { ConvertFrom-UHDTicketResponse -Content $mixed } | Should -Throw '*Antwortformat*'
        }
        It 'liest keine Formularfelder aus dem Plaintext-Bereich' {
            $native = $script:mockDetail.Replace('<input type="hidden" name="SET.summary"', '<plaintext><input type="hidden" name="SET.summary"')
            { ConvertFrom-UHDTicketResponse -Content $native } | Should -Throw '*Antwortformat*'
            $legacy = '<input name="ref_num" value="70"><plaintext><input name="summary" value="Inaktiver Text">'
            { ConvertFrom-UHDTicketResponse -Content $legacy } | Should -Throw '*Antwortformat*'
        }
    }
}
