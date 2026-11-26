function Get-UHDRequestFid {
    [CmdletBinding()]
    [OutputType([int])]
    param()

    # Entspricht der FID-Erzeugung des Browserclients.
    [int][math]::Round((Get-Random -Minimum 0.0 -Maximum 1.0) * 10000, [MidpointRounding]::AwayFromZero)
}
