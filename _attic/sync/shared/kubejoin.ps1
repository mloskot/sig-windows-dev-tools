if(!(Test-Path ("C:\Program Files\containerd\crictl.exe"))) {
    mv "C:\Users\vagrant\crictl.exe" "C:\Program Files\containerd\"
}
stop-service -name kubelet
cp C:\sync\windows\bin\* c:\k

$env:path += ";C:\Program Files\containerd"
[Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
kubeadm join 10.20.30.10:6443 --cri-socket "npipe:////./pipe/containerd-containerd" --token nd92f4.munc4kptzw3hp5wg --discovery-token-ca-cert-hash sha256:717e29deb5adcc2a7a3a41446a1715a505a39a08faa018514defa056055e833e 
