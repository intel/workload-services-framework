Enable-PSRemoting -Force
$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My\
New-Item WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $cert.Thumbprint -Force
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item -Path WSMan:\localhost\Service\MaxConcurrentOperationsPerUser -Value 4294967295
Set-Item -Path WSMan:\localhost\Service\MaxConnections -Value 4294967295
netsh advfirewall firewall add rule name='Allow WinRM' dir=in action=allow protocol=TCP localport=${winrm_port}

# if use local disk, The local disk needs to be allocated letters(H start) and partitioned first.
#
$global:letters = 72..90 | ForEach-Object { [char]$_ }
$global:count = 0
$global:labels = "data"

$allDisks = Get-PhysicalDisk | ForEach-Object {
    $physicalDisk = $_
    $disk = Get-Disk -Number $physicalDisk.DeviceId
    [PSCustomObject]@{
        PhysicalDisk = $physicalDisk
        Disk = $disk
    }
}

function Initialize-AndFormatDisks {
    param (
        [Parameter(Mandatory=$true)]
        [System.Object[]]$disks
    )

    foreach ($disk in $disks) {
        $driveLetter = $global:letters[$global:count].ToString()
        $disk |
        Initialize-Disk -PartitionStyle GPT -PassThru |
        New-Partition -UseMaximumSize -DriveLetter $driveLetter |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel "$($global:labels)$($global:count)" -Confirm:$false -Force
        $global:count++
    }

}

$unpartitionedNonSSDs = $allDisks | Where-Object {
    $_.PhysicalDisk.MediaType -ne "SSD" -and 
    $_.Disk.PartitionStyle -eq "raw"
} | Select-Object -ExpandProperty Disk

$localDisk = ${local_disk ? "$true" : "$false"}

if ($localDisk) {
    $unpartitionedNonSSDs = $allDisks | Where-Object {
        $_.PhysicalDisk.MediaType -eq "SSD" -and 
        $_.Disk.PartitionStyle -eq "raw"
    } | Select-Object -ExpandProperty Disk
}

if ($unpartitionedNonSSDs) {
    Initialize-AndFormatDisks -disks $unpartitionedNonSSDs
}

$disks = Get-Disk | Where partitionstyle -eq 'raw' | sort number
Initialize-AndFormatDisks -disks $disks

