Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:commandScript = $args[0].MyCommand.Path.Replace($PSScriptRoot + '\', '')

function script:Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$msg
    )

    Begin {
        $savedForegroundColor = $host.UI.RawUI.ForegroundColor
        $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
    Process {
        $host.UI.RawUI.ForegroundColor = 'DarkGreen'
        Write-Output ('{0} [{1}] {2}' -f $timestamp, $script:commandScript, $msg)
    }
    End {
        $host.UI.RawUI.ForegroundColor = $savedForegroundColor
    }
}
