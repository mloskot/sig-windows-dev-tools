# Copyright 2020 The Kubernetes Authors.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function script:Write-Log {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$msg)
    $scriptTag = '01-containerd.ps1'
    $timeStamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Write-Output ('{0} [{1}] {2}' -f $timeStamp, $scriptTag, $msg)
}

Write-Log "Starting kubelet"

# From https://github.com/kubernetes-sigs/sig-windows-tools/blob/master/kubeadm/scripts/PrepareNode.ps1
$FileContent = Get-Content -Path "/var/lib/kubelet/kubeadm-flags.env"
$kubeAdmArgs = $FileContent.TrimStart('KUBELET_KUBEADM_ARGS=').Trim('"')

# TODO(mloskot): Turn into splatting
$args = "--cert-dir=$env:SYSTEMDRIVE/var/lib/kubelet/pki",
        "--config=$env:SYSTEMDRIVE/var/lib/kubelet/config.yaml",
        "--bootstrap-kubeconfig=$env:SYSTEMDRIVE/etc/kubernetes/bootstrap-kubelet.conf",
        "--kubeconfig=$env:SYSTEMDRIVE/etc/kubernetes/kubelet.conf",
        "--hostname-override=$(hostname)",
        "--pod-infra-container-image=`"{{ pause_image }}`"",
        "--enable-debugging-handlers",
        "--cgroups-per-qos=false",
        "--enforce-node-allocatable=`"`"",
        "--resolv-conf=`"`""

$kubeletCommandLine = "kubelet.exe " + ($args -join " ") + " $kubeAdmArgs"
Write-Log ("Running {0}" -f $kubeletCommandLine)
Invoke-Expression $kubeletCommandLine
