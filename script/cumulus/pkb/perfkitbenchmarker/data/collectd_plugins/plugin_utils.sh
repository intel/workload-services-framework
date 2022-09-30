#!/bin/bash

LINUX_DISTRIBUTION=`python -c 'import platform; print (platform.dist()[0].lower())'`
KERNEL=`uname -r`

function is_ubuntu() {
  # 0 = true ; 1 = false
  if [ $LINUX_DISTRIBUTION = "ubuntu" ]; then
    return 0
  fi
  return 1
}

function is_centos() {
  if [ $LINUX_DISTRIBUTION = "centos" ]; then
    return 0
  fi
  if [ $LINUX_DISTRIBUTION = "redhat" ]; then
      return 0
  fi
  return 1
}

function get_kernel_version() {
  return $KERNEL
}
