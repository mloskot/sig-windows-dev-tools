#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. .\common.ps1 $MyInvocation

Write-Log 'Running Minikube'
$config = Import-PowerShellDataFile -Path .\config.psd1

$cmd = 'minikube config set driver hyperv'
Write-Log $cmd
Invoke-Expression $cmd

$cmd = 'minikube config set driver hyperv'
Write-Log $cmd
Invoke-Expression $cmd

$cmd = ('minikube config set hyperv-virtual-switch "{0}"' -f $config.MinikubeVirtualSwitch)
Write-Log $cmd
Invoke-Expression $cmd

$cmd = ('minikube config set cpus {0}' -f $config.MinikubeCpus)
Write-Log $cmd
Invoke-Expression $cmd

$cmd = ('minikube config set memory {0}' -f $config.MinikubeMemory)
Write-Log $cmd
Invoke-Expression $cmd

$cmd = 'minikube config view'
Write-Log $cmd
Invoke-Expression $cmd

$cmd = ('minikube start --delete-on-failure --nodes {0} --dry-run ' -f $config.MinikubeNodeCount)
Write-Log $cmd
Invoke-Expression $cmd

$cmd = ('minikube start --delete-on-failure --nodes {0}' -f $config.MinikubeNodeCount)
Write-Log $cmd
Invoke-Expression $cmd

$cmd = 'minikube node list'
Write-Log $cmd
Invoke-Expression $cmd

Write-Log 'Done'
