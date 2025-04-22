
data "external" "envs" {
  program = [ 
    "${path.root}/templates/env.sh", 
    var.pool_name,
    "-p", var.kvm_host_port, 
    "${var.kvm_host_user}@${var.kvm_host}" 
  ]
}

data "external" "ssh_keyfile" {
  program = [
    "bash", "-c",
    "echo '{\"keyfile\":\"'$(ssh -v -p ${var.kvm_host_port} ${var.kvm_host_user}@${var.kvm_host} echo 2>&1 | grep 'Server accepts key:' | cut -f5 -d' ')'\"}'"
  ]
}
