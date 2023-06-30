#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
ifelse("defn(`TEST_CASE')","virtIO",`dnl
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: defn(`PVC_NAME')-1
spec:
  storageClassName: rook-ceph-block
  volumeMode: Block
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: defn(`PVC_BLOCK_SIZE')
---
ifelse("eval(defn(`RBD_IMAGE_NUM') > 1)","1",`dnl
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: defn(`PVC_NAME')-2
spec:
  storageClassName: rook-ceph-block
  volumeMode: Block
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: defn(`PVC_BLOCK_SIZE')
---
',)dnl
ifelse("eval(defn(`RBD_IMAGE_NUM') > 2)","1",`dnl
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: defn(`PVC_NAME')-3
spec:
  storageClassName: rook-ceph-block
  volumeMode: Block
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: defn(`PVC_BLOCK_SIZE')
---
',)dnl
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  labels:
    kubevirt.io/vm: ubuntu
  name: defn(`VM_NAME')
spec:
  running: true
  template:
    metadata:
      labels:
        kubevirt.io/vm: ubuntu
    spec:
      domain:
        devices:
          disks:
          - disk:
              bus: virtio
            name: containerdisk
          - disk:
              bus: virtio
            name: cloudinitdisk
          - disk:
              bus: virtio
            name: block-disk1
ifelse("eval(defn(`RBD_IMAGE_NUM') > 1)","1",`dnl
          - disk:
              bus: virtio
            name: block-disk2
',)dnl
ifelse("eval(defn(`RBD_IMAGE_NUM') > 2)","1",`dnl
          - disk:
              bus: virtio
            name: block-disk3
',)dnl
        cpu:
          cores: defn(`VM_CPU_NUM')
          sockets: 1
ifelse("defn(`CPU_PLACEMENT')","1",`dnl
          dedicatedCpuPlacement: true
',)dnl
        machine:
          type: ""
        resources:
          limits:
            memory: defn(`VM_HUGEMEM')
          requests:
            memory: defn(`VM_HUGEMEM')
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: HAS-SETUP-CEPH-STORAGE
                operator: Exists
ifelse("defn(`VM_SCALING')","1",`dnl
              - key: VM-SCALING-NODE
                operator: Exists
              - key: zone-defn(`VM_ZONE')
                operator: Exists
',)dnl
ifelse("defn(`VM_SCALING')","0",`dnl
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: kubevirt.io/vm
                operator: In
                values:
                - ubuntu
            topologyKey: kubernetes.io/hostname
',)dnl
      terminationGracePeriodSeconds: 0
      volumes:
      - name: block-disk1
        persistentVolumeClaim:
          claimName: defn(`PVC_NAME')-1
ifelse("eval(defn(`RBD_IMAGE_NUM') > 1)","1",`dnl
      - name: block-disk2
        persistentVolumeClaim:
          claimName: defn(`PVC_NAME')-2
',)dnl
ifelse("eval(defn(`RBD_IMAGE_NUM') > 2)","1",`dnl
      - name: block-disk3
        persistentVolumeClaim:
          claimName: defn(`PVC_NAME')-3
',)dnl
      - containerDisk:
          image: defn(`DOCKER_IMAGE_GUESTOS')
          imagePullPolicy: Always
        name: containerdisk
      - cloudInitNoCloud:
          userData: |-
            #cloud-config
            disable_root: False
            chpasswd:
              list: |
                ubuntu:ubuntu
                root:root
              expire: False
            ssh_pwauth: True
            ssh_authorized_keys:
              - ssh-rsa
            runcmd:
              - timedatectl set-timezone Asia/Shanghai
              - echo "export benchmark_options=\"defn(`BENCHMARK_OPTIONS')\"" >>/etc/profile
              - echo "export configuration_options=\"defn(`CONFIGURATION_OPTIONS')\"" >>/etc/profile
              - sudo bash -x /opt/test/run_test.sh
        name: cloudinitdisk
',)dnl


ifelse("defn(`TEST_CASE')","vhost",`dnl
---
apiVersion: kubevirt.io/v1alpha3
kind: VirtualMachine
metadata:
  labels:
    kubevirt.io/vm: ubuntu
  name: defn(`VM_NAME')
spec:
  running: True
  template:
    metadata:
      labels:
        kubevirt.io/vm: ubuntu
    spec:
      domain:
        cpu:
          cores: defn(`VM_CPU_NUM')
          sockets: 1
ifelse("defn(`CPU_PLACEMENT')","1",`dnl
          dedicatedCpuPlacement: true
',)dnl
        memory:
          hugepages:
            pageSize: "2Mi"
        devices:
          disks:
          - disk:
              bus: virtio
            name: containerdisk
          - disk:
              bus: virtio
            name: cloudinitdisk
          - disk:
              bus: virtio
            name: spdk-vhost-blk1
ifelse("eval(defn(`RBD_IMAGE_NUM') > 1)","1",`dnl
          - disk:
              bus: virtio
            name: spdk-vhost-blk2
',)dnl
ifelse("eval(defn(`RBD_IMAGE_NUM') > 2)","1",`dnl
          - disk:
              bus: virtio
            name: spdk-vhost-blk3
',)dnl
        machine:
          type: ""
        resources:
          limits:
            hugepages-2Mi: defn(`VM_HUGEMEM')
            memory: defn(`VM_HUGEMEM')
          requests:
            memory: defn(`VM_HUGEMEM')
            hugepages-2Mi: defn(`VM_HUGEMEM')
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: HAS-SETUP-CEPH-STORAGE
                operator: Exists
              - key: HAS-SETUP-HUGEPAGE-2048kB-32768
                operator: Exists
ifelse("defn(`VM_SCALING')","1",`dnl
              - key: VM-SCALING-NODE
                operator: Exists
              - key: zone-defn(`VM_ZONE')
                operator: Exists
',)dnl
ifelse("defn(`VM_SCALING')","0",`dnl
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: kubevirt.io/vm
                operator: In
                values:
                - ubuntu
            topologyKey: kubernetes.io/hostname
',)dnl
      terminationGracePeriodSeconds: 0
      volumes:
      - name: spdk-vhost-blk1
        spdkVhostBlkDisk:
          capacity: defn(`RBD_IMG_SIZE')
ifelse("eval(defn(`RBD_IMAGE_NUM') > 1)","1",`dnl
      - name: spdk-vhost-blk2
        spdkVhostBlkDisk:
          capacity: defn(`RBD_IMG_SIZE')
',)dnl
ifelse("eval(defn(`RBD_IMAGE_NUM') > 2)","1",`dnl
      - name: spdk-vhost-blk3
        spdkVhostBlkDisk:
          capacity: defn(`RBD_IMG_SIZE')
',)dnl
      - containerDisk:
          image: defn(`DOCKER_IMAGE_GUESTOS')
          imagePullPolicy: Always
        name: containerdisk
      - cloudInitNoCloud:
          userData: |-
            #cloud-config
            disable_root: False
            chpasswd:
              list: |
                ubuntu:ubuntu
                root:root
              expire: False
            ssh_pwauth: True
            ssh_authorized_keys:
              - ssh-rsa
            runcmd:
              - timedatectl set-timezone Asia/Shanghai
              - echo "export benchmark_options=\"defn(`BENCHMARK_OPTIONS')\"" >>/etc/profile
              - echo "export configuration_options=\"defn(`CONFIGURATION_OPTIONS')\"" >>/etc/profile
              - sudo bash -x /opt/test/run_test.sh
        name: cloudinitdisk


',)dnl