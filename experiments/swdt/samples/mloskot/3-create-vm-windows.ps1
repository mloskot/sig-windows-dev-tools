#Requires -RunAsAdministrator

$sampleWorkDir = '.\experiments\swdt\samples\mloskot'
if (-not (Test-Path -Path $sampleWorkDir -PathType Container)) {
    Write-Error "$sampleWorkDir not found" -ErrorAction Stop
}

$vmName = 'winworker'
if (Get-VM -Name $vmName) {
    Write-Error "Machine $vmName exists" -ErrorAction Stop
}

$vmConfigPath = New-Item -Path $sampleWorkDir -Name $vmName -ItemType Directory -Force;
$vmVhdPath = Join-Path -Path $vmConfigPath -ChildPath 'os.vhdx';
Write-Host "Converting $vmVhdPath"
if (Test-Path -Path $vmVhdPath -PathType Leaf) {
    Remove-Item -Path $vmVhdPath -Force
}
Convert-VHD -Path "$($Env:UserProfile)\Downloads\20348.169.amd64fre.fe_release_svc_refresh.210806-2348_server_serverdatacentereval_en-us.vhd" -DestinationPath $vmVhdPath;

Write-Host "Creating $vmName"
New-VM -Name $vmName -Generation 1 -Switch 'ClusterNatSwitch' -Path $vmConfigPath;
Add-VMHardDiskDrive -VMName $vmName -Path $vmVhdPath -ControllerType IDE -ControllerNumber 0 -ControllerLocation 1;
Set-VMBios -VMName $vmName -StartupOrder @('IDE', 'Floppy', 'LegacyNetworkAdapter', 'CD')
Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $true -MinimumBytes 2GB -StartupBytes 4GB -MaximumBytes 8GB;
Set-VMProcessor -VMName $vmName -Count 2;
Set-VMProcessor -VMName $vmName -ExposeVirtualizationExtensions $true;
Get-VMNetworkAdapter -VMName $vmName | Connect-VMNetworkAdapter -SwitchName 'ClusterNatSwitch';
Get-VMNetworkAdapter -VMName $vmName | Set-VMNetworkAdapter -MacAddressSpoofing On;

Write-Host "Starting $vmName"
Start-VM -Name $vmName;
vmconnect.exe $env:ComputerName $vmName;

Write-Host "Login to $vmName interactively to select keyboard and language, set local Administrator password, accept EULA."
