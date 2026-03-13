# File-System-Helpers.ps1
# A collection of utility functions for common file system tasks.

function Get-FilesOlderThan {
    <#
    .SYNOPSIS
        Returns a list of files in a directory that are older than a specified number of days.
    .PARAMETER Path
        The directory path to search in.
    .PARAMETER Days
        The age threshold in days. Files older than this will be returned.
    .EXAMPLE
        Get-FilesOlderThan -Path "C:\Logs" -Days 30
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [int]$Days
    )

    $cutoff = (Get-Date).AddDays(-$Days)
    Get-ChildItem -Path $Path -File -Recurse |
        Where-Object { $_.LastWriteTime -lt $cutoff }
}

function Remove-OldLogs {
    <#
    .SYNOPSIS
        Deletes log files older than a given number of days.
    .PARAMETER LogPath
        The directory containing log files.
    .PARAMETER RetentionDays
        How many days to keep logs. Default is 90.
    .EXAMPLE
        Remove-OldLogs -LogPath "C:\Logs" -RetentionDays 60
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogPath,

        [int]$RetentionDays = 90
    )

    $oldFiles = Get-FilesOlderThan -Path $LogPath -Days $RetentionDays
    $count = 0
    foreach ($file in $oldFiles) {
        Remove-Item -Path $file.FullName -Force
        $count++
    }
    Write-Host "Removed $count log files older than $RetentionDays days from '$LogPath'."
}

function Copy-FileWithTimestamp {
    <#
    .SYNOPSIS
        Copies a file and appends a timestamp to the destination filename.
    .PARAMETER Source
        Path to the source file.
    .PARAMETER DestinationFolder
        Folder where the timestamped copy will be placed.
    .EXAMPLE
        Copy-FileWithTimestamp -Source "C:\config.json" -DestinationFolder "C:\Backups"
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$DestinationFolder
    )

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $leaf = [System.IO.Path]::GetFileNameWithoutExtension($Source)
    $ext  = [System.IO.Path]::GetExtension($Source)
    $dest = Join-Path $DestinationFolder "$leaf`_$timestamp$ext"

    Copy-Item -Path $Source -Destination $dest -Force
    Write-Host "Copied '$Source' -> '$dest'"
}
