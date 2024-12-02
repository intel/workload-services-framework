
locals {
  ssh_config = join(" ", [
    "-o TCPKeepAlive=yes",
    "-o CheckHostIP=no",
    "-o StrictHostKeyChecking=no",
    "-o UserKnownHostsFile=/dev/null",
    "-o IdentitiesOnly=yes",
    "-o PreferredAuthentications=publickey",
    "-o PasswordAuthentication=no",
    "-o ConnectTimeout=20",
    "-o GSSAPIAuthentication=no",
    "-o ServerAliveInterval=30",
    "-o ServerAliveCountMax=10",
  ])
}

