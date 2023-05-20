: '
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
'

set -e

echo "ARGS: $1 $2 $3"
if [[ "$1" == "" || "$2" == "" || "$3" == "" ]]; then
  cat << EOF
    Missing args.
    You need to send kubernetes_version, k8s_kubelet_nodeip and pod_cidr i.e.
    ./controlplane.sh 1.21 10.20.30.10 100.244.0.0/16
    Normally these are in your variables.yml, and piped in by Vagrant.
    So, check that you didn't break the Vagrantfile :)
    BTW the only reason this error message is fancy is because friedrich said we should be curteous to people who want to
    copy paste this code from the internet and reuse it.
EOF
  exit 1
fi

kubernetes_version=${1}
k8s_kubelet_node_ip=${2}
pod_cidr=${3}
k8s_linux_apiserver="stable-${kubernetes_version}"

if [[ "$3" == "" ]]; then
  pod_cidr="100.244.0.0/16"
fi

echo "Using $kubernetes_version as the Kubernetes version"

# Installing packages

# Add GPG keys and repository for Kubernetes
echo "Setting up internet connectivity to /etc/resolv.conf"
cat <<EOF | sudo tee /etc/resolv.conf
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

echo "now curling to add keys..."
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat << EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

echo "SWDT: Running apt get update -y"
sudo apt-get update -y
# Disable swap
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

echo "SWDT: Running modprobes"
sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# Install Kubernetes binaries, using latest available, and
# overwritting the binaries later.

echo "SWDT installing kubelet, kubeadm, kubectl will overwrite them later as needeed..." 
sudo apt-get install -y kubelet kubeadm kubectl

sudo apt-mark hold kubelet kubeadm kubectl

# Install containerd - latest version
echo "Configuring Containerd"
sudo apt-get install \
    ca-certificates \
    gnupg \
    lsb-release -y

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

sudo apt-get install containerd.io

## Test if binaries folder exists
#if $overwrite_linux_bins ; then
for BIN in kubeadm kubectl kubelet
do
  file="/var/sync/linux/download/$BIN"
  if [ -f $file ]; then
    echo "copying $file to node path.."
    sudo cp $file /usr/bin/ -f
    sudo chmod +x /usr/bin/$BIN
  fi
done

# Configuring and starting containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock

cat << EOF > /var/sync/shared/kubeadm.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: $k8s_kubelet_node_ip
nodeRegistration:
  kubeletExtraArgs:
    node-ip: $k8s_kubelet_node_ip
    cgroup-driver: cgroupfs
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: $k8s_linux_apiserver
networking:
  podSubnet: "${pod_cidr}"
EOF

# Ignore kubelet mismatch in the copy process
sudo kubeadm init --config=/var/sync/shared/kubeadm.yaml --v=6 --ignore-preflight-errors=KubeletVersion

#to start the cluster with the current user:
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

rm -f /var/sync/shared/config
cp $HOME/.kube/config /var/sync/shared/config

######## MAKE THE JOIN FILE FOR WINDOWS ##########
######## MAKE THE JOIN FILE FOR WINDOWS ##########
######## MAKE THE JOIN FILE FOR WINDOWS ##########
rm -f /var/sync/shared/kubejoin.ps1

cat << EOF > /var/sync/shared/kubejoin.ps1
# Downloaded is newer
if((Test-Path ("C:\sync\windows\download\crictl.exe"))) {
    cp "C:\sync\windows\download\crictl.exe" "C:\Program Files\containerd\"
}
# Box-burned fallback
if((Test-Path ("C:\Users\vagrant\crictl.exe"))) {
    cp "C:\Users\vagrant\crictl.exe" "C:\Program Files\containerd\"
}
stop-service -name kubelet
cp C:\sync\windows\download\k* c:\k

\$env:path += ";C:\Program Files\containerd"
[Environment]::SetEnvironmentVariable("Path", \$env:Path, [System.EnvironmentVariableTarget]::Machine)
EOF

kubeadm token create --print-join-command >> /var/sync/shared/kubejoin.ps1

sed -i 's#--token#--cri-socket "npipe:////./pipe/containerd-containerd" --token#g' /var/sync/shared/kubejoin.ps1

cat << EOF > kube-proxy-and-antrea.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app: kube-proxy
  name: kube-proxy-windows
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: node:kube-proxy
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:node-proxier
subjects:
- kind: Group
  name: system:node
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: system:nodes
  apiGroup: rbac.authorization.k8s.io
- kind: ServiceAccount
  name: kube-proxy-windows
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: node:god2
  namespace: kube-system
subjects:
- kind: User
  name: system:node:winw1
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: node:god3
  namespace: kube-system
subjects:
- kind: Group
  name: system:nodes
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: node:god4
  namespace: kube-system
subjects:
- kind: User
  name: system:serviceaccount:kube-system:kube-proxy-windows
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl create -f kube-proxy-and-antrea.yaml

echo "Testing controlplane nodes!"

kubectl get pods -A
