#!/bin/bash

# Copyright 2021 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

[[ -n ${DEBUG:-} ]] && set -o xtrace

if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    if [[ -z "${VAGRANT_WSL_ENABLE_WINDOWS_ACCESS:-}" ]]; then
        echo "Enabling Vagrant support for WSL, see https://developer.hashicorp.com/vagrant/docs/other/wsl"
        if [[ ! -d "/mnt/c/Program Files/Oracle/VirtualBox" ]]; then
            echo "ERROR: Required Windows installation of VirtualBox does not exist. Folder '/mnt/c/Program Files/Oracle/VirtualBox' not found."
            exit 1
        fi
        # Add VBoxManage script to PATH
        cp ${PWD}/VBoxManage_WSL.sh ${PWD}/VBoxManage
        PATH="$PATH:${PWD}"
        VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
    fi
fi

for tool in ansible jq packer vagrant yq
do
    if ! command -v "${tool}" &> /dev/null; then
        echo "ERROR Required program ${tool} not found"
        exit 1
    fi
done

SWDT_ROOT=$(realpath "$(dirname "$0")"/../..)
SWDT_SETTINGS_FILE=${SWDT_SETTINGS_FILE:-${SWDT_ROOT}/settings.local.yaml}
if [[ ! -f ${SWDT_SETTINGS_FILE} ]]; then
    SWDT_SETTINGS_FILE=${SWDT_ROOT}/settings.yaml
fi
echo "SWDT_SETTINGS_FILE: $SWDT_SETTINGS_FILE"

tmpfile=$(mktemp)
OVERLAYS_FOLDER=${ROOT_OVERLAYS:-${PWD}/overlays}

IMAGE_BUILDER_FOLDER="${IMAGE_BUILDER_FOLDER:-image-builder}"
echo "IMAGE_BUILDER_FOLDER: $IMAGE_BUILDER_FOLDER"
IMAGE_BUILDER_BRANCH="${IMAGE_BUILDER_BRANCH:-master}"
echo "IMAGE_BUILDER_BRANCH: $IMAGE_BUILDER_BRANCH"
IMAGE_BUILDER_REPO="${IMAGE_BUILDER_REPO:-https://github.com/kubernetes-sigs/image-builder.git}"
echo "IMAGE_BUILDER_REPO: $IMAGE_BUILDER_REPO"
CAPI_IMAGES_PATH=${IMAGE_BUILDER_FOLDER}/images/capi

CONTAINERD_PREPULL_IMAGES=${CONTAINERD_PREPULL_IMAGES:-docker.io/stefanscherer/whoami:windows-amd64-2.0.2}  # comma separated
ANSIBLE_VARS="custom_role=true load_additional_components=true additional_registry_images=true additional_registry_images_list=${CONTAINERD_PREPULL_IMAGES}"

# Settings and building configuration file from SWDT settings file
SWDT_CALICO_VERSION=$(yq '.calico_version' ${SWDT_SETTINGS_FILE})
SWDT_CONTAINERD_VERSION=$(yq '.containerd_version' ${SWDT_SETTINGS_FILE})
SWDT_KUBERNETES_VERSION=$(yq '.kubernetes_version' ${SWDT_SETTINGS_FILE})

# Settings and building configuration file from environment variables
if [[ -f "${PWD}/.env" ]]; then
    echo "Loading user-specific environment variables from ${PWD}/.env"
    source ${PWD}/.env
fi
VBOX_WINDOWS_ISO="${VBOX_WINDOWS_ISO:-file:/tmp/windows.iso}"
VBOX_WINDOWS_RUNTIME="${VBOX_WINDOWS_RUNTIME:-containerd}"
VBOX_WINDOWS_ROLES=${VBOX_WINDOWS_CUSTOM_ROLES:-utilities}

function clean {
    rm -f ${tmpfile}
}


function build_configuration {
  echo "Saving build configuration: ${tmpfile}"
  jq --null-input \
    --arg iso_url "${VBOX_WINDOWS_ISO}"                 \
    --arg runtime "${VBOX_WINDOWS_RUNTIME}"             \
    --arg custom_role_names "${VBOX_WINDOWS_ROLES}"     \
    --arg ansible_extra_vars "${ANSIBLE_VARS}"          \
    --arg windows_updates_kbs "KB5009557"               \
    --arg calico_version "${SWDT_CALICO_VERSION}"   \
    --arg containerd_version "${SWDT_CONTAINERD_VERSION}"   \
    --arg kubernetes_version "${SWDT_KUBERNETES_VERSION}"   \
    --arg kubernetes_series "v${SWDT_KUBERNETES_VERSION}"   \
    '{
        "os_iso_url": $iso_url,
        "runtime": $runtime,
        "ansible_extra_vars": $ansible_extra_vars,
        "custom_role_names": $custom_role_names,
        "windows_updates_kbs": $windows_updates_kbs,
        "calico_version": $calico_version,
        "containerd_version": $containerd_version,
        "kubernetes_version": $kubernetes_version,
        "kubernetes_series": $kubernetes_series,
    }' > ${tmpfile}
  cat ${tmpfile}
}

function copy_overlay_files {
    # Overlay copy
    cp -r ${OVERLAYS_FOLDER}/ansible/roles/utilities ./ansible/windows/roles/
    cp ${OVERLAYS_FOLDER}/autounattend.xml ./packer/vbox/windows/windows-2019/autounattend.xml  
    cp ${OVERLAYS_FOLDER}/vm-guest-tools.ps1 ./packer/vbox/windows/vm-guest-tools.ps1
    cp ${OVERLAYS_FOLDER}/packer-windows.json ./packer/vbox/packer-windows.json
}

# adding the choco package manager plugin to ansible (see https://community.chocolatey.org/packages)
ansible-galaxy collection install chocolatey.chocolatey

# Cloning the image-builder repository
[[ ! -d ${IMAGE_BUILDER_FOLDER} ]] && git clone ${IMAGE_BUILDER_REPO} ${IMAGE_BUILDER_FOLDER}

# Build local virtualbox artifact
pushd ${CAPI_IMAGES_PATH}
    hack/ensure-jq.sh
    git checkout ${IMAGE_BUILDER_BRANCH}

    build_configuration
    copy_overlay_files

    make clean-vbox
    PACKER_VAR_FILES="${tmpfile}" make build-vbox-windows-2019
popd

clean
