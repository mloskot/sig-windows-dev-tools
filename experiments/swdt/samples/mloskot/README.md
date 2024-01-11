# Testing Windows on Windows with SWDT CLI

These instructions are dedicated to running and testing the SWDT CLI experiment
on Windows host in order to provision Windows VM and join it to Kubernetes
cluster as a node ready to deploy workloads in Windows containers.

## Prerequisites

- Windows host
- PowerShell 7 > Run as Administrator
- `Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All`
- `ssh-keygen -f .\samples\mloskot\ssh.id_rsa` to generate SSH keys to be deployed to Windows VM for password-less SSH communication
- Downloaded [Windows Server 2022](https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022) VHD

## 1. Create Hyper-V NAT network

Run the following PowerShell commands on Windows host as Administrator.

Windows currently [allows to set up only one NAT network per host](https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/user-guide/setup-nat-network),
hence a generic non-SWDT specific name is picked below:

```powershell
New-VMSwitch -SwitchName 'ClusterNatSwitch' -SwitchType Internal -Notes 'Virtual Switch with NAT used for networking between nodes of hybrid Kubernets cluster, with Internet access.'
```

```powershell
New-NetIPAddress -IPAddress 192.168.10.1 -PrefixLength 24 -InterfaceAlias 'vEthernet (ClusterNatSwitch)'
```

```powershell
New-NetNAT -Name 'ClusterNatNetwork' -InternalIPInterfaceAddressPrefix 192.168.10.0/24
```

```powershell
Add-Content -Path "$($Env:WinDir)\system32\Drivers\etc\hosts" -Value '192.168.10.1 gateway.cluster   gateway     # ClusterNatSwitch IP'
Add-Content -Path "$($Env:WinDir)\system32\Drivers\etc\hosts" -Value '192.168.10.2 master.cluster    master      # Kubernetes Linux node (control-plane)'
Add-Content -Path "$($Env:WinDir)\system32\Drivers\etc\hosts" -Value '192.168.10.3 winworker.cluster winworker   # Kubernetes Windows node'
```

## 2. Create Windows VM

The VHD requires VM generation 1, does not boot for VM generation 2.
Using the official Windows Server VHD to avoid walk through the manual
process of Windows installation from ISO. It will require to complete
initial configuration interactively (i.e. language and keyboard selection,
setting password for Administrator user - use `K8s@windows` as reasonable default).

```powershell
$vmName = 'winworker'
```

```powershell
Convert-VHD -Path D:\mloskot\_iso\WindowsServer2022\20348.169.amd64fre.fe_release_svc_refresh.210806-2348_server_serverdatacentereval_en-us.vhd -DestinationPath ('E:\mloskot\hyperv\disks\{0}.vhdx' -f $vmName);
```

```powershell
New-VM -Name $vmName -Generation 1 -Switch 'ClusterNatSwitch' -Path 'E:\mloskot\hyperv';
Add-VMHardDiskDrive -VMName $vmName -Path ('E:\mloskot\hyperv\disks\{0}.vhdx' -f $vmName) -ControllerType IDE -ControllerNumber 0 -ControllerLocation 1;
Set-VMBios -VMName $vmName -StartupOrder @("IDE", "Floppy", "LegacyNetworkAdapter", "CD")
Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $true -MinimumBytes 2GB -StartupBytes 4GB -MaximumBytes 8GB;
Set-VMProcessor -VMName $vmName -Count 2;
Set-VMProcessor -VMName $vmName -ExposeVirtualizationExtensions $true;
Get-VMNetworkAdapter -VMName $vmName | Connect-VMNetworkAdapter -SwitchName 'ClusterNatSwitch';
Get-VMNetworkAdapter -VMName $vmName | Set-VMNetworkAdapter -MacAddressSpoofing On;
Start-VM -Name $vmName;
vmconnect.exe $env:ComputerName $vmName;
```

## 3. Create Windows VM

The following PowerShell Direct commands are executed directly on the Windows VM.

*TODO(mloskot): Run those commands from within dedicated SWDT CLI command.*

```powershell
$username = "Administrator";
$password = "K8s@windows";
$passwordSecureString = New-Object -TypeName System.Security.SecureString;
$password.ToCharArray() | ForEach-Object { $passwordSecureString.AppendChar($_) };
$vmCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $passwordSecureString;
```

```powershell
Invoke-Command -VMName $vmName -Credential $vmCredential -ScriptBlock {
  Rename-Computer -NewName 'winworker';
  New-NetIPAddress -IPAddress 192.168.0.4 -PrefixLength 24 -InterfaceAlias "Ethernet" -DefaultGateway 192.168.0.1;
  Set-DnsClientServerAddress -ServerAddresses 1.1.1.1,8.8.8.8 -InterfaceAlias "Ethernet";
}
```

[Configure Windows Firewall](https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/configure-with-command-line?tabs=powershell)
to allow all traffic from Linux nodes, including ICMP - Lazy way:

```powershell
Invoke-Command -VMName $vmName -Credential $vmCredential -ScriptBlock {
  Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False;
}
```

Since, currently, SWDT CLI executes commands on remote host via SSH,
it is a good idea to [set up SSH on Windows VM](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse?tabs=powershell),
with key based authentication in the next steps:

```powershell
Invoke-Command -VMName $vmName -Credential $vmCredential -ScriptBlock {
  $ProgressPreference = 'SilentlyContinue'
  Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'
  Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0;
  Set-Service -Name sshd -StartupType 'Automatic';
  Start-Service sshd;
}
```

Fix broken configuration of SSH on Windows:

- https://stackoverflow.com/a/77705199/151641
- https://github.com/PowerShell/Win32-OpenSSH/issues/1942#issuecomment-1868015179

```powershell
Invoke-Command -VMName $vmName -Credential $vmCredential -ScriptBlock {
    $content = Get-Content -Path $env:ProgramData\ssh\sshd_config;
    $content = $content -replace '.*Match Group administrators.*', '';
    $content = $content -replace '.*AuthorizedKeysFile.*__PROGRAMDATA__.*', '';
    Set-Content -Path $env:ProgramData\ssh\sshd_config -Value $content;
}
```

Use SSH to [deploy the public key](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement#deploying-the-public-key) to Windows VM:

```powershell
ssh-keygen -R winworker;
$publicKey = Get-Content -Path .\samples\mloskot\ssh.id_rsa.pub;
$remoteCmd = "powershell New-Item -Force -ItemType Directory -Path C:\Users\Administrator\.ssh; Add-Content -Force -Path C:\Users\Administrator\.ssh\authorized_keys -Value '$publicKey';icacls.exe ""C:\Users\Administrator\.ssh\authorized_keys "" /inheritance:r /grant ""Administrators:F"" /grant ""SYSTEM:F""";
ssh Administrator@winworker $remoteCmd
```

```powershell
Invoke-Command -VMName $vmName -Credential $vmCredential -ScriptBlock {
    Restart-Computer  -Force;
}
```
