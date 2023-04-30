# Image Builder on WSL

STATUS: Build successful with non-critical error at post-build clean up stage

```
$ ls -la  image-builder/images/capi/output/windows-2019-kube-v1.24.11/win*
-rwxrwxrwx 1 mloskot mloskot 4713108480 May  3 21:17 image-builder/images/capi/output/windows-2019-kube-v1.24.11/windows-2019-kube-v1.24.11-disk001.vmdk
-rwxrwxrwx 1 mloskot mloskot       8078 May  3 21:10 image-builder/images/capi/output/windows-2019-kube-v1.24.11/windows-2019-kube-v1.24.11.ovf
## Enable WinRM connectivity from Packer on WSL to VirtualBox machine on Windows host
```

On WSL

```
winhostip=$(ipconfig.exe | grep "IPv4 Address" | head -n 1 | cut -d":" -f 2 | tail -n1 | sed -e 's/\s*//g')
```

Patch `packer-windows.json` with

```
      "winrm_host": "<winhostip here>",
      "host_port_min":"4442",
      "host_port_max":"4444",
      "vboxmanage": [
        ["modifyvm", "{{.Name}}", "--nic2", "hostonly"],
        ["modifyvm", "{{.Name}}", "--natpf1", "swdtwinrm4442,tcp,<winhostip here>,4442,,5985"],
        ["modifyvm", "{{.Name}}", "--natpf1", "swdtwinrm4443,tcp,<winhostip here>,4443,,5985"],
        ["modifyvm", "{{.Name}}", "--natpf1", "swdtwinrm4444,tcp,<winhostip here>,4444,,5985"],
```

## Scratchpad

Notes on progress of attempts trying to run `image-builder.sh` workflow on WSL.

Vagrant with [WSL support enabled](https://developer.hashicorp.com/vagrant/docs/other/wsl) by `image-builder.sh`.

VBoxManage_WSL.sh proxy runner from https://github.com/finarfin/wsl-virtualbox

```
$ which vagrant && vagrant --version
/usr/bin/vagrant
Vagrant 2.3.4
```

```
$ which packer && packer --version
/usr/bin/packer
1.8.6
```

```
$ which ansible && ansible --version
/home/mloskot/.local/bin/ansible
ansible [core 2.14.5]
  config file = None
  configured module search path = ['/home/mloskot/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /home/mloskot/.local/lib/python3.10/site-packages/ansible
  ansible collection location = /home/mloskot/.ansible/collections:/usr/share/ansible/collections
  executable location = /home/mloskot/.local/bin/ansible
  python version = 3.10.6 (main, Mar 10 2023, 10:55:28) [GCC 11.3.0] (/usr/bin/python3)
  jinja version = 3.1.2
  libyaml = True
```

```
mloskot:~/sig-windows-dev-tools/experiments/image-builder$ ./VBoxManage_WSL.sh --version
7.0.8r156879
```

```console
mloskot:~/sig-windows-dev-tools/experiments/image-builder$ cat .env
export VBOX_WINDOWS_ISO=/mnt/f/_/software/microsoft/WindowsServer2022/SERVER_EVAL_x64FRE_en-us.iso
```

```console
mloskot:~/sig-windows-dev-tools/experiments/image-builder$ ./image-builder.sh
Enabling Vagrant support for WSL, see https://developer.hashicorp.com/vagrant/docs/other/wsl
SWDT_SETTINGS_FILE: /home/mloskot/sig-windows-dev-tools/settings.local.yaml
IMAGE_BUILDER_FOLDER: image-builder
IMAGE_BUILDER_BRANCH: master
IMAGE_BUILDER_REPO: https://github.com/kubernetes-sigs/image-builder.git
Loading user-specific environment variables from /home/mloskot/sig-windows-dev-tools/experiments/image-builder/.env
Starting galaxy collection install process
Nothing to do. All requested collections are already installed. If you want to reinstall them, consider using `--force`.
~/sig-windows-dev-tools/experiments/image-builder/image-builder/images/capi ~/sig-windows-dev-tools/experiments/image-builder
Already on 'master'
Your branch is up to date with 'origin/master'.
Saving build configuration: /tmp/tmp.8UZP11vH5A
{
  "os_iso_url": "/mnt/f/_/software/microsoft/WindowsServer2022/SERVER_EVAL_x64FRE_en-us.iso",
  "runtime": "containerd",
  "ansible_extra_vars": "custom_role=true load_additional_components=true additional_registry_images=true additional_registry_images_list=docker.io/stefanscherer/whoami:windows-amd64-2.0.2",
  "custom_role_names": "utilities",
  "windows_updates_kbs": "KB5009557",
  "calico_version": "3.25.1",
  "containerd_version": "1.7.0",
  "kubernetes_version": "1.27",
  "kubernetes_series": "v1.27"
}
rm -fr output/windows-2019-kube*
hack/ensure-ansible.sh
Starting galaxy collection install process
Nothing to do. All requested collections are already installed. If you want to reinstall them, consider using `--force`.
hack/ensure-ansible-windows.sh
hack/ensure-packer.sh
hack/ensure-goss.sh
Right version of binary present
packer build -var-file="/home/mloskot/sig-windows-dev-tools/experiments/image-builder/image-builder/images/capi/packer/config/kubernetes.json"  -var-file="/home/mloskot/sig-windows-dev-tools/experiments/image-builder/image-builder/images/capi/packer/config/windows/kubernetes.json"  -var-file="/home/mloskot/sig-windows-dev-tools/experiments/image-builder/image-builder/images/capi/packer/config/containerd.json"  -var-file="/home/mloskot/sig-windows-dev-tools/experiments/image-builder/image-builder/images/capi/packer/config/windows/containerd.json"  -var-file="/home/mloskot/sig-windows-dev-tools/experiments/image-builder/image-builder/images/capi/packer/config/windows/docker.json"  -var-file="/home/mloskot/sig-windows-dev-tools/experiments/image-builder/image-builder/images/capi/packer/config/windows/ansible-args-windows.json"  -var-file="/home/mloskot/sig-windows-dev-tools/experiments/image-builder/image-builder/images/capi/packer/config/common.json"  -var-file="/home/mloskot/sig-windows-dev-tools/experiments/image-builder/image-builder/images/capi/packer/config/windows/common.json"  -var-file="/home/mloskot/sig-windows-dev-tools/experiments/image-builder/image-builder/images/capi/packer/config/windows/cloudbase-init.json"  -var-file="/home/mloskot/sig-windows-dev-tools/experiments/image-builder/image-builder/images/capi/packer/config/goss-args.json"  -var-file="/home/mloskot/sig-windows-dev-tools/experiments/image-builder/image-builder/images/capi/packer/config/additional_components.json"  -color=true -var-file="packer/vbox/packer-common.json" -var-file="/home/mloskot/sig-windows-dev-tools/experiments/image-builder/image-builder/images/capi/packer/vbox/windows-2019.json" -only=virtualbox-iso -var-file="/tmp/tmp.8UZP11vH5A"  packer/vbox/packer-windows.json
Warning: Warning when preparing build: "virtualbox-iso"

A checksum of 'none' was specified. Since ISO files are so big,
a checksum is highly recommended.


virtualbox-iso: output will be in this color.

==> virtualbox-iso: Retrieving ISO
==> virtualbox-iso: Trying /mnt/f/_/software/microsoft/WindowsServer2022/SERVER_EVAL_x64FRE_en-us.iso
==> virtualbox-iso: Trying /mnt/f/_/software/microsoft/WindowsServer2022/SERVER_EVAL_x64FRE_en-us.iso
==> virtualbox-iso: /mnt/f/_/software/microsoft/WindowsServer2022/SERVER_EVAL_x64FRE_en-us.iso => /mnt/f/_/software/microsoft/WindowsServer2022/SERVER_EVAL_x64FRE_en-us.iso
==> virtualbox-iso: Creating floppy disk...
    virtualbox-iso: Copying files flatly from floppy_files
    virtualbox-iso: Copying file: ./packer/vbox/windows/windows-2019/autounattend.xml
    virtualbox-iso: Copying file: ./packer/vbox/windows/enable-winrm.ps1
    virtualbox-iso: Copying file: ./packer/vbox/windows/sysprep.ps1
    virtualbox-iso: Done copying files from floppy_files
    virtualbox-iso: Collecting paths from floppy_dirs
    virtualbox-iso: Resulting paths from floppy_dirs : []
    virtualbox-iso: Done copying paths from floppy_dirs
    virtualbox-iso: Copying files from floppy_content
    virtualbox-iso: Done copying files from floppy_content
==> virtualbox-iso: Creating ephemeral key pair for SSH communicator...
==> virtualbox-iso: Created ephemeral SSH key pair for communicator
==> virtualbox-iso: Creating virtual machine...
==> virtualbox-iso: Creating hard drive output/windows-2019-kube-v1.24.11/windows-2019-kube-v1.24.11.vdi with size 81920 MiB...
==> virtualbox-iso: Mounting ISOs...
    virtualbox-iso: Mounting boot ISO...
==> virtualbox-iso: Deleting any current floppy disk...
==> virtualbox-iso: Attaching floppy disk...
==> virtualbox-iso: Cleaning up floppy disk...
==> virtualbox-iso: Deregistering and deleting VM...
==> virtualbox-iso: Deleting output directory...

Build 'virtualbox-iso' errored after 11 seconds 425 milliseconds: Error attaching floppy: VBoxManage error: VBoxManage.exe: error: Could not find file for the medium 'C:\Users\MateuszL\AppData\Local\Docker\wsl\data\\C\Users\MateuszL\AppData\Local\Docker\wsl\distroC\Users\MateuszL\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState\rootfs\tmp\virtualbox2295419610\floppy.vfd' (VERR_PATH_NOT_FOUND)
VBoxManage.exe: error: Details: code VBOX_E_FILE_ERROR (0x80bb0004), component MediumWrap, interface IMedium, callee IUnknown
VBoxManage.exe: error: Context: "OpenMedium(Bstr(pszFilenameOrUuid).raw(), enmDevType, enmAccessMode, fForceNewUuidOnOpen, pMedium.asOutParam())" at line 201 of file VBoxManageDisk.cpp
VBoxManage.exe: error: Invalid UUID or filename "C:\Users\MateuszL\AppData\Local\Docker\wsl\data\\C\Users\MateuszL\AppData\Local\Docker\wsl\distroC\Users\MateuszL\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState\rootfs\tmp\virtualbox2295419610\floppy.vfd"

==> Wait completed after 11 seconds 425 milliseconds

==> Some builds didn't complete successfully and had errors:
--> virtualbox-iso: Error attaching floppy: VBoxManage error: VBoxManage.exe: error: Could not find file for the medium 'C:\Users\MateuszL\AppData\Local\Docker\wsl\data\\C\Users\MateuszL\AppData\Local\Docker\wsl\distroC\Users\MateuszL\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState\rootfs\tmp\virtualbox2295419610\floppy.vfd' (VERR_PATH_NOT_FOUND)
VBoxManage.exe: error: Details: code VBOX_E_FILE_ERROR (0x80bb0004), component MediumWrap, interface IMedium, callee IUnknown
VBoxManage.exe: error: Context: "OpenMedium(Bstr(pszFilenameOrUuid).raw(), enmDevType, enmAccessMode, fForceNewUuidOnOpen, pMedium.asOutParam())" at line 201 of file VBoxManageDisk.cpp
VBoxManage.exe: error: Invalid UUID or filename "C:\Users\MateuszL\AppData\Local\Docker\wsl\data\\C\Users\MateuszL\AppData\Local\Docker\wsl\distroC\Users\MateuszL\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState\rootfs\tmp\virtualbox2295419610\floppy.vfd"

==> Builds finished but no artifacts were created.
make: *** [Makefile:526: build-vbox-windows-2019] Error 1
```