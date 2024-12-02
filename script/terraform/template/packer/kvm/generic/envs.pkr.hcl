
data "external" "envs" {
  program = [ 
    "${path.root}/templates/env.sh", 
    var.pool_name,
    "-p", var.kvm_host_port, 
    "-i", var.kvm_host_ssh_pri_key_file, 
    "${var.kvm_host_user}@${var.kvm_host}" 
  ]
}

