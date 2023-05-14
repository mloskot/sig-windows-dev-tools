Param(
    [parameter(HelpMessage="Kubernetes Version")]
    [string] $kubernetesVersion=""
)

# Force Kubernetes folder
New-Item -Path C:\k -ItemType Directory -Force

# Copy a clean StartKubelet.ps1 configuration for 1.24+
If ([int]$kubernetesVersion.split(".",2)[1] -gt 23) {
    Copy-Item -Path C:\forked\StartKubelet.ps1 -Destination C:\k\StartKubelet.ps1 -Force
}
