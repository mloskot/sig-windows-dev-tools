Param(
    [parameter(HelpMessage="Kubernetes Version")]
    [string] $kubernetesVersion=""
)

function script:Write-Log {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$msg)
    $scriptTag = '01-containerd.ps1'
    $timeStamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Write-Output ('{0} [{1}] {2}' -f $timeStamp, $scriptTag, $msg)
}

Write-Log "Creating C:\k directory"
New-Item -Path C:\k -ItemType Directory -Force

# Copy a clean StartKubelet.ps1 configuration for 1.24+
If ([int]$kubernetesVersion.split(".",2)[1] -gt 23) {
    Write-Log "Copying C:\forked\StartKubelet.ps1 to C:\k\StartKubelet.ps1"
    Copy-Item -Path C:\forked\StartKubelet.ps1 -Destination C:\k\StartKubelet.ps1 -Force
}
