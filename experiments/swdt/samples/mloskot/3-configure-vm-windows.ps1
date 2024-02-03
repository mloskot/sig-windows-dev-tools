#Requires -RunAsAdministrator

$sampleWorkDir = '.\experiments\swdt\samples\mloskot'
if (-not (Test-Path -Path $sampleWorkDir -PathType Container)) {
    Write-Error "$sampleWorkDir not found" -ErrorAction Stop
}

$vmName = 'winworker'
if (-not (Get-VM -Name $vmName)) {
    Write-Error "Machine $vmName exists" -ErrorAction Stop
}

$vmAdminUsername = 'Administrator';
$vmAdminPassword = 'K8s@windows';
$vmAdminPasswordSecure = New-Object -TypeName System.Security.SecureString;
$vmAdminPassword.ToCharArray() | ForEach-Object { $vmAdminPasswordSecure.AppendChar($_) };
$vmAdminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $vmAdminUsername, $vmAdminPasswordSecure;

Write-Host "Configuring network on $vmName"
Invoke-Command -VMName $vmName -Credential $vmAdminCredential -ScriptBlock {
    Rename-Computer -NewName 'winworker'; # cannot access variable from outside script block
    New-NetIPAddress -IPAddress 192.168.10.3 -PrefixLength 24 -InterfaceAlias 'Ethernet' -DefaultGateway 192.168.10.1;
    Set-DnsClientServerAddress -ServerAddresses 1.1.1.1, 8.8.8.8 -InterfaceAlias 'Ethernet';
}

Write-Host "Disabling firewall on $vmName"
Invoke-Command -VMName $vmName -Credential $vmAdminCredential -ScriptBlock {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False;
}

Write-Host "Restarting $vmName"
Restart-VM -VMName $vmName -Force -Wait;

Write-Host "Installing SSH on $vmName"
Invoke-Command -VMName $vmName -Credential $vmAdminCredential -ScriptBlock {
    $ProgressPreference = 'SilentlyContinue';
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0;
    Set-Service -Name sshd -StartupType 'Automatic';
    Start-Service sshd;
}

Write-Host "Configuring SSH on $vmName"
Invoke-Command -VMName $vmName -Credential $vmAdminCredential -ScriptBlock {
    $content = Get-Content -Path $env:ProgramData\ssh\sshd_config;
    $content = $content -replace '.*Match Group administrators.*', '';
    $content = $content -replace '.*AuthorizedKeysFile.*__PROGRAMDATA__.*', '';
    Set-Content -Path $env:ProgramData\ssh\sshd_config -Value $content;
}

Write-Host "Deploying SSH public key to $vmName"
ssh-keygen -q -R winworker;
New-Variable -Name publicKeyPath -Value (Join-Path -Path $sampleWorkDir -ChildPath 'ssh.id_rsa.pub')
New-Variable -Name publicKey -Value (Get-Content -Path $publicKeyPath)
$remoteCmd = "powershell New-Item -Force -ItemType Directory -Path C:\Users\Administrator\.ssh; Add-Content -Force -Path C:\Users\Administrator\.ssh\authorized_keys -Value '$publicKey'; icacls.exe ""C:\Users\Administrator\.ssh\authorized_keys "" /inheritance:r /grant ""Administrators:F"" /grant ""SYSTEM:F""; Restart-Service sshd;";
ssh -o StrictHostKeyChecking=no Administrator@winworker $remoteCmd
Remove-Variable -Name publicKey
Remove-Variable -Name publicKeyPath

Write-Host "Setting SSH private key permissions"
$privateKeyPath = (Join-Path -Path $sampleWorkDir -ChildPath 'ssh.id_rsa')
icacls $privateKeyPath /c /t /Inheritance:d
icacls $privateKeyPath /c /t /Grant ${env:UserName}:F
takeown /F $privateKeyPath
icacls $privateKeyPath /c /t /Grant:r ${env:UserName}:F
icacls $privateKeyPath /c /t /Remove:g Administrator "Authenticated Users" BUILTIN\Administrators BUILTIN Everyone System Users

Write-Host "Testing SSH connection to $vmName with public key"
ssh -i $privateKeyPath Administrator@winworker
