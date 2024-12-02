
locals {
  architecture_name = lower(replace(var.architecture, "_", "-"))

  instance_type = (local.architecture_name == "amd64")?replace(var.instance_type, "e2-small", "t2a-standard-2"):var.instance_type
}

