<#
.SYNOPSIS
    Prüft genau einen belegten Leseaufruf für ein freigegebenes UHD-Testticket.
.DESCRIPTION
    Verwendet eine bereits aktive Modulsitzung und gibt nur Antwortmerkmale
    aus. Meldet sich weder an noch ab, folgt keinen Links und lädt keine
    Anhänge herunter. Die Rückgabe enthält keine Ticket- oder Sitzungswerte.
.PARAMETER Case
    Eine Probe: Detail, Children, Attachments, Transitions oder Activities.
.PARAMETER TestTicketId
    Interne numerische Kennung eines ausdrücklich dafür freigegebenen Tickets,
    nicht die sichtbare Ticketnummer aus der Request-Liste.
.PARAMETER ApprovedLiveRead
    Bestätigt die vorliegende Freigabe für genau diese Live-Leseprobe.
.PARAMETER Status
    Aktueller Status als Kurzcode; für Transitions erforderlich.
.PARAMETER TenantId
    Bekannte 32-stellige Hex-Mandantenkennung; für Transitions erforderlich.
#>
#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Case,

    [Parameter(Mandatory)]
    [string]$TestTicketId,

    [switch]$ApprovedLiveRead,

    [string]$Status,

    [string]$TenantId
)

if (-not $ApprovedLiveRead) {
    throw 'Keine Leseprobe ohne ausdrückliche Freigabe. Es wurde kein Request gesendet.'
}
if ($TestTicketId -notmatch '\A[0-9]{1,30}\z') {
    throw 'Eine numerische interne Testticket-ID ist erforderlich.'
}
if ($Case -cnotin 'Detail', 'Children', 'Attachments', 'Transitions', 'Activities') {
    throw 'Zulässige Leseproben: Detail, Children, Attachments, Transitions und Activities.'
}
if ($Case -eq 'Transitions') {
    if ($Status -cnotmatch '\A[A-Z][A-Z0-9]{0,31}\z' -or $TenantId -notmatch '\A[0-9A-Fa-f]{32}\z') {
        throw 'Für Statusübergänge sind der aktuelle Status-Kurzcode und die bekannte Hex-Mandantenkennung erforderlich.'
    }
}
elseif ($PSBoundParameters.ContainsKey('Status') -or $PSBoundParameters.ContainsKey('TenantId')) {
    throw 'Status und Mandantenkennung sind nur für die Probe Transitions zulässig.'
}

$modules = @(Get-Module -Name UHDServiceDesk)
if ($modules.Count -ne 1) {
    throw 'Genau ein geladenes UHDServiceDesk-Modul mit aktiver Sitzung ist erforderlich.'
}

. (Join-Path $PSScriptRoot 'Private/Get-UHDReadEvidenceShape.ps1')

# Get-UHDSession meldet eine fehlende Sitzung ohne Sitzungswerte.
$session = & $modules[0] { Get-UHDSession }
try {
    $response = & $modules[0] {
        param($ProbeSession, $ProbeCase, $Id, $CurrentStatus, $TicketTenant)

        $query = switch -CaseSensitive ($ProbeCase) {
            'Detail' { [ordered]@{ OP = 'SHOW_DETAIL'; FACTORY = 'cr'; PERSID = "cr:${Id}" } }
            'Children' { [ordered]@{ OP = 'SEARCH'; FACTORY = 'in'; 'QBE.EQ.parent.id' = $Id; 'KEEP.forInChildList' = '1' } }
            'Attachments' { [ordered]@{ OP = 'SEARCH'; FACTORY = 'attmnt'; HTMPL = 'list_attmnt_sd.htmpl'; 'KEEP.ticketFac' = 'cr'; 'QBE.EQ.requests.cr.persistent_id' = "cr:${Id}" } }
            'Transitions' { Get-UHDAuxiliaryQuery -Operation VALID_TRANSITIONS -Id $Id -Status $CurrentStatus -TenantId $TicketTenant }
            'Activities' { [ordered]@{ OP = 'SEARCH'; FACTORY = 'alg'; 'QBE.EQ.call_req_id' = "cr:${Id}" } }
        }
        $url = ConvertTo-UHDOperationUrl -Session $ProbeSession -Query $query
        Invoke-UHDRequest -Session $ProbeSession -Method GET -RelativeUrl $url -ReadOnly -RetryCount 0 -ErrorAction Stop -Verbose:$false -Debug:$false
    } $session $Case $TestTicketId $Status $TenantId
    $report = [pscustomobject]@{
        Case = $Case
        HttpStatus = [int]$response.StatusCode
        Shape = Get-UHDReadEvidenceShape -Content ([string]$response.Content)
    }
}
catch {
    # Keine Fehlerdetails aus Transport oder Antwortparser nach außen geben.
    throw 'Die UHD-Leseprobe konnte nicht ausgewertet werden. Es werden keine Rohdaten ausgegeben.'
}
$report
