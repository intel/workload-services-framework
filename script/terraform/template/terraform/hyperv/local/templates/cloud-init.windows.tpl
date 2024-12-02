#cloud-config
groups:
  - cloud-users
users:
  - 
    name: Administrator
    primary_group: Administrators
    passwd: '${password}'
  - 
    name: ${user}
    primary_group: Users
    groups: [ 'cloud-users', 'Administrators' ]
    passwd: '${password}'
    inactive: False
    expiredate: '9999-12-31'
set_hostname: '${host_name}'
write_files:
  path: C:\cloud-init.ps1
  content: |
    function Set-Proxy($proxy, $bypass) {
      $registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"
      Set-ItemProperty -Path $registryPath -Name ProxySettingsPerUser -Value 0

      $registryPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
      Set-ItemProperty -Path $registryPath -Name ProxyServer -Value $proxy
      Set-ItemProperty -Path $registryPath -Name ProxyEnable -Value 1
      Set-ItemProperty -Path $registryPath -Name ProxyOverride -Value $bypass

      $proxyBytes = [system.Text.Encoding]::ASCII.GetBytes($proxy)
      $bypassBytes = [system.Text.Encoding]::ASCII.GetBytes($bypass)
      $defaultConnectionSettings = [byte[]]@(@(70,0,0,0,0,0,0,0,11,0,0,0,$proxyBytes.Length,0,0,0)+$proxyBytes+@($bypassBytes.Length,0,0,0)+$bypassBytes+ @(1..36 | % {0}))
      Set-ItemProperty -Path "$registryPath\Connections" -Name DefaultConnectionSettings -Value $defaultConnectionSettings

      netsh winhttp set proxy proxy-server=$proxy bypass-list=$bypass
    }
    Set-Proxy "http=${http_proxy};https=${https_proxy}" "${no_proxy}"
%{ for i,drive in drives ~}
    Initialize-Disk -Number ${i+1} -PartitionStyle GPT -Confirm:$false
    New-Partition -DiskNumber ${i+1} -UseMaximumSize -DriveLetter ${drive}
    Format-Volume -DriveLetter ${drive} -FileSystem NTFS -NewFileSystemLabel Disk${i+1} -Force -Confirm:$false
%{ endfor ~}
    Set-Item -Path WSMan:\localhost\Service\MaxConcurrentOperationsPerUser -Value 4294967295
    Set-Item -Path WSMan:\localhost\Service\MaxConnections -Value 4294967295
runcmd:
- powershell -File C:\cloud-init.ps1
