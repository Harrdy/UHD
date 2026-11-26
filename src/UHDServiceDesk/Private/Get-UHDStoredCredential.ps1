function Get-UHDStoredCredential {
    <#
    .SYNOPSIS
        Liefert die gespeicherten Zugangsdaten oder fragt sie per Login-Fenster ab.
    .DESCRIPTION
        Liest die Datei unter -Path (Export-Clixml). Fehlt sie, unbrauchbar ist oder
        -Reset gesetzt ist, öffnet sich das Login-Fenster (Get-Credential). Die
        neuen Daten werden danach in -Path gespeichert.
        Die Datei ist unter Windows mit DPAPI verschlüsselt und nur für denselben
        Benutzer auf demselben Rechner lesbar.
    #>
    [CmdletBinding()]
    [OutputType([pscredential])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Reset
    )

    if (-not $Reset -and (Test-Path -LiteralPath $Path -PathType Leaf)) {
        try {
            $stored = Import-Clixml -LiteralPath $Path
            if ($stored -is [pscredential]) {
                Write-Verbose "Gespeicherte Zugangsdaten geladen: $Path"
                return $stored
            }
            Write-Warning 'Credential-Datei hat ein unerwartetes Format und wird neu angelegt.'
        }
        catch {
            Write-Warning "Credential-Datei kann nicht gelesen werden und wird neu angelegt: $($_.Exception.Message)"
        }
    }

    if (-not [Environment]::UserInteractive) {
        throw 'Keine Zugangsdaten gespeichert und kein Login-Fenster möglich. Bitte zuerst interaktiv anmelden.'
    }

    if (-not $IsWindows) {
        Write-Warning 'Credential-Speicherung ist nur unter Windows (DPAPI) ausreichend geschützt.'
    }

    $credential = Get-Credential -Message 'Anmeldung am UHD Service Desk'
    if (-not $credential) {
        throw 'Anmeldung abgebrochen.'
    }

    $folder = Split-Path -Parent $Path
    if ($folder -and -not (Test-Path -LiteralPath $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    Export-Clixml -LiteralPath $Path -InputObject $credential
    Write-Verbose "Zugangsdaten gespeichert: $Path"

    $credential
}
