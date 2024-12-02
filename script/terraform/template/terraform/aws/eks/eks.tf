#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

resource "aws_key_pair" "default" {
  key_name   = "wsf-${var.job_id}-key"
  public_key = var.ssh_pub_key
}

resource "aws_iam_role" "cluster" {
  name = "wsf-${var.job_id}-cluster-role"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role" "node_group" {
  name = "wsf-${var.job_id}-node-group-role"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "cwr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

locals {
  eks_cluster_name = "wsf-${var.job_id}-cluster"
}

resource "aws_eks_cluster" "default" {
  name = local.eks_cluster_name
  version = var.k8s_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    endpoint_private_access = false
    endpoint_public_access = true
    #public_access_cidrs = concat(var.sg_whitelist_cidr_blocks, [
    #  var.vpc_cidr_block
    #])
    security_group_ids = [ aws_default_security_group.default.id ]
    subnet_ids = [ for s in aws_subnet.default : s.id ]
  }

  kubernetes_network_config {
    service_ipv4_cidr = var.service_network_cidr
    ip_family = "ipv4"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster
  ]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${local.region} --name ${self.name}"
  }
}

resource "aws_launch_template" "default" {
  for_each = local.instances

  name = "wsf-${var.job_id}-template-${each.key}"
  key_name = aws_key_pair.default.key_name
  image_id = each.value.os_image!=null?data.aws_ami.custom[each.key].image_id:data.aws_ami.search[each.key].image_id
  user_data = data.template_cloudinit_config.default[each.key].rendered

  dynamic "block_device_mappings" {
    for_each = { 
      sort([ for k in each.value.os_image!=null?data.aws_ami.custom[each.key].block_device_mappings:data.aws_ami.search[each.key].block_device_mappings: k.device_name ])[0] = true
    }

    content {
      device_name = block_device_mappings.key

      ebs {
        delete_on_termination = true
        volume_size = each.value.os_disk_size
        volume_type = each.value.os_disk_type
        throughput  = each.value.os_disk_throughput
        iops        = each.value.os_disk_iops
      }
    }
  }

  vpc_security_group_ids = concat([
    aws_default_security_group.default.id,
  ], [
    for c in aws_eks_cluster.default.vpc_config: c.cluster_security_group_id
  ])
  
  cpu_options {
    core_count = each.value.cpu_core_count
    threads_per_core = each.value.threads_per_core
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.common_tags, {
      Name = "wsf-${var.job_id}-${each.key}"
    })
  }

  tags = {
    Name = "wsf-${var.job_id}-templete-${each.key}"
  }
}

resource "aws_eks_node_group" "default" {
  for_each = local.instances

  cluster_name = aws_eks_cluster.default.name
  node_group_name = "wsf-${var.job_id}-node-group-${each.key}"
  node_role_arn = aws_iam_role.node_group.arn
  subnet_ids = [ for s in aws_subnet.default : s.id ]
  #version = var.k8s_version

  scaling_config {
    desired_size = 1
    max_size = 1
    min_size = 1
  }

  capacity_type = var.spot_instance?"SPOT":"ON_DEMAND"
  instance_types = [ each.value.instance_type ]

  launch_template {
    id = aws_launch_template.default[each.key].id
    version = aws_launch_template.default[each.key].latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.cwr_policy,
    aws_iam_role_policy_attachment.cni_policy,
  ]

  tags = {
    Name = "wsf-${var.job_id}-node-group-${each.key}"
  }
}

data "aws_instance" "default" {
  for_each = local.instances

  instance_tags = {
    Name = "wsf-${var.job_id}-${each.key}"
  }

  filter {
    name   = "tag:eks:cluster-name"
    values = [aws_eks_cluster.default.name]
  }

  depends_on = [ aws_eks_node_group.default ]
}

