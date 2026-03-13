# Service-Management.ps1
# Functions for querying and managing Windows services.

function Get-StoppedServices {
    <#
    .SYNOPSIS
        Returns all services that are set to start automatically but are currently stopped.
    .EXAMPLE
        Get-StoppedServices
    #>
    Get-Service |
        Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -eq 'Stopped' }
}

function Restart-ServiceWithLogging {
    <#
    .SYNOPSIS
        Restarts a named service and writes the result to a log file.
    .PARAMETER ServiceName
        The name of the service to restart.
    .PARAMETER LogFile
        Path to the log file. Defaults to 'C:\Logs\service-restart.log'.
    .EXAMPLE
        Restart-ServiceWithLogging -ServiceName "Spooler"
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,

        [string]$LogFile = "C:\Logs\service-restart.log"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    try {
        Restart-Service -Name $ServiceName -Force -ErrorAction Stop
        $message = "$timestamp  [OK]  '$ServiceName' restarted successfully."
    }
    catch {
        $message = "$timestamp  [ERROR]  Failed to restart '$ServiceName': $_"
    }

    Write-Host $message
    Add-Content -Path $LogFile -Value $message
}

function Wait-ForService {
    <#
    .SYNOPSIS
        Polls a service until it reaches the desired status or a timeout is hit.
    .PARAMETER ServiceName
        Name of the service to monitor.
    .PARAMETER DesiredStatus
        The status to wait for (e.g. 'Running', 'Stopped'). Default is 'Running'.
    .PARAMETER TimeoutSeconds
        Maximum number of seconds to wait. Default is 60.
    .EXAMPLE
        Wait-ForService -ServiceName "wuauserv" -DesiredStatus "Running" -TimeoutSeconds 120
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,

        [string]$DesiredStatus = "Running",

        [int]$TimeoutSeconds = 60
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq $DesiredStatus) {
            Write-Host "'$ServiceName' reached status '$DesiredStatus' after $([math]::Round($stopwatch.Elapsed.TotalSeconds, 1))s."
            return $true
        }
        Start-Sleep -Seconds 2
    }
    Write-Warning "Timeout: '$ServiceName' did not reach '$DesiredStatus' within $TimeoutSeconds seconds."
    return $false
}
