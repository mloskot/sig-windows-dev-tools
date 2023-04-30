#!/bin/bash
#
# Based on idea found in:
# https://www.wriotsecurity.com/posts/setting-up-wsl-ansible-and-packer-for-devops/
# https://github.com/finarfin/wsl-virtualbox
#
# Get path for WSL storage
#wslroot=$(wslpath $(reg.exe query "HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss" /s /v BasePath | awk 'BEGIN { FS = "[ \t]+" } ; /BasePath/{print $4}' | tr -d "[:cntrl:]"))
# wslroot is no longer used as SWDT must be cloned to Windows host filesystem, not WSL filesystem,
# for realiable TMPDIR access by Packer, see .env
#WSL_DEFAULT_DISTRO=$(reg.exe QUERY 'HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss' /v DefaultDistribution /t REG_SZ | grep -oP 'DefaultDistribution\s+REG_SZ\s+\K{[^\}]+}')
#WSL_DEFAULT_ROOTFS=$(reg.exe QUERY 'HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\'"${WSL_DEFAULT_DISTRO}" /v BasePath /t REG_SZ | grep -oP 'BasePath\s+REG_SZ\s+\K\S.+' | sed -E 's|/*\s*$|\\rootfs|')

# Initialize defaults
is_next_path=0
is_next_adapter=0
vboxmanage_args=()

for argument; do
  # If the current argument is --medium expect path of the medium in next argument
  if [ "$argument" = '--medium' ]; then
    is_next_path=1
  elif [ "$argument" = '--hostonlyadapter2' ]; then
    is_next_adapter=1
  elif [ $is_next_path = 1 ]; then
    # Packer tries to create floppy in the linux /tmp folder which is not representable in Windows. Replace it with direct storage path
    #if [[ $argument == /tmp/* ]]; then
    #  argument="$WSL_DEFAULT_ROOTFS/$argument"
    #fi
    # Convert WSL paths to Windows path
    argument=$(wslpath -w "$argument")
    is_next_path=0
  elif [ $is_next_adapter = 1 ]; then
    # Replace Linux-specific vboxnet0 with adapter available on Windows host
    argument="VirtualBox Host-Only Ethernet Adapter"
    is_next_adapter=0
  fi
  vboxmanage_args+=("\"$argument\"")
done

# Do NOT log to stdout as Packer expects to read VBoxManage stdout, e.g.
# 2023/05/02 20:00:26 packer-builder-virtualbox-iso plugin: VBoxManage --version output: [VBoxManage_WSL.sh] args= "--version"
echo "[VBoxManage_WSL.sh] args= ${vboxmanage_args[@]}" >&2
echo "${vboxmanage_args[@]}" | xargs /mnt/c/Program\ Files/Oracle/VirtualBox/VBoxManage.exe
