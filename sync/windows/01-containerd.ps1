<#
Copyright 2021 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
#>
Param(
    [parameter(HelpMessage="ContainerD Version")]
    [string] $calicoVersion="",
    [string] $containerdVersion=""
)

function script:Write-Log {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$msg)
    $scriptTag = '01-containerd.ps1'
    $timeStamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Write-Output ('{0} [{1}] {2}' -f $timeStamp, $scriptTag, $msg)
}

Write-Log "Installing ContainerD $containerdVersion"

Write-Log "Stopping container service"
Stop-Service containerd -Force

Write-Log "Copying C:\sync\windows\download\Install-Containerd.ps1 to C:\Install-Containerd.ps1"
Copy-Item C:\sync\windows\download\Install-Containerd.ps1 C:\Install-Containerd.ps1

Write-Log "Running C:\Install-Containerd.ps1"
C:\Install-Containerd.ps1 -ContainerDVersion $containerdVersion -CNIConfigPath "c:/etc/cni/net.d" -CNIBinPath "c:/opt/cni/bin"
