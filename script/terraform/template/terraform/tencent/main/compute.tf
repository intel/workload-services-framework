
resource "tencentcloud_key_pair" "default" {
  key_name   = substr(replace("wsf-${var.job_id}", "-", "_"), 0, 25)
  public_key = var.ssh_pub_key
}

resource "tencentcloud_instance" "default" {
  for_each = local.instances

  instance_name = "wsf-${var.job_id}-${each.key}-instance"
  hostname = each.key
  availability_zone = tencentcloud_subnet.default.availability_zone
  image_id = each.value.image!=null?each.value.image:data.tencentcloud_images.search[each.value.profile].images.0.image_id
  instance_type = each.value.instance_type

  allocate_public_ip = true
  internet_max_bandwidth_out = var.internet_bandwidth
  force_delete = true

  system_disk_type = each.value.os_disk_type
  system_disk_size = each.value.os_disk_size

  spot_instance_type = var.spot_instance?"ONE-TIME":null
  instance_charge_type = var.spot_instance?"SPOTPAID":null
  spot_max_price = var.spot_instance?var.spot_price:null
  stopped_mode = "STOP_CHARGING"

  key_ids = [ tencentcloud_key_pair.default.id ]
  vpc_id = tencentcloud_vpc.default.id
  subnet_id = tencentcloud_subnet.default.id

  security_groups = [ tencentcloud_security_group.default.id ]

  user_data = "${data.template_cloudinit_config.default[each.key].rendered}"

  tags = merge(
    var.common_tags,
    {
      Name    = "wsf-${var.job_id}-instance-${each.key}"
      JobId   = var.job_id
    },
  )
}

