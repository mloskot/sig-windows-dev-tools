#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. .\common.ps1 $MyInvocation

$config = Import-PowerShellDataFile -Path .\config.psd1

if (Get-VMSwitch -SwitchName $config.MinikubeVirtualSwitch) {
    Write-Log ("Hyper-V Virtual Switch '{0}' exists" -f $config.MinikubeVirtualSwitch)
    return
}

Write-Log ("Creating Hyper-V Virtual Switch '{0}'" -f $config.MinikubeVirtualSwitch)
New-VMSwitch `
    -SwitchName $config.MinikubeVirtualSwitch `
    -SwitchType Internal `
    -Notes 'Hyper-V Virtual Switch with NAT used for Minikube nodes networking.'
