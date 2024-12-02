# Windows firewall (Close firewell)
$firewallStatus = Get-NetFirewallProfile | Select-Object -Property Name, Enabled
if ($firewallStatus.Enabled -contains 'True') {
    Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False
    Write-Host "Windows firewall closed"
} else {
    Write-Host "Windows firewall has been shut down"
}

# Visual Performance (Adjust best performance)
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force -ErrorAction Stop
}
Set-ItemProperty -Path $regPath -Name VisualFXSetting -Value 2

# Virtual Memory (custom size :4096(initial and maximum) )
Import-Module .\AdjustVirtualMemoryPagingFileSize.psm1
Set-OSCVirtualMemory  -InitialSize 4096  -MaximumSize 4096  -DriveLetter C:

# Remove Windows Defender 
Remove-WindowsFeature -Name Windows-Defender
# Power profile (High Performance)
$powerpolicy = powercfg /GetActiveScheme
if ($powerpolicy.contains("Balanced")) {
    $powerPlanGuid = powercfg -l | Select-String -Pattern "High Performance" |  ForEach-Object { $_.ToString().Trim() -split '\s+' } | Select-Object -Index 3
    powercfg -s $powerPlanGuid
}

# Large page Enable
$file = "C:\secpol.cfg"
secedit /export /cfg $file
$targetLine = "[Privilege Rights]"
$newLine = "SeLockMemoryPrivilege = Administrator"
$lines_array = [System.Collections.ArrayList](Get-Content $file)
$lines = Get-Content $file
$indexOfTargetLine = $lines.IndexOf($targetLine)
if ($indexOfTargetLine -ge 0) {
    $lines_array.Insert($indexOfTargetLine + 1, $newLine)
    $lines_array | Set-Content $file
    secedit /configure /db "secedit.sdb" /cfg $file /areas USER_RIGHTS
}