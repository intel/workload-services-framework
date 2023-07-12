Enable-PSRemoting -Force
$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My\
New-Item WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $cert.Thumbprint -Force
Set-Item -Path 'WSMan:\localhost\Service\Auth\Basic' -Value $true
netsh advfirewall firewall add rule name='Allow WinRM' dir=in action=allow protocol=TCP localport=${winrm_port}
