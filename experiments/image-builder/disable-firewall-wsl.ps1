#Requires -RunAsAdministrator
Set-NetFirewallProfile -Profile Domain-DisabledInterfaceAliases "vEthernet (WSL)"
Set-NetFirewallProfile -Profile Private -DisabledInterfaceAliases "vEthernet (WSL)"
Set-NetFirewallProfile -Profile Public -DisabledInterfaceAliases "vEthernet (WSL)"
#Set-NetFirewallProfile -Profile Public -DisabledInterfaceAliases "vEthernet (WSL)" -LogBlocked True
# Get-Content C:\WINDOWS\system32\LogFiles\Firewall\pfirewall.log -Tail 15 -Wait
