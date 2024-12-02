<powershell>
  function Test-DiskIndexExist {
    param (
        [Parameter(Mandatory = $true)]
        [int]$DiskIndex,
        
        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds
    )

    $startTime = Get-Date
    $timeout = $TimeoutSeconds

    while ($true) {
        $disks = @(Get-Disk | Where-Object { $_.Number -eq $DiskIndex })

        if ($disks.Count -gt 0) {
            return $true
        }

        $currentTime = Get-Date
        $elapsedTime = ($currentTime - $startTime).TotalSeconds

        if ($elapsedTime -ge $timeout) {
            return $false
        }

        Start-Sleep -Seconds 1
    }
  }

  Stop-Service -Name ShellHWDetection
  foreach ($i in 0..(${drive_count} - 1)) {
    Get-Disk
    $drive = [char]([int][char]'G' + $i)
    $diskIndex = $i + 1
    $diskIndexExist = Test-DiskIndexExist -DiskIndex $diskIndex -TimeoutSeconds 180
    if ($diskIndexExist) {
      Initialize-Disk -Number $diskIndex -PartitionStyle GPT -Confirm:$false
      New-Partition -DiskNumber $diskIndex -UseMaximumSize -DriveLetter $drive
      Format-Volume -DriveLetter $drive -FileSystem NTFS -NewFileSystemLabel Disk$diskIndex -Force -Confirm:$false 
    }
    else {
      Write-Host "xx $diskIndex"
    }
  }
  Start-Service -Name ShellHWDetection

  Disable-NetFirewallRule -Name WINRM-HTTP-In-TCP
  Disable-NetFirewallRule -Name WINRM-HTTP-In-TCP-PUBLIC
  Get-ChildItem WSMan:\Localhost\listener | Remove-Item -Recurse

  Set-Item -Path WSMan:\LocalHost\Service\AllowUnencrypted -Value false
  Set-Item -Path WSMan:\LocalHost\Service\Auth\Basic -Value true
  Set-Item -Path WSMan:\LocalHost\Service\Auth\CredSSP -Value true

  New-NetFirewallRule -Name WINRM-HTTPS-In-TCP -DisplayName "Windows Remote Management (HTTPS-In)" -Description "Inbound rule for Windows Remote Management via WS-Management. [TCP ${winrm_port}]" -Group "Windows Remote Management" -Program "System" -Protocol TCP -LocalPort "${winrm_port}" -Action Allow -Profile Domain,Private

  New-NetFirewallRule -Name WINRM-HTTPS-In-TCP-PUBLIC -DisplayName "Windows Remote Management (HTTPS-In)" -Description "Inbound rule for Windows Remote Management via WS-Management. [TCP ${winrm_port}]" -Group "Windows Remote Management" -Program "System" -Protocol TCP -LocalPort "${winrm_port}" -Action Allow -Profile Public

  $Hostname = [System.Net.Dns]::GetHostByName((hostname)).HostName.ToUpper()
  $pfx = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName $Hostname
  $certThumbprint = $pfx.Thumbprint
  $certSubjectName = $pfx.SubjectName.Name.TrimStart("CN = ").Trim()

  New-Item -Path WSMan:\LocalHost\Listener -Address * -Transport HTTPS -Hostname $certSubjectName -CertificateThumbPrint $certThumbprint -Port ${winrm_port} -force

  Stop-Service WinRM
  Set-Service WinRM -StartupType Automatic
  Start-Service WinRM


</powershell>
