# Network-Utilities.ps1
# Helper functions for common network diagnostics and operations.

function Test-PortOpen {
    <#
    .SYNOPSIS
        Tests whether a specific TCP port is open on a remote host.
    .PARAMETER Host
        The hostname or IP address to test.
    .PARAMETER Port
        The TCP port number to test.
    .PARAMETER TimeoutMs
        Connection timeout in milliseconds. Default is 1000.
    .EXAMPLE
        Test-PortOpen -Host "192.168.1.1" -Port 443
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Host,

        [Parameter(Mandatory = $true)]
        [int]$Port,

        [int]$TimeoutMs = 1000
    )

    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connect = $tcp.BeginConnect($Host, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($wait -and !$tcp.Client.Connected) { $wait = $false }
        $tcp.Close()
        return $wait
    }
    catch {
        return $false
    }
}

function Get-PublicIP {
    <#
    .SYNOPSIS
        Retrieves the current public IP address of the machine.
    .EXAMPLE
        Get-PublicIP
    #>
    try {
        $response = Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 5
        return $response.ip
    }
    catch {
        Write-Warning "Could not retrieve public IP: $_"
        return $null
    }
}

function Invoke-PingSweep {
    <#
    .SYNOPSIS
        Pings every host in a /24 subnet and returns those that respond.
    .PARAMETER Subnet
        The first three octets of the subnet (e.g. '192.168.1').
    .PARAMETER TimeoutMs
        Ping timeout in milliseconds. Default is 200.
    .EXAMPLE
        Invoke-PingSweep -Subnet "10.0.0"
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Subnet,

        [int]$TimeoutMs = 200
    )

    $online = [System.Collections.Generic.List[string]]::new()
    1..254 | ForEach-Object -Parallel {
        $ip   = "$using:Subnet.$_"
        $ping = New-Object System.Net.NetworkInformation.Ping
        try {
            $reply = $ping.Send($ip, $using:TimeoutMs)
            if ($reply.Status -eq 'Success') {
                $using:online.Add($ip)
            }
        }
        catch { }
    } -ThrottleLimit 50

    return $online | Sort-Object { [version]$_ }
}
