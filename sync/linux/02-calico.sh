#!/bin/bash
#set -e
ME="02-calico.sh" # $(basename "$0") reports vagrant-shell instead of script name
function echolog
{
    echo "$(printf '%(%F %T)T') [${ME}] $*" >&2
}


if [[ "$1" == "" || "$2" == ""  ]]; then
  cat << EOF
  Missing args.
  You need to send pod_cidr and calico version i.e.
  ${ME} 100.244.0.0/16 3.25.0
  Normally these are in your settings.yml, and piped in by Vagrant.
  So, check that you didn't break the Vagrantfile :)
EOF
  exit 1
fi

pod_cidr=${1}
calico_version=${2}
echolog "Running Calico ${calico_version} installer with pod_cidr ${pod_cidr}"

sleep 2
export KUBECONFIG=/home/vagrant/.kube/config

echolog "Tainting nodes"
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
kubectl taint nodes --all node-role.kubernetes.io/master-

calico_url="https://raw.githubusercontent.com/projectcalico/calico/v${calico_version}/manifests/tigera-operator.yaml"
echolog "Applying Calico manifest ${calico_url}"
kubectl create ns calico-system
kubectl create -f "${calico_url}"

calico_url="https://raw.githubusercontent.com/projectcalico/calico/v${calico_version}/manifests/custom-resources.yaml"
echolog "Applying Calico manifest ${calico_url}"
wget "${calico_url}" -O trigera-custom-resource.yaml
sed -i "s|cidr: 192.168.0.0/16|cidr: ${pod_cidr}|g" trigera-custom-resource.yaml
kubectl create -f trigera-custom-resource.yaml

echolog "Ensureing that BGP is disabled since we are using VXLAN"
kubectl patch installation default --type=merge -p '{"spec": {"calicoNetwork": {"bgp": "Disabled"}}}'

echolog "Waiting 20s for Calico pods..."
sleep 20

calico_url="https://raw.githubusercontent.com/projectcalico/calico/v${calico_version}/manifests/calico-windows-vxlan.yaml"
echolog "Applying manifest ${calico_url}"
wget "${calico_url}" -O calico-windows.yaml
k8s_service_host=$(kubectl get endpoints kubernetes -n default -o jsonpath='{.subsets[0].addresses[0].ip}')
k8s_service_port=$(kubectl get endpoints kubernetes -n default -o jsonpath='{.subsets[0].ports[0].port}')
sed -i "s|KUBERNETES_SERVICE_HOST: \"\"|KUBERNETES_SERVICE_HOST: \"$k8s_service_host\"|g" calico-windows.yaml
sed -i "s|KUBERNETES_SERVICE_PORT: \"\"|KUBERNETES_SERVICE_PORT: \"$k8s_service_port\"|g" calico-windows.yaml
kubectl create -f calico-windows.yaml

echolog "Copying calicoctl to /usr/bin/calicoctl"
sudo cp -f /var/sync/linux/download/calicoctl /usr/bin/
sudo chmod +x /usr/bin/calicoctl

echolog "Running calicoctl version"
/usr/bin/calicoctl version

# From https://docs.tigera.io/calico/latest/getting-started/kubernetes/windows-calico/quickstart
# For Linux control nodes using Calico networking, strict affinity must be set to true.
# This is required to prevent Linux nodes from borrowing IP addresses from Windows nodes:
echolog "Running calicoctl ipam configure"
/usr/bin/calicoctl ipam configure --strictaffinity=true

echolog "Listing Calico pods"
kubectl get pods -n calico-system
