#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. .\common.ps1 $MyInvocation

$hypervState = (Get-WindowsOptionalFeature -Online -FeatureName:Microsoft-Hyper-V).State
if ($hypervState -eq 'Enabled') {
    Write-Log 'Microsoft-Hyper-V feature already enabled'
}

if ($hypervState -eq 'Disabled') {
    $r = (Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart)
    $r | Format-List

    if ($r.RestartNeeded) {
        Write-Log 'Restart and continue running next script in the queue'
    }
}
