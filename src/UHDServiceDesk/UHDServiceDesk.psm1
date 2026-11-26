Set-StrictMode -Version Latest

# Modulweiter Sitzungszustand. Wird ausschließlich von Connect-UHD / Disconnect-UHD gesetzt.
$script:UHDSession = $null

foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue) {
    . $file.FullName
}
foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1') {
    . $file.FullName
}
